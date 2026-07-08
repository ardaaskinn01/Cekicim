-- Enable the pgcrypto and postgis extensions if not already enabled
create extension if not exists postgis;

-- Create the driver_locations table
create table public.driver_locations (
  id uuid references auth.users on delete cascade primary key,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  location geography(Point, 4326) not null,
  bearing double precision default 0.0 not null,
  speed double precision default 0.0 not null
);

-- Enable Row Level Security (RLS)
alter table public.driver_locations enable row level security;

-- Policies
create policy "Allow public read access to driver locations" 
  on public.driver_locations 
  for select 
  using (true);

create policy "Allow authenticated users to update their own location" 
  on public.driver_locations 
  for insert 
  with check (auth.uid() = id);

create policy "Allow authenticated users to update their own location update" 
  on public.driver_locations 
  for update 
  using (auth.uid() = id);

-- Spatial index for fast geographic queries
create index driver_locations_geo_idx on public.driver_locations using gist (location);
