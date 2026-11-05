from pydantic import BaseModel

class FlashcardItem(BaseModel):
    front: str
    back: str
    source_page: int | None = None
    example: str | None = None

class FlashcardList(BaseModel):
    flashcards: list[FlashcardItem]


class FlashcardReviewRequest(BaseModel):
    understood: bool = True
