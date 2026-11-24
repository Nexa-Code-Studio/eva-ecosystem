from pydantic import BaseModel, ConfigDict


class UserAuthResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    email: str
    is_admin: bool = False
    coin_balance: int = 10


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserAuthResponse


class EmailCheckResponse(BaseModel):
    available: bool
    email: str
    message: str


class LogoutResponse(BaseModel):
    message: str = "Logged out successfully"
