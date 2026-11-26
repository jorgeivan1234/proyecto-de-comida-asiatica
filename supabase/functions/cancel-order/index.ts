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

  let orderId: number;
  let refundDestination: string;
  try {
    const body = await request.json();
    orderId = Number(body.order_id);
    refundDestination = String(body.refund_destination ?? "");
  } catch {
    return jsonResponse({ error: "Invalid request body." }, 400);
  }
  if (!Number.isSafeInteger(orderId) || orderId <= 0) {
    return jsonResponse({ error: "Invalid order ID." }, 400);
  }

  const supabaseUrl = requiredEnv("SUPABASE_URL");
  const anonKey = requiredEnv("SUPABASE_ANON_KEY");
  const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
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

  const { data: result, error: cancelError } = await userClient.rpc(
    "cancel_my_order",
    {
      p_order_id: orderId,
      p_refund_destination: refundDestination,
    },
  );
  if (cancelError) {
    return jsonResponse({ error: cancelError.message }, 409);
  }
  if (result === null || typeof result !== "object") {
    return jsonResponse({ error: "Invalid cancellation response." }, 500);
  }

  const cancellation = result as Record<string, unknown>;
  if (cancellation.result !== "refund_pending") {
    return jsonResponse(cancellation);
  }

  const providerOrderId = cancellation.provider_order_id;
  if (typeof providerOrderId !== "string" || providerOrderId.length === 0) {
    console.error("Cancelled order has no Mercado Pago order ID.");
    return jsonResponse({
      error: "El pedido se canceló, pero falta el identificador del pago.",
    }, 500);
  }

  let refundResponse: Response;
  try {
    refundResponse = await fetch(
      `https://api.mercadopago.com/v1/orders/${
        encodeURIComponent(providerOrderId)
      }/refund`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${requiredEnv("MP_ACCESS_TOKEN")}`,
          "Content-Type": "application/json",
          "X-Idempotency-Key": `refund-${providerOrderId}`,
        },
        body: JSON.stringify({}),
      },
    );
  } catch (error) {
    console.error("Mercado Pago cancellation refund failed:", error);
    return jsonResponse({
      error: "El pedido se canceló; el reembolso quedó pendiente para reintento.",
    }, 502);
  }

  if (!refundResponse.ok) {
    console.error(
      "Mercado Pago cancellation refund failed:",
      refundResponse.status,
    );
    return jsonResponse({
      error: "El pedido se canceló; el reembolso quedó pendiente para reintento.",
    }, 502);
  }

  const { error: recordRefundError } = await serviceClient.rpc(
    "mark_cancelled_mp_refund",
    { p_order_id: orderId },
  );
  if (recordRefundError) {
    console.error(
      "Could not record cancellation refund:",
      recordRefundError.message,
    );
    return jsonResponse({
      error: "El reembolso se envió, pero no se pudo actualizar su estado.",
    }, 500);
  }

  return jsonResponse({
    ...cancellation,
    result: "refund_requested",
  });
});
