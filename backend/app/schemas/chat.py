from pydantic import BaseModel

class CreateSessionRequest(BaseModel):
    material_id: str

class SendMessageRequest(BaseModel):
    content: str