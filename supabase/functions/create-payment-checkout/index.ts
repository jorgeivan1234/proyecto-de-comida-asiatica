import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing environment variable: ${name}`);
  return value;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization) {
    return jsonResponse({ error: "Authentication is required." }, 401);
  }

  const supabaseUrl = requiredEnv("SUPABASE_URL");
  const anonKey = requiredEnv("SUPABASE_ANON_KEY");
  const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const accessToken = requiredEnv("MP_ACCESS_TOKEN");
  const mpEnvironment = requiredEnv("MP_ENVIRONMENT");
  if (
    (mpEnvironment !== "test" && mpEnvironment !== "production") ||
    (mpEnvironment === "test" && !accessToken.startsWith("TEST-")) ||
    (mpEnvironment === "production" && !accessToken.startsWith("APP_USR-"))
  ) {
    console.error("Mercado Pago environment and access token do not match.");
    return jsonResponse({ error: "Payment provider configuration is invalid." }, 500);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const serviceClient = createClient(supabaseUrl, serviceRoleKey);

  const {
    data: { user },
    error: authError,
  } = await userClient.auth.getUser();
  if (authError || !user) {
    return jsonResponse({ error: "Your session is invalid or expired." }, 401);
  }

  let orderId: number;
  try {
    const body = await request.json();
    orderId = Number(body.order_id);
  } catch {
    return jsonResponse({ error: "Invalid request body." }, 400);
  }
  if (!Number.isSafeInteger(orderId) || orderId <= 0) {
    return jsonResponse({ error: "Invalid order ID." }, 400);
  }

  const { data: order, error: orderError } = await serviceClient
    .from("orders")
    .select(
      "id, user_id, status, payment_provider, total, expires_at, provider_preference_id, checkout_url, order_items(product_name, quantity, unit_price)",
    )
    .eq("id", orderId)
    .eq("user_id", user.id)
    .maybeSingle();

  if (orderError) {
    console.error("Could not load order:", orderError.message);
    return jsonResponse({ error: "Could not load the order." }, 500);
  }
  if (!order) {
    return jsonResponse({ error: "Order not found." }, 404);
  }
  if (order.status !== "pending_payment") {
    return jsonResponse({ error: "This order is not awaiting payment." }, 409);
  }
  if (order.payment_provider !== "mercadopago") {
    return jsonResponse({ error: "This order is not set up for online payment." }, 409);
  }
  if (new Date(order.expires_at).getTime() <= Date.now()) {
    return jsonResponse({ error: "The order reservation has expired." }, 409);
  }
  if (order.checkout_url && order.provider_preference_id) {
    return jsonResponse({
      order_id: order.id,
      checkout_url: order.checkout_url,
    });
  }

  const notificationUrl =
    `${supabaseUrl}/functions/v1/mercadopago-webhook`;
  const preferenceBody = {
    items: order.order_items.map((item: {
      product_name: string;
      quantity: number;
      unit_price: number;
    }) => ({
      title: item.product_name,
      quantity: item.quantity,
      unit_price: Number(item.unit_price),
      currency_id: "MXN",
    })),
    payer: user.email ? { email: user.email } : undefined,
    payment_methods: {
      excluded_payment_types: [
        { id: "ticket" },
        { id: "bank_transfer" },
        { id: "atm" },
        { id: "account_money" },
      ],
    },
    external_reference: String(order.id),
    notification_url: notificationUrl,
    expires: true,
    expiration_date_from: new Date().toISOString(),
    expiration_date_to: order.expires_at,
  };

  let preference: {
    id?: string;
    init_point?: string;
    sandbox_init_point?: string;
  };

  try {
    const response = await fetch("https://api.mercadopago.com/checkout/preferences", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(preferenceBody),
    });
    const result = await response.json();

    if (!response.ok) {
      console.error("Mercado Pago preference request failed:", response.status);
      const { error: cancelError } = await userClient.rpc(
        "cancel_pending_order",
        { p_order_id: order.id },
      );
      if (cancelError) {
        console.error("Could not release order reservation:", cancelError.message);
      }
      return jsonResponse({ error: "The payment checkout could not be created." }, 502);
    }

    preference = result;
  } catch (error) {
    console.error("Mercado Pago request failed:", error);
    const { error: cancelError } = await userClient.rpc(
      "cancel_pending_order",
      { p_order_id: order.id },
    );
    if (cancelError) {
      console.error("Could not release order reservation:", cancelError.message);
    }
    return jsonResponse({ error: "The payment provider is unavailable." }, 502);
  }

  const checkoutUrl = mpEnvironment === "test"
    ? preference.sandbox_init_point
    : preference.init_point;
  if (!preference.id || !checkoutUrl) {
    console.error("Mercado Pago returned an incomplete preference.");
    const { error: cancelError } = await userClient.rpc(
      "cancel_pending_order",
      { p_order_id: order.id },
    );
    if (cancelError) {
      console.error("Could not release order reservation:", cancelError.message);
    }
    return jsonResponse({ error: "The payment provider returned an invalid checkout." }, 502);
  }

  const { error: updateError } = await serviceClient
    .from("orders")
    .update({
      payment_provider: "mercadopago",
      provider_preference_id: preference.id,
      checkout_url: checkoutUrl,
    })
    .eq("id", order.id)
    .eq("user_id", user.id)
    .eq("status", "pending_payment");

  if (updateError) {
    console.error("Could not save Mercado Pago preference:", updateError.message);
    return jsonResponse({ error: "Could not save the payment checkout." }, 500);
  }

  return jsonResponse({ order_id: order.id, checkout_url: checkoutUrl });
});
