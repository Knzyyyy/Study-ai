from pydantic import BaseModel

class TermDefinition(BaseModel):
    term: str
    definition: str

class SectionSummary(BaseModel):
    title: str
    key_points: list[str]
    key_terms: list[TermDefinition]
    examples: list[str]

class OverviewResponse(BaseModel):
    overview: str