-- breeding_logs: 메이팅 기록
create table if not exists breeding_logs (
  id           uuid primary key default gen_random_uuid(),
  male_id      uuid references reptiles(id) on delete set null,
  female_id    uuid references reptiles(id) on delete set null,
  paired_at    timestamptz not null default now(),
  separated_at timestamptz,
  success      boolean,
  memo         text,
  created_at   timestamptz not null default now()
);

alter table breeding_logs enable row level security;

create policy "breeding_logs: owner access"
  on breeding_logs
  for all
  using (
    male_id   in (select id from reptiles where user_id = auth.uid())
    or
    female_id in (select id from reptiles where user_id = auth.uid())
  )
  with check (
    male_id   in (select id from reptiles where user_id = auth.uid())
    or
    female_id in (select id from reptiles where user_id = auth.uid())
  );

-- egg_clutches: 산란 기록
create table if not exists egg_clutches (
  id                  uuid primary key default gen_random_uuid(),
  female_id           uuid not null references reptiles(id) on delete cascade,
  breeding_log_id     uuid references breeding_logs(id) on delete set null,
  laid_at             date not null,
  total_eggs          int not null default 0,
  fertile             int not null default 0,
  infertile           int not null default 0,
  expected_hatch_date date,
  memo                text,
  created_at          timestamptz not null default now()
);

alter table egg_clutches enable row level security;

create policy "egg_clutches: owner access"
  on egg_clutches
  for all
  using (
    female_id in (select id from reptiles where user_id = auth.uid())
  )
  with check (
    female_id in (select id from reptiles where user_id = auth.uid())
  );

-- hatch_records: 해칭 기록
create table if not exists hatch_records (
  id            uuid primary key default gen_random_uuid(),
  clutch_id     uuid not null references egg_clutches(id) on delete cascade,
  hatched_at    date not null,
  hatched_count int not null default 0,
  memo          text,
  created_at    timestamptz not null default now()
);

alter table hatch_records enable row level security;

create policy "hatch_records: owner access"
  on hatch_records
  for all
  using (
    clutch_id in (
      select id from egg_clutches
      where female_id in (select id from reptiles where user_id = auth.uid())
    )
  )
  with check (
    clutch_id in (
      select id from egg_clutches
      where female_id in (select id from reptiles where user_id = auth.uid())
    )
  );

create index if not exists breeding_logs_male_id   on breeding_logs (male_id);
create index if not exists breeding_logs_female_id  on breeding_logs (female_id);
create index if not exists egg_clutches_female_id   on egg_clutches (female_id);
create index if not exists egg_clutches_hatch_date  on egg_clutches (expected_hatch_date);
