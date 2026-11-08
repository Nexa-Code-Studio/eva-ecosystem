from pydantic import BaseModel, ConfigDict


class HealthCheckResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    status: str
    app: str
    environment: str
    database: str
    redis: str
    qdrant: str
