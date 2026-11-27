from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from shared.config import settings

from app.api.dependencies import shutdown_webrtc_signaling_manager
from app.services.call import shutdown_emotion_coordinator, shutdown_stt_coordinator
from app.api.routes.admin_coins import router as admin_coins_router
from app.api.routes.admin_counselors import router as admin_counselors_router
from app.api.routes.admin_finance import router as admin_finance_router
from app.api.routes.admin_sessions import router as admin_sessions_router
from app.api.routes.analytics import router as analytics_router
from app.api.routes.auth import router as auth_router
from app.api.routes.booth_feedbacks import (
    admin_router as booth_feedbacks_admin_router,
    public_router as booth_feedbacks_public_router,
)
from app.api.routes.call import router as call_router
from app.api.routes.care import community_router, router as care_router
from app.api.routes.certificates import (
    admin_router as certificates_admin_router,
    counselor_router as certificates_counselor_router,
)
from app.api.routes.coins import router as coins_router
from app.api.routes.content import (
    admin_router as content_admin_router,
    public_router as content_public_router,
)
from app.api.routes.conversations import router as conversations_router
from app.api.routes.counselor import router as counselor_router
from app.api.routes.dass import router as dass_router
from app.api.routes.diaries import router as diaries_router
from app.api.routes.finances import router as finances_router
from app.api.routes.health import router as health_router
from app.api.routes.levels import (
    admin_router as levels_admin_router,
    counselor_router as levels_counselor_router,
)
from app.api.routes.patients import router as patients_router
from app.api.routes.pricing import router as pricing_router
from app.api.routes.recommendations import router as recommendations_router
from app.api.routes.sessions import router as sessions_router
from app.api.routes.user import router as user_router
from app.api.routes.webhooks import router as webhooks_router
from app.core.logging import setup_logging

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging()
    if settings.APP_ENV == "development":
        try:
            from app.db.seed import seed_master_data
            logger.info("APP_ENV=development: Running auto-seeder...")
            await seed_master_data()
        except Exception as e:
            logger.warning(f"Auto-seed during development startup skipped: {e}")
    try:
        yield
    finally:
        await shutdown_stt_coordinator()
        await shutdown_emotion_coordinator()
        await shutdown_webrtc_signaling_manager()


app = FastAPI(
    title="Eva AI Backend API",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router, tags=["Health"])
app.include_router(auth_router, prefix="/api/v1")
app.include_router(user_router, prefix="/api/v1")
app.include_router(diaries_router, prefix="/api/v1")
app.include_router(analytics_router, prefix="/api/v1")
app.include_router(recommendations_router, prefix="/api/v1")
app.include_router(dass_router, prefix="/api/v1")
app.include_router(conversations_router, prefix="/api/v1")
app.include_router(call_router, prefix="/api/v1")
app.include_router(counselor_router, prefix="/api/v1")
app.include_router(pricing_router, prefix="/api/v1")
app.include_router(sessions_router, prefix="/api/v1")
app.include_router(patients_router, prefix="/api/v1")
app.include_router(finances_router, prefix="/api/v1")
app.include_router(care_router, prefix="/api/v1")
app.include_router(admin_coins_router, prefix="/api/v1")
app.include_router(admin_finance_router, prefix="/api/v1")
app.include_router(coins_router, prefix="/api/v1")
app.include_router(admin_counselors_router, prefix="/api/v1")
app.include_router(admin_sessions_router, prefix="/api/v1")
app.include_router(content_public_router, prefix="/api/v1")
app.include_router(content_admin_router, prefix="/api/v1")
app.include_router(booth_feedbacks_public_router, prefix="/api/v1")
app.include_router(booth_feedbacks_admin_router, prefix="/api/v1")
app.include_router(community_router, prefix="/api/v1")
app.include_router(certificates_counselor_router, prefix="/api/v1")
app.include_router(certificates_admin_router, prefix="/api/v1")
app.include_router(levels_counselor_router, prefix="/api/v1")
app.include_router(levels_admin_router, prefix="/api/v1")
app.include_router(webhooks_router, prefix="/api/v1")


@app.get("/")
async def root():
    return {"message": "Eva AI API Server", "environment": settings.APP_ENV}
