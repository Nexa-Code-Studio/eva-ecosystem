from typing import Any
from pydantic import BaseModel, ConfigDict


class CopingActivityResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    category: str
    targetCondition: str
    duration: str
    difficulty: str
    level: str
    description: str
    instructions: list[str] = []
    rationale: str = ""
    iconName: str = "spa"
    isCompleted: bool = False


class TodayRecommendationResponse(BaseModel):
    targetCondition: str
    conditionLabel: str
    conditionReason: str
    severityLevel: str
    isCrisis: bool
    crisisHotline: str
    crisisGuidance: str
    todayActivity: CopingActivityResponse
    completedTodayCount: int
    alternatives: list[CopingActivityResponse] = []
    allRecommendations: list[CopingActivityResponse] = []


class CompleteActivityResponse(BaseModel):
    message: str
    activityId: str
    completedDate: str | None = None
    isCompleted: bool = True
