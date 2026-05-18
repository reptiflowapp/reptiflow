-- feeding_recipes: 사용자별 급여 레시피
create table if not exists feeding_recipes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  components  jsonb not null default '{}',
  created_at  timestamptz not null default now()
);

alter table feeding_recipes enable row level security;

create policy "feeding_recipes: owner access"
  on feeding_recipes
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- feeding_logs: 개체별 급여 기록
create table if not exists feeding_logs (
  id          uuid primary key default gen_random_uuid(),
  reptile_id  uuid not null references reptiles(id) on delete cascade,
  recipe_id   uuid references feeding_recipes(id) on delete set null,
  fed_at      timestamptz not null default now(),
  status      text not null check (status in ('fed', 'partial', 'refused')),
  memo        text,
  created_at  timestamptz not null default now()
);

alter table feeding_logs enable row level security;

create policy "feeding_logs: owner access"
  on feeding_logs
  for all
  using (
    reptile_id in (
      select id from reptiles where user_id = auth.uid()
    )
  )
  with check (
    reptile_id in (
      select id from reptiles where user_id = auth.uid()
    )
  );

-- 조회 성능용 인덱스
create index if not exists feeding_logs_reptile_fed_at
  on feeding_logs (reptile_id, fed_at desc);

create index if not exists feeding_logs_fed_at
  on feeding_logs (fed_at desc);
