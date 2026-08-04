-- ============================================================
-- Схема для аналитики Weather App
-- Выполнить целиком в Supabase → SQL Editor → New query → Run
-- ============================================================

-- Расширение для генерации UUID (обычно уже включено в Supabase, но на всякий случай)
create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- 1. Устройства (анонимные "пользователи")
-- Каждая установка приложения = одна строка. Никакой регистрации,
-- id генерируется в приложении один раз и хранится локально.
-- ------------------------------------------------------------
create table if not exists devices (
  device_id uuid primary key,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  app_version text,
  platform text,              -- 'android' / 'ios' / 'web' и т.д.
  locale text,                -- 'ru', 'en', 'hy'
  country_code text,          -- код страны по последней геолокации, напр. 'AM'
  city_name text               -- город по последней геолокации
);

create index if not exists idx_devices_first_seen on devices (first_seen_at);
create index if not exists idx_devices_last_seen on devices (last_seen_at);

-- ------------------------------------------------------------
-- 2. Избранные города по устройствам
-- Дублирует то, что уже лежит локально в SharedPreferences,
-- но здесь — чтобы видеть агрегаты в админке.
-- ------------------------------------------------------------
create table if not exists favorite_cities (
  id bigint generated always as identity primary key,
  device_id uuid not null references devices(device_id) on delete cascade,
  city_name text not null,
  country_code text,
  added_at timestamptz not null default now(),
  removed_at timestamptz          -- null = всё ещё в избранном
);

create index if not exists idx_favorites_device on favorite_cities (device_id);
create index if not exists idx_favorites_city on favorite_cities (city_name) where removed_at is null;

-- ------------------------------------------------------------
-- 3. Лог запросов погоды (для топ городов/стран и графиков активности)
-- ------------------------------------------------------------
create table if not exists weather_requests (
  id bigint generated always as identity primary key,
  device_id uuid not null references devices(device_id) on delete cascade,
  city_name text not null,
  country_code text,
  source text,                 -- 'geolocation' или 'search'
  requested_at timestamptz not null default now()
);

create index if not exists idx_requests_city on weather_requests (city_name);
create index if not exists idx_requests_country on weather_requests (country_code);
create index if not exists idx_requests_date on weather_requests (requested_at);
create index if not exists idx_requests_device on weather_requests (device_id);

-- ------------------------------------------------------------
-- 4. Row Level Security
-- Приложение подключается анонимным ключом (anon key) — этот ключ
-- публичный и будет "зашит" в APK, поэтому доступ через него должен
-- быть МАКСИМАЛЬНО ограничен: только запись своих же данных,
-- никакого чтения чужих. Чтение агрегатов — только вам, через
-- авторизованную сессию в админке.
-- ------------------------------------------------------------

alter table devices enable row level security;
alter table favorite_cities enable row level security;
alter table weather_requests enable row level security;

-- --- devices ---
-- anon может вставлять новую запись устройства
create policy "anon insert own device"
  on devices for insert
  to anon
  with check (true);

-- anon может обновлять только last_seen_at/локацию своего устройства
-- (в реальности ограничить это на уровне "какой именно device_id" через RLS
-- без Auth невозможно железно, поэтому доверяем клиенту передавать свой же id;
-- строгая защита не критична — эти данные не секретные и не про чужой доступ)
create policy "anon update own device"
  on devices for update
  to anon
  using (true)
  with check (true);

-- Только авторизованные (вы через Supabase Auth) видят список устройств
create policy "authenticated read devices"
  on devices for select
  to authenticated
  using (true);

-- --- favorite_cities ---
create policy "anon insert favorite"
  on favorite_cities for insert
  to anon
  with check (true);

create policy "anon update favorite"
  on favorite_cities for update
  to anon
  using (true)
  with check (true);

create policy "authenticated read favorites"
  on favorite_cities for select
  to authenticated
  using (true);

-- --- weather_requests ---
create policy "anon insert request"
  on weather_requests for insert
  to anon
  with check (true);

create policy "authenticated read requests"
  on weather_requests for select
  to authenticated
  using (true);

-- ------------------------------------------------------------
-- 5. Полезные представления (views) для админки — упрощают запросы
-- ------------------------------------------------------------

-- Активные (не удалённые) избранные города прямо сейчас
create or replace view v_active_favorites as
select device_id, city_name, country_code, added_at
from favorite_cities
where removed_at is null;

-- Топ городов по числу запросов погоды за всё время
create or replace view v_top_cities as
select city_name, country_code, count(*) as request_count
from weather_requests
group by city_name, country_code
order by request_count desc;

-- Топ стран по числу запросов
create or replace view v_top_countries as
select country_code, count(*) as request_count
from weather_requests
where country_code is not null
group by country_code
order by request_count desc;

-- Ежедневная активность (DAU) — уникальные устройства в день
create or replace view v_daily_active_users as
select date_trunc('day', requested_at) as day, count(distinct device_id) as active_devices
from weather_requests
group by 1
order by 1;

-- Ежедневные новые устройства
create or replace view v_daily_new_devices as
select date_trunc('day', first_seen_at) as day, count(*) as new_devices
from devices
group by 1
order by 1;
