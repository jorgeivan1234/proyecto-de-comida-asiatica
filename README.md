# Comercio electrónico

Aplicación Flutter conectada a Supabase. El catálogo consulta el stock disponible;
los pedidos pendientes reservan existencias sin modificar el stock físico.

## Preparar la base de datos

La migración inicial `20261112000000_place_order_and_decrement_stock.sql` ya se
aplicó manualmente en Supabase. Para actualizar el flujo de pedidos, ejecuta una
sola vez el contenido de
`supabase/migrations/20261113000000_pending_orders_and_stock_reservations.sql`
en Supabase SQL Editor.

Esta migración reemplaza `place_order`: crea el pedido como pendiente de pago,
congela los precios y crea una reserva de hasta 96 horas. El enlace de pago vence
a las 72 horas. El valor de `products.stock` solo baja cuando el webhook valida
un pago aprobado.

## Configurar Mercado Pago

La app usa Checkout Pro para ofrecer los medios disponibles en la cuenta de
Mercado Pago, incluidos tarjeta y OXXO en México. El cliente paga en la página
segura del proveedor; la app nunca recibe ni almacena datos de tarjeta.

1. Crea una aplicación en Mercado Pago y configura notificaciones del evento
   `payment` a la URL de la función `mercadopago-webhook`.
2. Despliega las funciones `create-payment-checkout` y `mercadopago-webhook` en
   el mismo proyecto Supabase.
3. Configura los secretos de las Edge Functions desde un entorno seguro:
   `MP_ACCESS_TOKEN`, `MP_WEBHOOK_SECRET` y `MP_ENVIRONMENT`.
4. Empieza con credenciales de prueba y `MP_ENVIRONMENT=test`. La función solo
   usa el enlace Sandbox si el token empieza con `TEST-`.
5. Cambia a producción únicamente después de probar los pagos y OXXO, y después
   de habilitar la cuenta de vendedor. En producción, la función exige
   `MP_ENVIRONMENT=production` y un token `APP_USR-`.

Nunca agregues el access token ni el secreto del webhook a Flutter, al SQL, al
repositorio ni al chat. Supabase proporciona `SUPABASE_URL`,
`SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` a las funciones; la clave de
servicio solo se usa en el backend.

El boleto de OXXO se genera en el checkout de Mercado Pago. El estado del pago
se actualiza después de validar el webhook; el historial muestra el estado y el
detalle del pedido. Esta integración no emite una factura fiscal CFDI.

## Roles de cliente y administrador

Ejecuta una sola vez
`supabase/migrations/20261114000000_user_roles.sql` en Supabase SQL Editor.
Cada cuenta nueva recibe automáticamente un perfil con rol `client`; el
formulario de registro no ofrece ni envía una opción de rol. La tabla permite a
cada usuario autenticado leer únicamente su propio perfil y no permite cambiar
el rol desde la app.

Para dar permisos de administrador, el dueño del proyecto debe localizar la
cuenta del encargado y actualizar su rol desde Supabase SQL Editor, por ejemplo:

```sql
update public.user_profiles
set role = 'admin'
where id = (
  select id
  from auth.users
  where email = 'correo-del-encargado@example.com'
);
```

Reemplaza el correo de ejemplo por el correo exacto de la cuenta. Para devolver
la cuenta al rol de cliente, cambia `'admin'` por `'client'`. Ejecuta estos
cambios únicamente desde un entorno administrativo confiable; nunca incluyas la
clave `service_role` en Flutter ni la expongas al cliente. Después de cambiar
un rol, el usuario debe cerrar sesión e iniciarla de nuevo para que la app
actualice el permiso mostrado.

La ruta `/admin` verifica el rol guardado en la base de datos y el enlace de
administración solo aparece para cuentas con rol `admin`. El panel todavía no
incluye gestión de productos, pedidos ni métricas; las futuras operaciones
administrativas también deben protegerse en Supabase, no solo ocultarse en la
interfaz.
