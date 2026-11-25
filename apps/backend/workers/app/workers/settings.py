from app.tasks.emotion_task import detect_voice_emotion_task
from app.tasks.payment_task import (
    payment_daily_reconciliation_task,
    payment_reconcile_pending_orders_task,
    payment_retry_outbox_task,
    payout_reconcile_pending_withdrawals_task,
)
from app.tasks.risk_task import assess_risk_task
from app.tasks.symptom_task import extract_symptom_task
from app.tasks.summarization import extract_memory_task, summarize_conversation_task
from arq import cron
from arq.connections import RedisSettings
from shared.config import settings


def parse_redis_settings(url: str) -> RedisSettings:
    """Helper to convert redis URL to ARQ RedisSettings."""
    from urllib.parse import urlparse
    parsed = urlparse(url)
    return RedisSettings(
        host=parsed.hostname or "localhost",
        port=parsed.port or 6379,
        database=int(parsed.path.lstrip("/") or 0),
    )


class WorkerSettings:
    functions = [
        summarize_conversation_task,
        extract_memory_task,
        detect_voice_emotion_task,
        extract_symptom_task,
        assess_risk_task,
        payment_reconcile_pending_orders_task,
        payment_retry_outbox_task,
        payout_reconcile_pending_withdrawals_task,
        payment_daily_reconciliation_task,
    ]
    cron_jobs = [
        cron(payment_reconcile_pending_orders_task, minute={0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58}),
        cron(payment_retry_outbox_task, minute={1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37, 39, 41, 43, 45, 47, 49, 51, 53, 55, 57, 59}),
        cron(payout_reconcile_pending_withdrawals_task, minute={0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45, 48, 51, 54, 57}),
        cron(payment_daily_reconciliation_task, hour=2, minute=0),
    ]
    redis_settings = parse_redis_settings(settings.REDIS_URL)
    max_jobs = 10



