from pydantic import BaseModel

# Request dari Flutter saat mau bikin quiz
class GenerateQuizRequest(BaseModel):
    amount: int = 5          # Jumlah soal default 5
    difficulty: str = "sedang" # Tingkat kesulitan (mudah/sedang/sulit)

# Skema untuk memaksa Gemini membuat format yang benar
class QuizQuestionItem(BaseModel):
    question: str
    options: list[str]     # Array berisi 4 pilihan jawaban
    correct_index: int     # Index jawaban benar (0, 1, 2, atau 3)
    explanation: str       # Penjelasan kenapa jawaban itu benar

class QuizData(BaseModel):
    questions: list[QuizQuestionItem]

# Request dari Flutter saat kumpul jawaban
class AnswerItem(BaseModel):
    question_id: str
    selected_index: int

class SubmitQuizRequest(BaseModel):
    answers: list[AnswerItem]