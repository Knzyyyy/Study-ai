begin;

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  created_at timestamptz not null default now()
);

create index courses_user_id_idx on public.courses(user_id);
alter table public.courses enable row level security;
grant select, insert, update on public.courses to authenticated;
revoke all on public.courses from anon;

create policy courses_select_owner on public.courses
  for select to authenticated using (user_id = auth.uid());
create policy courses_insert_owner on public.courses
  for insert to authenticated with check (user_id = auth.uid());
create policy courses_update_owner on public.courses
  for update to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid());

do $$
declare
  column_type text;
begin
  if to_regclass('public.materials') is null then
    raise exception 'public.materials harus tersedia sebelum migrasi';
  end if;
  select udt_name into column_type from information_schema.columns
    where table_schema = 'public' and table_name = 'materials' and column_name = 'course_id';
  if column_type is null then
    alter table public.materials add column course_id uuid;
  elsif column_type not in ('uuid', 'text', 'varchar') then
    raise exception 'Tipe materials.course_id tidak didukung: %', column_type;
  end if;
  select udt_name into column_type from information_schema.columns
    where table_schema = 'public' and table_name = 'materials' and column_name = 'user_id';
  if column_type is distinct from 'uuid' then
    raise exception 'materials.user_id harus bertipe uuid, ditemukan: %', column_type;
  end if;
end;
$$;

create function public.validate_material_course_owner()
returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    if new.course_id is not distinct from old.course_id
       and new.user_id is not distinct from old.user_id then
      return new;
    end if;
  end if;
  if not exists (
    select 1 from public.courses
    where id::text = new.course_id::text and user_id = new.user_id
  ) then
    raise exception 'Mata kuliah tidak ditemukan atau bukan milik pemilik materi';
  end if;
  return new;
end;
$$;

create trigger materials_validate_course_owner
before insert or update of course_id, user_id on public.materials
for each row execute function public.validate_material_course_owner();

commit;
