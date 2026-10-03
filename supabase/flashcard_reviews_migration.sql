begin;

create table if not exists public.flashcard_reviews (
  user_id uuid not null references auth.users(id) on delete cascade,
  flashcard_id uuid not null,
  material_id uuid not null,
  studied_at timestamptz not null default now(),
  primary key (user_id, flashcard_id)
);

alter table public.flashcard_reviews enable row level security;

create policy "Users can view own flashcard reviews"
  on public.flashcard_reviews for select to authenticated
  using (auth.uid() = user_id);

create policy "Users can mark own flashcards studied"
  on public.flashcard_reviews for insert to authenticated
  with check (
    auth.uid() = user_id and exists (
      select 1 from public.flashcards f
      join public.materials m on m.id = f.material_id
      where f.id = flashcard_id
        and m.id = flashcard_reviews.material_id
        and m.user_id = auth.uid()
    )
  );

commit;
