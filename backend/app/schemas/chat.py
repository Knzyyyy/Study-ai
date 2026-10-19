from typing import Literal

from pydantic import BaseModel, ConfigDict, constr


class ChatScopeResult(BaseModel):
    model_config = ConfigDict(extra="forbid")

    scope: Literal["material", "app_help", "off_topic"]

class CreateSessionRequest(BaseModel):
    material_id: str

class SendMessageRequest(BaseModel):
    content: constr(strip_whitespace=True, min_length=1, max_length=20000)