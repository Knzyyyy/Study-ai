from pydantic import BaseModel

class FlashcardItem(BaseModel):
    front: str
    back: str

class FlashcardList(BaseModel):
    flashcards: list[FlashcardItem]