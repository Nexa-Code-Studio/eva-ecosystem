from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_current_admin, get_scheduling_service
from app.models.user import User
from app.schemas.session import AdminSessionMonitoringResponse
from app.services.session import SchedulingService

router = APIRouter(prefix="/admin/sessions", tags=["Admin Sessions"])


@router.get("", response_model=list[AdminSessionMonitoringResponse])
async def list_admin_consultation_sessions(
    status: str | None = Query(default=None),
    is_extended: bool | None = Query(default=None),
    search: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    admin: User = Depends(get_current_admin),
    service: SchedulingService = Depends(get_scheduling_service),
) -> list[AdminSessionMonitoringResponse]:
    """List teleconsultation sessions across patients and counselors for read-only admin monitoring."""
    return await service.list_admin_sessions(
        session_status=status,
        is_extended=is_extended,
        search=search,
        limit=limit,
        offset=offset,
    )
