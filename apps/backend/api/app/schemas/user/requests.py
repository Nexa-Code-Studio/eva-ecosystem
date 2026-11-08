from pydantic import BaseModel


class CreateEmergencyContactRequest(BaseModel):
    name: str
    relationship: str
    phone_number: str
    is_primary: bool = False


class UpdateEmergencyContactRequest(BaseModel):
    name: str | None = None
    relationship: str | None = None
    phone_number: str | None = None
    is_primary: bool | None = None
