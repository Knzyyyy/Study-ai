begin;

alter table public.flashcard_reviews
  add column if not exists known boolean not null default true;

commit;
