from typing import Any
from pydantic import BaseModel, ConfigDict


class EmotionBreakdownItem(BaseModel):
    name: str
    label: str
    emoji: str
    percent: float
    color: str


class TranscriptItem(BaseModel):
    isUser: bool
    time: str
    text: str
    emotionTag: str | None = None
    emotionEmoji: str | None = None


class DiarySessionItem(BaseModel):
    id: str
    title: str
    time: str
    moodTag: str
    moodEmoji: str
    emotionsBreakdown: list[EmotionBreakdownItem] = []
    transcripts: list[TranscriptItem] = []


class DiaryRiskWarning(BaseModel):
    detected: bool
    type: str
    title: str
    level: str
    message: str


class DiaryEntryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str | None = None
    title: str | None = None
    date: str | None = None
    sessionCount: int = 0
    lastSessionTime: str = "-"
    moodTag: str = "Netral"
    moodEmoji: str = "😌"
    summary: str = ""
    riskWarning: DiaryRiskWarning | None = None
    aiInsight: str = ""
    importantEvents: list[str] = []
    emotionalReflection: str = ""
    mentalHealthScores: dict[str, Any] = {}
    emotionsBreakdown: list[EmotionBreakdownItem] = []
    sessions: list[DiarySessionItem] = []
    message: str | None = None


class DeleteDiaryResponse(BaseModel):
    message: str = "Diary entry deleted successfully"
