alter table public.orders
  add column if not exists payment_status text not null default 'not_started',
  add column if not exists payment_provider text,
  add column if not exists payment_method text,
  add column if not exists provider_preference_id text,
  add column if not exists provider_payment_id text,
  add column if not exists payment_ticket_url text,
  add column if not exists checkout_url text,
  add column if not exists expires_at timestamptz,
  add column if not exists reservation_expires_at timestamptz,
  add column if not exists paid_at timestamptz;

alter table public.orders
  drop constraint if exists orders_status_check;

alter table public.orders
  add constraint orders_status_check
  check (
    status in (
      'confirmed',
      'pending_payment',
      'paid',
      'rejected',
      'cancelled',
      'expired',
      'payment_review',
      'refunded'
    )
  );

alter table public.orders
  drop constraint if exists orders_payment_status_check;

alter table public.orders
  add constraint orders_payment_status_check
  check (
    payment_status in (
      'not_started',
      'pending',
      'in_process',
      'approved',
      'rejected',
      'cancelled',
      'expired',
      'refunded',
      'charged_back'
    )
  );

create table if not exists public.order_stock_reservations (
  order_id bigint not null
    references public.orders(id) on delete cascade,
  product_id integer not null
    references public.products(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  expires_at timestamptz not null,
  primary key (order_id, product_id)
);

create index if not exists order_stock_reservations_product_expiry_idx
on public.order_stock_reservations(product_id, expires_at);

alter table public.order_stock_reservations enable row level security;
revoke all on public.order_stock_reservations from public, anon, authenticated;

create or replace view public.products_available as
select
  product.id,
  product.name,
  product.description,
  product.price,
  product.category,
  product.image,
  greatest(
    product.stock - coalesce(reservations.quantity, 0),
    0
  )::integer as stock
from public.products as product
left join lateral (
  select sum(reservation.quantity)::integer as quantity
  from public.order_stock_reservations as reservation
  join public.orders as reserved_order
    on reserved_order.id = reservation.order_id
  where reservation.product_id = product.id
    and reservation.expires_at > now()
    and reserved_order.status = 'pending_payment'
) as reservations on true;

grant select on public.products_available to anon, authenticated;

create or replace function public.place_order(p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_order_id bigint;
  v_created_at timestamptz;
  v_expires_at timestamptz;
  v_reservation_expires_at timestamptz;
  v_total numeric(10, 2);
  v_order_items jsonb;
  v_item record;
  v_stock integer;
  v_reserved integer;
  v_now timestamptz := now();
begin
  if v_user_id is null then
    raise exception 'Inicia sesión para crear un pedido.';
  end if;

  if p_items is null or jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'Los productos del pedido no son válidos.';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'El carrito está vacío.';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_items) as item(
      product_id integer,
      quantity integer
    )
    where item.product_id is null
       or item.quantity is null
       or item.quantity < 1
  ) then
    raise exception 'El producto o la cantidad del pedido no son válidos.';
  end if;

  update public.orders
  set status = 'expired',
      payment_status = 'expired'
  where status = 'pending_payment'
    and reservation_expires_at <= v_now;

  delete from public.order_stock_reservations
  where expires_at <= v_now;

  for v_item in
    select item.product_id, sum(item.quantity)::integer as quantity
    from jsonb_to_recordset(p_items) as item(
      product_id integer,
      quantity integer
    )
    group by item.product_id
    order by item.product_id
  loop
    select product.stock
    into v_stock
    from public.products as product
    where product.id = v_item.product_id
    for update;

    if not found then
      raise exception 'No se encontró el producto con ID %.',
        v_item.product_id;
    end if;

    select coalesce(sum(reservation.quantity), 0)::integer
    into v_reserved
    from public.order_stock_reservations as reservation
    join public.orders as reserved_order
      on reserved_order.id = reservation.order_id
    where reservation.product_id = v_item.product_id
      and reservation.expires_at > v_now
      and reserved_order.status = 'pending_payment';

    if v_stock - v_reserved < v_item.quantity then
      raise exception 'Existencias insuficientes para el producto con ID %.',
        v_item.product_id;
    end if;
  end loop;

  v_expires_at := v_now + interval '72 hours';
  v_reservation_expires_at := v_expires_at + interval '24 hours';

  insert into public.orders (
    user_id,
    status,
    payment_status,
    expires_at,
    reservation_expires_at
  )
  values (
    v_user_id,
    'pending_payment',
    'pending',
    v_expires_at,
    v_reservation_expires_at
  )
  returning id, created_at into v_order_id, v_created_at;

  insert into public.order_items (
    order_id,
    product_id,
    product_name,
    quantity,
    unit_price
  )
  select
    v_order_id,
    product.id,
    product.name,
    item.quantity,
    product.price
  from (
    select item.product_id, sum(item.quantity)::integer as quantity
    from jsonb_to_recordset(p_items) as item(
      product_id integer,
      quantity integer
    )
    group by item.product_id
  ) as item
  join public.products as product on product.id = item.product_id;

  insert into public.order_stock_reservations (
    order_id,
    product_id,
    quantity,
    expires_at
  )
  select
    v_order_id,
    item.product_id,
    item.quantity,
    v_reservation_expires_at
  from (
    select item.product_id, sum(item.quantity)::integer as quantity
    from jsonb_to_recordset(p_items) as item(
      product_id integer,
      quantity integer
    )
    group by item.product_id
  ) as item;

  select coalesce(sum(detail.subtotal), 0)
  into v_total
  from public.order_items as detail
  where detail.order_id = v_order_id;

  update public.orders
  set total = v_total
  where id = v_order_id;

  select jsonb_agg(
    jsonb_build_object(
      'product_id', detail.product_id,
      'product_name', detail.product_name,
      'quantity', detail.quantity,
      'unit_price', detail.unit_price
    )
    order by detail.id
  )
  into v_order_items
  from public.order_items as detail
  where detail.order_id = v_order_id;

  return jsonb_build_object(
    'id', v_order_id,
    'created_at', v_created_at,
    'status', 'pending_payment',
    'payment_status', 'pending',
    'total', v_total,
    'expires_at', v_expires_at,
    'reservation_expires_at', v_reservation_expires_at,
    'items', v_order_items
  );
end;
$$;

revoke all on function public.place_order(jsonb) from public, anon;
grant execute on function public.place_order(jsonb) to authenticated;

create unique index if not exists orders_provider_payment_id_key
on public.orders(provider_payment_id)
where provider_payment_id is not null;

create or replace function public.expire_my_pending_orders()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'Inicia sesión para consultar tus pedidos.';
  end if;

  update public.orders
  set status = 'expired',
      payment_status = 'expired'
  where user_id = v_user_id
    and status = 'pending_payment'
    and reservation_expires_at <= now();

  delete from public.order_stock_reservations as reservation
  where reservation.order_id in (
    select id
    from public.orders
    where user_id = v_user_id
      and status = 'expired'
      and reservation_expires_at <= now()
  );
end;
$$;

revoke all on function public.expire_my_pending_orders() from public, anon;
grant execute on function public.expire_my_pending_orders() to authenticated;

create or replace function public.process_mp_payment(
  p_order_id bigint,
  p_payment_id text,
  p_provider_status text,
  p_amount numeric,
  p_currency text,
  p_payment_created_at timestamptz,
  p_approved_at timestamptz,
  p_payment_method text,
  p_payment_ticket_url text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders%rowtype;
  v_item record;
  v_stock integer;
begin
  select *
  into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'No se encontró el pedido.';
  end if;

  if p_provider_status = 'refunded' then
    if v_order.provider_payment_id is distinct from p_payment_id then
      return jsonb_build_object('result', 'refund_recorded');
    end if;

    update public.orders
    set status = 'refunded',
        payment_status = 'refunded',
        provider_payment_id = p_payment_id
    where id = p_order_id;

    delete from public.order_stock_reservations
    where order_id = p_order_id;

    return jsonb_build_object('result', 'refunded');
  end if;

  if p_provider_status = 'charged_back' then
    if v_order.provider_payment_id is distinct from p_payment_id then
      return jsonb_build_object('result', 'chargeback_recorded');
    end if;

    update public.orders
    set status = 'payment_review',
        payment_status = 'charged_back',
        provider_payment_id = p_payment_id
    where id = p_order_id;

    return jsonb_build_object('result', 'charged_back');
  end if;

  if v_order.status = 'paid' then
    if v_order.provider_payment_id = p_payment_id then
      return jsonb_build_object('result', 'already_paid');
    end if;

    return jsonb_build_object('result', 'refund_required');
  end if;

  if p_provider_status in ('pending', 'in_process') then
    if v_order.status = 'pending_payment' then
      update public.orders
      set payment_status = p_provider_status,
          provider_payment_id = p_payment_id,
          payment_method = p_payment_method,
          payment_ticket_url = p_payment_ticket_url
      where id = p_order_id;
    end if;

    return jsonb_build_object('result', 'pending');
  end if;

  if p_provider_status in ('rejected', 'cancelled') then
    if v_order.status = 'pending_payment' then
      update public.orders
      set payment_status = p_provider_status,
          provider_payment_id = p_payment_id,
          payment_method = p_payment_method,
          payment_ticket_url = p_payment_ticket_url
      where id = p_order_id;
    end if;

    return jsonb_build_object('result', p_provider_status);
  end if;

  if p_provider_status = 'expired' then
    if v_order.status = 'pending_payment' then
      update public.orders
      set status = 'expired',
          payment_status = 'expired',
          provider_payment_id = p_payment_id
      where id = p_order_id;

      delete from public.order_stock_reservations
      where order_id = p_order_id;
    end if;

    return jsonb_build_object('result', 'expired');
  end if;

  if p_provider_status <> 'approved' then
    return jsonb_build_object('result', 'ignored');
  end if;

  if p_currency is distinct from 'MXN'
     or p_amount is null
     or p_amount <> v_order.total then
    update public.orders
    set status = 'payment_review',
        payment_status = 'approved',
        provider_payment_id = p_payment_id,
        payment_method = p_payment_method,
        payment_ticket_url = p_payment_ticket_url
    where id = p_order_id;

    return jsonb_build_object('result', 'refund_required');
  end if;

  if v_order.status <> 'pending_payment'
     or v_order.expires_at is null
     or p_payment_created_at is null
     or p_payment_created_at > v_order.expires_at
     or not exists (
       select 1
       from public.order_stock_reservations as reservation
       where reservation.order_id = p_order_id
         and reservation.expires_at > now()
     ) then
    update public.orders
    set status = 'payment_review',
        payment_status = 'approved',
        provider_payment_id = p_payment_id,
        payment_method = p_payment_method,
        payment_ticket_url = p_payment_ticket_url
    where id = p_order_id;

    return jsonb_build_object('result', 'refund_required');
  end if;

  for v_item in
    select product_id, quantity
    from public.order_items
    where order_id = p_order_id
    order by product_id
  loop
    if v_item.product_id is null then
      update public.orders
      set status = 'payment_review',
          payment_status = 'approved',
          provider_payment_id = p_payment_id
      where id = p_order_id;

      return jsonb_build_object('result', 'refund_required');
    end if;

    select stock
    into v_stock
    from public.products
    where id = v_item.product_id
    for update;

    if not found or v_stock < v_item.quantity then
      update public.orders
      set status = 'payment_review',
          payment_status = 'approved',
          provider_payment_id = p_payment_id
      where id = p_order_id;

      return jsonb_build_object('result', 'refund_required');
    end if;
  end loop;

  update public.products as product
  set stock = product.stock - detail.quantity
  from public.order_items as detail
  where detail.order_id = p_order_id
    and detail.product_id = product.id;

  update public.orders
  set status = 'paid',
      payment_status = 'approved',
      provider_payment_id = p_payment_id,
      payment_method = p_payment_method,
      payment_ticket_url = p_payment_ticket_url,
      paid_at = p_approved_at
  where id = p_order_id;

  delete from public.order_stock_reservations
  where order_id = p_order_id;

  return jsonb_build_object('result', 'paid');
end;
$$;

revoke all on function public.process_mp_payment(
  bigint, text, text, numeric, text, timestamptz, timestamptz, text, text
) from public, anon, authenticated;
grant execute on function public.process_mp_payment(
  bigint, text, text, numeric, text, timestamptz, timestamptz, text, text
) to service_role;

create or replace function public.mark_mp_payment_refunded(
  p_order_id bigint,
  p_payment_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.orders
  set status = 'refunded',
      payment_status = 'refunded'
  where id = p_order_id
    and provider_payment_id = p_payment_id
    and status = 'payment_review';

  delete from public.order_stock_reservations
  where order_id = p_order_id;
end;
$$;

revoke all on function public.mark_mp_payment_refunded(bigint, text)
from public, anon, authenticated;
grant execute on function public.mark_mp_payment_refunded(bigint, text)
to service_role;

create or replace function public.cancel_pending_order(p_order_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'Inicia sesión para cancelar el pedido.';
  end if;

  update public.orders
  set status = 'cancelled',
      payment_status = 'cancelled'
  where id = p_order_id
    and user_id = v_user_id
    and status = 'pending_payment';

  delete from public.order_stock_reservations as reservation
  where reservation.order_id = p_order_id
    and exists (
      select 1
      from public.orders
      where orders.id = reservation.order_id
        and orders.user_id = v_user_id
        and orders.status = 'cancelled'
    );
end;
$$;

revoke all on function public.cancel_pending_order(bigint) from public, anon;
grant execute on function public.cancel_pending_order(bigint) to authenticated;
