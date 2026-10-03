from typing import Literal
from pydantic import BaseModel, Field


class GenerateQuizRequest(BaseModel):
    amount: int = Field(default=10, ge=1, le=30, strict=True)
    difficulty: Literal["mudah", "sedang", "sulit", "easy", "medium", "hard"] = "sedang"


class QuizQuestionItem(BaseModel):
    question: str = Field(min_length=1)
    options: list[str] = Field(min_length=4, max_length=4)
    correct_index: int = Field(ge=0, le=3, strict=True)
    explanation: str = Field(min_length=1)


class QuizData(BaseModel):
    questions: list[QuizQuestionItem]


class AnswerItem(BaseModel):
    question_id: str = Field(min_length=1)
    selected_index: int = Field(ge=0, strict=True)


class SubmitQuizRequest(BaseModel):
    answers: list[AnswerItem] = Field(min_length=1)
