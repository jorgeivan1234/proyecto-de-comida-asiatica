alter table public.orders
  add column if not exists payment_provider text,
  add column if not exists payment_method text,
  add column if not exists fulfillment_method text not null default 'pickup',
  add column if not exists delivery_address text,
  add column if not exists fulfillment_status text not null default 'pending';

alter table public.orders
  drop constraint if exists orders_fulfillment_method_check;

alter table public.orders
  add constraint orders_fulfillment_method_check
  check (fulfillment_method in ('pickup', 'delivery'));

alter table public.orders
  drop constraint if exists orders_fulfillment_status_check;

alter table public.orders
  add constraint orders_fulfillment_status_check
  check (
    fulfillment_status in (
      'pending',
      'preparing',
      'shipped',
      'delivered',
      'ready_for_pickup',
      'picked_up'
    )
  );

create or replace function public.place_order_with_options(
  p_items jsonb,
  p_fulfillment_method text,
  p_delivery_address text,
  p_payment_method text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_order jsonb;
  v_order_id bigint;
begin
  if v_user_id is null then
    raise exception 'Inicia sesión para crear un pedido.';
  end if;

  if p_fulfillment_method is null
     or p_fulfillment_method not in ('pickup', 'delivery') then
    raise exception 'La modalidad de entrega no es válida.';
  end if;

  if p_payment_method is null
     or p_payment_method not in ('cash', 'online') then
    raise exception 'El método de pago no es válido.';
  end if;

  if p_fulfillment_method = 'delivery'
     and nullif(trim(p_delivery_address), '') is null then
    raise exception 'Escribe la dirección de entrega.';
  end if;

  v_order := public.place_order(p_items);
  v_order_id := (v_order ->> 'id')::bigint;

  update public.orders
  set fulfillment_method = p_fulfillment_method,
      delivery_address = case
        when p_fulfillment_method = 'delivery' then trim(p_delivery_address)
        else null
      end,
      payment_provider = case
        when p_payment_method = 'cash' then 'cash'
        else 'mercadopago'
      end,
      payment_method = p_payment_method
  where id = v_order_id
    and user_id = v_user_id
    and status = 'pending_payment'
    and payment_status = 'pending'
    and provider_preference_id is null
    and provider_payment_id is null;

  if not found then
    raise exception 'No se pudo guardar la modalidad y el método de pago.';
  end if;

  return v_order;
end;
$$;

revoke all on function public.place_order_with_options(
  jsonb, text, text, text
) from public, anon;
grant execute on function public.place_order_with_options(
  jsonb, text, text, text
) to authenticated;

create or replace function public.confirm_cash_order_payment(p_order_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_order public.orders%rowtype;
  v_item record;
  v_stock integer;
begin
  if v_user_id is null or not exists (
    select 1
    from public.user_profiles as profile
    where profile.id = v_user_id
      and profile.role = 'admin'
  ) then
    raise exception 'No tienes permiso para confirmar pagos en efectivo.';
  end if;

  select *
  into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'No se encontró el pedido.';
  end if;

  if v_order.status = 'paid'
     and v_order.payment_provider = 'cash'
     and v_order.payment_method = 'cash' then
    return jsonb_build_object('result', 'already_paid');
  end if;

  if v_order.status is distinct from 'pending_payment'
     or v_order.payment_status is distinct from 'pending'
     or v_order.payment_provider is distinct from 'cash'
     or v_order.payment_method is distinct from 'cash' then
    raise exception 'El pedido no está pendiente de pago en efectivo.';
  end if;

  if v_order.reservation_expires_at is null
     or v_order.reservation_expires_at <= now()
     or not exists (
       select 1
       from public.order_stock_reservations as reservation
       where reservation.order_id = p_order_id
         and reservation.expires_at > now()
     ) then
    raise exception 'La reserva del pedido venció; no se puede confirmar el pago.';
  end if;

  for v_item in
    select product_id, quantity
    from public.order_items
    where order_id = p_order_id
    order by product_id
  loop
    if v_item.product_id is null then
      raise exception 'Un producto del pedido ya no está disponible.';
    end if;

    select stock
    into v_stock
    from public.products
    where id = v_item.product_id
    for update;

    if not found or v_stock < v_item.quantity then
      raise exception 'No hay existencias suficientes para confirmar el pedido.';
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
      paid_at = now()
  where id = p_order_id;

  delete from public.order_stock_reservations
  where order_id = p_order_id;

  return jsonb_build_object('result', 'paid');
end;
$$;

revoke all on function public.confirm_cash_order_payment(bigint)
from public, anon;
grant execute on function public.confirm_cash_order_payment(bigint)
to authenticated;

revoke update on public.orders from public, anon, authenticated;
grant update (fulfillment_status) on public.orders to authenticated;

drop policy if exists orders_admin_select on public.orders;
create policy orders_admin_select
on public.orders
for select
to authenticated
using (
  exists (
    select 1
    from public.user_profiles as profile
    where profile.id = (select auth.uid())
      and profile.role = 'admin'
  )
);

drop policy if exists orders_admin_update_fulfillment on public.orders;
create policy orders_admin_update_fulfillment
on public.orders
for update
to authenticated
using (
  status = 'paid'
  and payment_status = 'approved'
  and exists (
    select 1
    from public.user_profiles as profile
    where profile.id = (select auth.uid())
      and profile.role = 'admin'
  )
)
with check (
  status = 'paid'
  and payment_status = 'approved'
  and exists (
    select 1
    from public.user_profiles as profile
    where profile.id = (select auth.uid())
      and profile.role = 'admin'
  )
);

drop policy if exists order_items_admin_select on public.order_items;
create policy order_items_admin_select
on public.order_items
for select
to authenticated
using (
  exists (
    select 1
    from public.orders
    where orders.id = order_items.order_id
      and exists (
        select 1
        from public.user_profiles as profile
        where profile.id = (select auth.uid())
          and profile.role = 'admin'
      )
  )
);
