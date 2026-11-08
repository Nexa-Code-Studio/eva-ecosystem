from pydantic import BaseModel


class CreateDiaryRequest(BaseModel):
    content: str
    mood_tag: str | None = None


class UpdateDiaryRequest(BaseModel):
    content: str | None = None
    mood_tag: str | None = None
    title: str | None = None
