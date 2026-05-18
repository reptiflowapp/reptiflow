create table if not exists profile_templates (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  name           text not null,
  field_order    jsonb not null default '[]'::jsonb,
  theme          text not null default 'dark',
  watermark_text text not null default 'ReptiFlow',
  created_at     timestamptz not null default now()
);

alter table profile_templates enable row level security;

create policy "profile_templates: owner access"
  on profile_templates
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists profile_templates_user_id on profile_templates (user_id);
