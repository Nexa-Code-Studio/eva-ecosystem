from typing import Any
from pydantic import BaseModel, ConfigDict


class MessageItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    sender: str
    text: str
    time: str
    isAudio: bool = False
    emotionTag: str | None = None
    emotionEmoji: str | None = None


class ConversationDetailResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    is_title_generating: bool = False
    lastMessage: str = ""
    lastMessageTime: str = ""
    duration: str = "00:00"
    dominant_emotion: str = "Tenang & Nyaman"
    dominant_emoji: str = "😌"
    summary: str | None = None
    messages: list[MessageItemResponse] = []


class ConversationPagination(BaseModel):
    page: int
    limit: int
    total_items: int
    total_pages: int
    has_more: bool


class ConversationListResponse(BaseModel):
    items: list[ConversationDetailResponse]
    pagination: ConversationPagination
    total: int
    page: int
    limit: int
    has_more: bool


class TranscriptItem(BaseModel):
    role: str
    content: str
    time: str
    emotionTag: str | None = None
    emotionEmoji: str | None = None


class EmotionBreakdownSimple(BaseModel):
    label: str
    emoji: str
    percent: float
    color: str


class ConversationAnalysis(BaseModel):
    dominant_emotion: str
    calm_score: str
    stress_level: str
    empathy_level: str
    ai_insight: str
    emotions_breakdown: list[EmotionBreakdownSimple] = []


class TodayConversationItem(BaseModel):
    id: str
    title: str
    is_title_generating: bool = False
    date: str
    duration: str
    moodTag: str
    emotion_analysis: ConversationAnalysis
    transcript: list[TranscriptItem] = []


class TodayConversationResponse(BaseModel):
    items: list[TodayConversationItem]
    total: int
    page: int
    limit: int
    has_more: bool


class TodayMessageItem(BaseModel):
    id: str
    role: str
    isUser: bool
    content: str
    text: str
    time: str
    sessionTitle: str
    emotionTag: str | None = None
    emotionEmoji: str | None = None


class TodayMessagesResponse(BaseModel):
    items: list[TodayMessageItem]
    total_items: int
    page: int
    limit: int
    total_pages: int


class SentMessageResponse(BaseModel):
    id: str
    sender: str
    text: str
    time: str
    isAudio: bool = False
