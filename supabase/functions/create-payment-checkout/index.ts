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

function isMercadoPagoCheckoutUrl(value: string): boolean {
  try {
    const url = new URL(value);
    const allowedHosts = ["mercadopago.com", "mercadopago.com.mx"];
    return url.protocol === "https:" &&
      allowedHosts.some((host) =>
        url.hostname === host || url.hostname.endsWith(`.${host}`)
      );
  } catch {
    return false;
  }
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
  if (mpEnvironment !== "test" && mpEnvironment !== "production") {
    console.error("MP_ENVIRONMENT must be 'test' or 'production'.");
    return jsonResponse(
      { error: "Payment provider configuration is invalid." },
      500,
    );
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
      "id, user_id, status, payment_provider, total, expires_at, provider_order_id, provider_idempotency_key, checkout_url, order_items(product_name, quantity, unit_price)",
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
    return jsonResponse({
      error: "This order is not set up for online payment.",
    }, 409);
  }
  if (new Date(order.expires_at).getTime() <= Date.now()) {
    return jsonResponse({ error: "The order reservation has expired." }, 409);
  }
  if (order.checkout_url && order.provider_order_id) {
    return jsonResponse({
      order_id: order.id,
      checkout_url: order.checkout_url,
    });
  }

  let idempotencyKey = order.provider_idempotency_key as string | null;
  if (!idempotencyKey) {
    const candidateKey = crypto.randomUUID();
    const { error: saveKeyError } = await serviceClient
      .from("orders")
      .update({ provider_idempotency_key: candidateKey })
      .eq("id", order.id)
      .eq("user_id", user.id)
      .eq("status", "pending_payment")
      .is("provider_idempotency_key", null);

    if (saveKeyError) {
      console.error(
        "Could not save Mercado Pago idempotency key:",
        saveKeyError.message,
      );
      return jsonResponse(
        { error: "Could not prepare the payment checkout." },
        500,
      );
    }

    const { data: latestOrder, error: reloadError } = await serviceClient
      .from("orders")
      .select("provider_order_id, provider_idempotency_key, checkout_url")
      .eq("id", order.id)
      .eq("user_id", user.id)
      .maybeSingle();

    if (reloadError || !latestOrder?.provider_idempotency_key) {
      console.error(
        "Could not reload Mercado Pago checkout data:",
        reloadError?.message ?? "Idempotency key was not saved.",
      );
      return jsonResponse(
        { error: "Could not prepare the payment checkout." },
        500,
      );
    }

    if (latestOrder.checkout_url && latestOrder.provider_order_id) {
      return jsonResponse({
        order_id: order.id,
        checkout_url: latestOrder.checkout_url,
      });
    }

    idempotencyKey = latestOrder.provider_idempotency_key;
  }

  if (!idempotencyKey) {
    console.error("Mercado Pago idempotency key is unavailable.");
    return jsonResponse(
      { error: "Could not prepare the payment checkout." },
      500,
    );
  }

  const items = order.order_items.map((item: {
    product_name: string;
    quantity: number;
    unit_price: number;
  }) => ({
    title: item.product_name,
    quantity: item.quantity,
    unit_price: Number(item.unit_price).toFixed(2),
  }));
  const orderTotal = Number(order.total);
  const itemsTotal = items.reduce(
    (total: number, item: { quantity: number; unit_price: string }) =>
      total + item.quantity * Number(item.unit_price),
    0,
  );
  if (
    !Number.isFinite(orderTotal) ||
    orderTotal <= 0 ||
    items.length === 0 ||
    Math.round(itemsTotal * 100) !== Math.round(orderTotal * 100)
  ) {
    console.error("Stored order total does not match its items.");
    return jsonResponse({ error: "The order total is invalid." }, 409);
  }

  const orderBody = {
    type: "online",
    processing_mode: "manual",
    capture_mode: "automatic_async",
    total_amount: orderTotal.toFixed(2),
    external_reference: String(order.id),
    payer: user.email ? { email: user.email } : undefined,
    items,
    config: {
      payment_method: {
        not_allowed_types: ["ticket", "bank_transfer", "atm", "account_money"],
      },
    },
  };

  let mercadoPagoOrder: {
    id?: string;
    checkout_url?: string;
    message?: string;
    error?: string;
  };

  try {
    const response = await fetch("https://api.mercadopago.com/v1/orders", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        "X-Idempotency-Key": idempotencyKey,
      },
      body: JSON.stringify(orderBody),
    });
    const result = await response.json() as typeof mercadoPagoOrder;

    if (!response.ok) {
      console.error(
        "Mercado Pago order request failed:",
        response.status,
        result.error ?? result.message ?? "No provider message.",
      );
      return jsonResponse({
        error: "The payment checkout could not be created.",
      }, 502);
    }

    mercadoPagoOrder = result;
  } catch (error) {
    console.error("Mercado Pago request failed:", error);
    return jsonResponse({ error: "The payment provider is unavailable." }, 502);
  }

  if (
    !mercadoPagoOrder.id ||
    !mercadoPagoOrder.checkout_url ||
    !isMercadoPagoCheckoutUrl(mercadoPagoOrder.checkout_url)
  ) {
    console.error("Mercado Pago returned an invalid order checkout URL.");
    return jsonResponse({
      error: "The payment provider returned an invalid checkout.",
    }, 502);
  }

  const { error: updateError } = await serviceClient
    .from("orders")
    .update({
      payment_provider: "mercadopago",
      provider_order_id: mercadoPagoOrder.id,
      checkout_url: mercadoPagoOrder.checkout_url,
    })
    .eq("id", order.id)
    .eq("user_id", user.id)
    .eq("status", "pending_payment");

  if (updateError) {
    console.error("Could not save Mercado Pago order:", updateError.message);
    return jsonResponse({ error: "Could not save the payment checkout." }, 500);
  }

  return jsonResponse({
    order_id: order.id,
    checkout_url: mercadoPagoOrder.checkout_url,
  });
});
