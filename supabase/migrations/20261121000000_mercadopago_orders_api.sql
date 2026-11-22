alter table public.orders
  add column if not exists provider_order_id text,
  add column if not exists provider_idempotency_key uuid;

create unique index if not exists orders_provider_order_id_key
on public.orders(provider_order_id)
where provider_order_id is not null;

create unique index if not exists orders_provider_idempotency_key_key
on public.orders(provider_idempotency_key)
where provider_idempotency_key is not null;
