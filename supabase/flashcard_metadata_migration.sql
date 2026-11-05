begin;

alter table public.flashcards
  add column if not exists source_page integer,
  add column if not exists example text;

commit;
