from pydantic import BaseModel, ConfigDict


class EmergencyContactResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    relationship: str
    phone: str
    isPrimary: bool


class DeleteContactResponse(BaseModel):
    message: str = "Contact deleted successfully"
