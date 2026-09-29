-- Messages table
create table public.messages (
  id uuid default gen_random_uuid() primary key,
  request_id uuid references public.service_requests(id) on delete cascade not null,
  sender_id uuid references auth.users(id) on delete cascade not null,
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable Row Level Security (RLS)
alter table public.messages enable row level security;

-- Policies for Messages
create policy "Users can view messages for their service requests"
  on public.messages for select
  using (
    auth.uid() in (
      select customer_id from public.service_requests where id = request_id
      union
      select driver_id from public.service_requests where id = request_id
    )
  );

create policy "Users can insert messages into their active requests"
  on public.messages for insert
  with check (
    auth.uid() = sender_id and (
      auth.uid() in (
        select customer_id from public.service_requests where id = request_id
        union
        select driver_id from public.service_requests where id = request_id
      )
    )
  );
