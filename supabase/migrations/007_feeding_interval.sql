alter table reptiles
  add column if not exists feeding_interval_days int default 7;
