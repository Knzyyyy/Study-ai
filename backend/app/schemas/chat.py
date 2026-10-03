from pydantic import BaseModel, constr

class CreateSessionRequest(BaseModel):
    material_id: str

class SendMessageRequest(BaseModel):
    content: constr(strip_whitespace=True, min_length=1, max_length=20000)