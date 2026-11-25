import base64
from datetime import UTC, datetime, timedelta
import hashlib
import json
import logging
from typing import Any

import httpx
from sqlalchemy import text

from shared.config import settings
from shared.database import AsyncSessionLocal

logger = logging.getLogger(__name__)


def _midtrans_base_url() -> str:
    return "https://api.midtrans.com" if settings.MIDTRANS_IS_PRODUCTION else "https://api.sandbox.midtrans.com"


def _api_internal_base_url() -> str:
    return f"http://api:{settings.PORT}/api/v1"


async def _fetch_midtrans_status(client: httpx.AsyncClient, order_id: str) -> dict[str, Any] | None:
    server_key = (settings.MIDTRANS_SERVER_KEY or "").strip()
    if not server_key:
        return None
    auth = base64.b64encode(f"{server_key}:".encode()).decode()
    resp = await client.get(
        f"{_midtrans_base_url()}/v2/{order_id}/status",
        headers={"Accept": "application/json", "Authorization": f"Basic {auth}"},
    )
    if resp.status_code == 404:
        return {"status_code": "404"}
    if resp.status_code >= 400:
        return None
    return resp.json()


async def _dispatch_to_api_webhook(client: httpx.AsyncClient, status_payload: dict[str, Any]) -> bool:
    for base in (_api_internal_base_url(), f"http://127.0.0.1:{settings.PORT}/api/v1"):
        try:
            resp = await client.post(f"{base}/webhooks/midtrans/payment", json=status_payload)
            if resp.status_code < 400:
                return True
        except httpx.HTTPError:
            continue
    return False


async def payment_reconcile_pending_orders_task(ctx: dict[str, Any]) -> dict[str, int]:
    """Reconcile pending/creating QRIS orders against Midtrans Get Status or expire stale orders."""
    if not settings.MIDTRANS_PAYMENT_ENABLED:
        return {"checked": 0, "updated": 0}

    now = datetime.now(UTC)
    checked = 0
    updated = 0

    async with AsyncSessionLocal() as db:
        rows = (
            await db.execute(
                text(
                    """
                    SELECT id, order_id, status, expires_at
                    FROM coin_topup_orders
                    WHERE status IN ('creating', 'pending')
                    ORDER BY created_at ASC
                    LIMIT 50
                    """
                )
            )
        ).mappings().all()

        async with httpx.AsyncClient(timeout=10.0) as client:
            for row in rows:
                checked += 1
                order_id = str(row["order_id"])
                try:
                    status_data = await _fetch_midtrans_status(client, order_id)
                    if status_data and status_data.get("status_code") == "404":
                        expires_at = row["expires_at"]
                        if expires_at and now > expires_at + timedelta(minutes=2):
                            await db.execute(
                                text("UPDATE coin_topup_orders SET status = 'expired', updated_at = :now WHERE id = :id"),
                                {"id": row["id"], "now": now},
                            )
                            await db.commit()
                            updated += 1
                    elif status_data and status_data.get("signature_key"):
                        if await _dispatch_to_api_webhook(client, status_data):
                            updated += 1
                except Exception as exc:
                    logger.warning("payment_reconcile_pending_orders_task error for %s: %s", order_id, exc)

    return {"checked": checked, "updated": updated}


async def payment_retry_outbox_task(ctx: dict[str, Any]) -> dict[str, int]:
    """Retry pending top-up outbox reconciliation events via Midtrans Get Status."""
    if not settings.MIDTRANS_PAYMENT_ENABLED:
        return {"processed": 0, "failed": 0}

    now = datetime.now(UTC)
    processed = 0
    failed = 0

    async with AsyncSessionLocal() as db:
        events = (
            await db.execute(
                text(
                    """
                    SELECT id, payload_json, attempts, next_retry_at
                    FROM payment_outbox_events
                    WHERE aggregate_type = 'topup_order' AND status = 'pending'
                    ORDER BY created_at ASC
                    LIMIT 25
                    """
                )
            )
        ).mappings().all()

        async with httpx.AsyncClient(timeout=10.0) as client:
            for ev in events:
                if ev["next_retry_at"] and ev["next_retry_at"] > now:
                    continue
                payload = ev["payload_json"] or {}
                order_id = str(payload.get("order_id") or "")
                if not order_id:
                    await db.execute(
                        text("UPDATE payment_outbox_events SET status = 'failed', updated_at = :now WHERE id = :id"),
                        {"id": ev["id"], "now": now},
                    )
                    await db.commit()
                    failed += 1
                    continue

                try:
                    status_data = await _fetch_midtrans_status(client, order_id)
                    if status_data and status_data.get("signature_key") and await _dispatch_to_api_webhook(client, status_data):
                        await db.execute(
                            text("UPDATE payment_outbox_events SET status = 'processed', updated_at = :now WHERE id = :id"),
                            {"id": ev["id"], "now": now},
                        )
                        await db.commit()
                        processed += 1
                        continue
                    raise RuntimeError("Status not yet reconcilable")
                except Exception as exc:
                    next_attempts = int(ev["attempts"] or 0) + 1
                    new_status = "failed" if next_attempts >= 5 else "pending"
                    next_retry = None if new_status == "failed" else now + timedelta(seconds=30 * next_attempts)
                    await db.execute(
                        text(
                            """
                            UPDATE payment_outbox_events
                            SET attempts = :attempts, status = :status, next_retry_at = :next_retry, last_error = :err, updated_at = :now
                            WHERE id = :id
                            """
                        ),
                        {
                            "id": ev["id"],
                            "attempts": next_attempts,
                            "status": new_status,
                            "next_retry": next_retry,
                            "err": str(exc)[:500],
                            "now": now,
                        },
                    )
                    await db.commit()
                    if new_status == "failed":
                        failed += 1

    return {"processed": processed, "failed": failed}


def _iris_base_url() -> str:
    configured = (settings.MIDTRANS_IRIS_BASE_URL or "").strip()
    if configured:
        return configured.rstrip("/")
    if settings.MIDTRANS_IS_PRODUCTION:
        return "https://app.midtrans.com/iris/api/v1"
    return "https://app.sandbox.midtrans.com/iris/api/v1"


async def payout_reconcile_pending_withdrawals_task(ctx: dict[str, Any]) -> dict[str, int]:
    """Reconcile active/review_required counselor payouts against Iris Get Payout Status."""
    creator_key = (settings.MIDTRANS_IRIS_CREATOR_KEY or "").strip()
    notif_secret = (settings.MIDTRANS_IRIS_NOTIFICATION_SECRET or "").strip()
    if not settings.MIDTRANS_PAYOUT_ENABLED or not creator_key or not notif_secret:
        return {"checked": 0, "updated": 0}

    checked = 0
    updated = 0
    auth = base64.b64encode(f"{creator_key}:".encode()).decode()

    async with AsyncSessionLocal() as db:
        rows = (
            await db.execute(
                text(
                    """
                    SELECT id, provider_reference, status
                    FROM counselor_withdrawals
                    WHERE status IN ('waiting_approval', 'processing', 'review_required')
                      AND provider_reference IS NOT NULL
                    ORDER BY created_at ASC
                    LIMIT 50
                    """
                )
            )
        ).mappings().all()

        async with httpx.AsyncClient(timeout=10.0) as client:
            for row in rows:
                checked += 1
                ref_no = str(row["provider_reference"])
                try:
                    resp = await client.get(
                        f"{_iris_base_url()}/payouts/{ref_no}",
                        headers={"Accept": "application/json", "Authorization": f"Basic {auth}"},
                    )
                    if resp.status_code != 200:
                        continue
                    data = resp.json()
                    raw_body = json.dumps(
                        {
                            "reference_no": ref_no,
                            "status": data.get("status"),
                            "amount": data.get("amount"),
                            "updated_at": data.get("updated_at"),
                        },
                        separators=(",", ":"),
                    ).encode("utf-8")
                    signature = hashlib.sha512(raw_body + notif_secret.encode("utf-8")).hexdigest()
                    for base in (_api_internal_base_url(), f"http://127.0.0.1:{settings.PORT}/api/v1"):
                        try:
                            hook_resp = await client.post(
                                f"{base}/webhooks/midtrans/iris",
                                content=raw_body,
                                headers={
                                    "Content-Type": "application/json",
                                    "Iris-Signature": signature,
                                },
                            )
                            if hook_resp.status_code < 400:
                                updated += 1
                                break
                        except httpx.HTTPError:
                            continue
                except Exception as exc:
                    logger.warning("payout_reconcile_pending_withdrawals_task error for %s: %s", ref_no, exc)

    return {"checked": checked, "updated": updated}


async def payment_daily_reconciliation_task(ctx: dict[str, Any]) -> dict[str, int]:
    """Daily reconciliation sweep comparing last 48h orders & withdrawals against provider truth."""
    now = datetime.now(UTC)
    cutoff = now - timedelta(hours=48)
    checked_topups = 0
    mismatched_topups = 0
    checked_payouts = 0
    matched_payouts = 0

    async with AsyncSessionLocal() as db:
        async with httpx.AsyncClient(timeout=10.0) as client:
            if settings.MIDTRANS_PAYMENT_ENABLED and (settings.MIDTRANS_SERVER_KEY or "").strip():
                topup_rows = (
                    await db.execute(
                        text(
                            """
                            SELECT id, order_id, status
                            FROM coin_topup_orders
                            WHERE created_at >= :cutoff
                              AND status IN ('pending', 'paid', 'review_required')
                              AND reconciliation_status != 'matched'
                            ORDER BY created_at ASC
                            LIMIT 200
                            """
                        ),
                        {"cutoff": cutoff},
                    )
                ).mappings().all()
                for row in topup_rows:
                    checked_topups += 1
                    status_data = await _fetch_midtrans_status(client, str(row["order_id"]))
                    if not status_data or status_data.get("status_code") == "404":
                        await db.execute(
                            text("UPDATE coin_topup_orders SET reconciliation_status = 'unknown', updated_at = :now WHERE id = :id"),
                            {"id": row["id"], "now": now},
                        )
                        continue
                    tx_status = str(status_data.get("transaction_status") or "").lower()
                    if row["status"] == "paid" and tx_status in ("settlement", "capture"):
                        rec_status = "matched"
                    elif row["status"] != "paid" and tx_status in ("settlement", "capture"):
                        rec_status = "mismatch"
                        mismatched_topups += 1
                    else:
                        rec_status = "matched"
                    await db.execute(
                        text("UPDATE coin_topup_orders SET reconciliation_status = :rec, updated_at = :now WHERE id = :id"),
                        {"id": row["id"], "rec": rec_status, "now": now},
                    )

            creator_key = (settings.MIDTRANS_IRIS_CREATOR_KEY or "").strip()
            if settings.MIDTRANS_PAYOUT_ENABLED and creator_key:
                auth = base64.b64encode(f"{creator_key}:".encode()).decode()
                payout_rows = (
                    await db.execute(
                        text(
                            """
                            SELECT id, provider_reference, status
                            FROM counselor_withdrawals
                            WHERE created_at >= :cutoff
                              AND provider_reference IS NOT NULL
                              AND reconciliation_status != 'matched'
                            ORDER BY created_at ASC
                            LIMIT 200
                            """
                        ),
                        {"cutoff": cutoff},
                    )
                ).mappings().all()
                for row in payout_rows:
                    checked_payouts += 1
                    resp = await client.get(
                        f"{_iris_base_url()}/payouts/{row['provider_reference']}",
                        headers={"Accept": "application/json", "Authorization": f"Basic {auth}"},
                    )
                    if resp.status_code != 200:
                        await db.execute(
                            text("UPDATE counselor_withdrawals SET reconciliation_status = 'unknown', updated_at = :now WHERE id = :id"),
                            {"id": row["id"], "now": now},
                        )
                        continue
                    remote_status = str(resp.json().get("status") or "").lower()
                    local_status = str(row["status"])
                    if (local_status == "completed" and remote_status == "completed") or (
                        local_status == remote_status
                    ):
                        await db.execute(
                            text("UPDATE counselor_withdrawals SET reconciliation_status = 'matched', updated_at = :now WHERE id = :id"),
                            {"id": row["id"], "now": now},
                        )
                        matched_payouts += 1
        await db.commit()

    return {
        "checked_topups": checked_topups,
        "mismatched_topups": mismatched_topups,
        "checked_payouts": checked_payouts,
        "matched_payouts": matched_payouts,
    }
