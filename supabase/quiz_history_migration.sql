begin;

alter table public.quiz_attempts
  add column if not exists created_at timestamptz;

alter table public.quiz_attempts
  alter column created_at set default now();

commit;
