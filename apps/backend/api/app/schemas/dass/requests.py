from pydantic import BaseModel, Field


class DASSItemUpdate(BaseModel):
    item_id: int = Field(..., ge=1, le=21)
    score: int = Field(..., ge=0, le=3)


class DASSAssessmentUpdate(BaseModel):
    items: list[DASSItemUpdate] = Field(..., min_length=1, max_length=21)
