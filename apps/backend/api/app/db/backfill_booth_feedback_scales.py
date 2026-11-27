from __future__ import annotations

import argparse
import asyncio
from dataclasses import dataclass

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import AsyncSessionLocal

VALID_VISITOR_ROLES = {"user", "counselor"}


@dataclass(frozen=True)
class BackfillBoothFeedbackResult:
    """Summary of BoothFeedback scale and role backfill execution."""

    total_rows: int
    pending_rows: int
    updated_rows: int
    default_value: int
    default_role: str
    applied: bool


async def backfill_booth_feedback_scales(
    session: AsyncSession,
    *,
    default_value: int = 3,
    default_role: str = "user",
    apply: bool = False,
    overwrite_all: bool = False,
) -> BackfillBoothFeedbackResult:
    """Inspect and optionally populate BoothFeedback scale and role columns."""
    if default_value < 1 or default_value > 5:
        raise ValueError("default_value must be an integer between 1 and 5.")
    normalized_role = default_role.strip().lower()
    if normalized_role not in VALID_VISITOR_ROLES:
        raise ValueError("default_role must be 'user' or 'counselor'.")

    total_res = await session.execute(text("SELECT COUNT(*) FROM booth_feedbacks"))
    total_rows = int(total_res.scalar_one() or 0)

    where_clause = (
        "1 = 1"
        if overwrite_all
        else "usage_likelihood IS NULL OR recommendation_score IS NULL OR visitor_role IS NULL"
    )

    pending_res = await session.execute(
        text(f"SELECT COUNT(*) FROM booth_feedbacks WHERE {where_clause}")
    )
    pending_rows = int(pending_res.scalar_one() or 0)

    if not apply or pending_rows == 0:
        return BackfillBoothFeedbackResult(
            total_rows=total_rows,
            pending_rows=pending_rows,
            updated_rows=0,
            default_value=default_value,
            default_role=normalized_role,
            applied=False,
        )

    set_clause = (
        "usage_likelihood = :default_val, "
        "recommendation_score = :default_val, "
        "visitor_role = :default_role"
        if overwrite_all
        else (
            "usage_likelihood = COALESCE(usage_likelihood, :default_val), "
            "recommendation_score = COALESCE(recommendation_score, :default_val), "
            "visitor_role = COALESCE(visitor_role, :default_role)"
        )
    )
    update_res = await session.execute(
        text(f"UPDATE booth_feedbacks SET {set_clause} WHERE {where_clause}"),
        {"default_val": default_value, "default_role": normalized_role},
    )
    await session.commit()

    updated_rows = int(update_res.rowcount or pending_rows)
    return BackfillBoothFeedbackResult(
        total_rows=total_rows,
        pending_rows=pending_rows,
        updated_rows=updated_rows,
        default_value=default_value,
        default_role=normalized_role,
        applied=True,
    )


async def _run_cli(args: argparse.Namespace) -> int:
    should_apply = bool(args.apply and not args.dry_run)
    async with AsyncSessionLocal() as session:
        preview = await backfill_booth_feedback_scales(
            session,
            default_value=args.default_value,
            default_role=args.default_role,
            apply=False,
            overwrite_all=args.overwrite_all,
        )
        mode_label = "APPLY" if should_apply else "DRY-RUN"
        print(
            f"[{mode_label}] booth_feedbacks total={preview.total_rows}, "
            f"target_rows={preview.pending_rows}, default_value={preview.default_value}, "
            f"default_role={preview.default_role}"
        )

        if not should_apply or preview.pending_rows == 0:
            return 0

        if not args.yes:
            answer = input(
                f"Konfirmasi isi {preview.pending_rows} baris booth_feedbacks dengan skor {args.default_value} & peran '{args.default_role}'? [y/N]: "
            ).strip().lower()
            if answer not in {"y", "yes"}:
                print("Dibatalkan. Tidak ada data yang diubah.")
                return 0

        result = await backfill_booth_feedback_scales(
            session,
            default_value=args.default_value,
            default_role=args.default_role,
            apply=True,
            overwrite_all=args.overwrite_all,
        )
        print(f"Selesai: {result.updated_rows} baris diperbarui.")
        return 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Backfill default scores (1-5) and visitor_role for existing booth_feedbacks rows."
    )
    parser.add_argument(
        "--default-value",
        type=int,
        default=3,
        help="Default integer score between 1 and 5 (default: 3).",
    )
    parser.add_argument(
        "--default-role",
        type=str,
        default="user",
        choices=["user", "counselor"],
        help="Default visitor_role when NULL (default: user).",
    )
    parser.add_argument(
        "--overwrite-all",
        action="store_true",
        help="Reset all rows in dev DB instead of only NULL values.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview affected rows without modifying the database (default behavior).",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Execute UPDATE commit on database after confirmation.",
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Skip interactive prompt when used with --apply.",
    )
    parsed = parser.parse_args()
    raise SystemExit(asyncio.run(_run_cli(parsed)))


if __name__ == "__main__":
    main()
