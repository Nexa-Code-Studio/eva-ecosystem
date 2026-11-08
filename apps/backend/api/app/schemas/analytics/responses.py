from pydantic import BaseModel, ConfigDict


class EmotionalCenterResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    status: str
    level: int
    description: str
    textColorHex: str


class RiskItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    name: str
    type: str
    percent: float
    levelLabel: str
    colorHex: str
    badgeBgHex: str


class MonitoringDataResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    periodKey: str
    periodLabel: str
    summary: str
    emotionalCenter: EmotionalCenterResponse
    risks: list[RiskItemResponse]
    xLabels: list[str]
    chartData: list[list[float]]
