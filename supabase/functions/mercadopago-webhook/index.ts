import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing environment variable: ${name}`);
  return value;
}

function timingSafeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index++) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

async function verifySignature(
  request: Request,
  dataId: string,
  secret: string,
): Promise<boolean> {
  const signatureHeader = request.headers.get("x-signature");
  const requestId = request.headers.get("x-request-id");
  if (!signatureHeader || !requestId) return false;

  const signatureParts = Object.fromEntries(
    signatureHeader.split(",").map((part) => {
      const [key, ...valueParts] = part.trim().split("=");
      return [key, valueParts.join("=")];
    }),
  );
  const timestamp = signatureParts.ts;
  const receivedSignature = signatureParts.v1;
  if (!timestamp || !receivedSignature) return false;

  const manifest =
    `id:${dataId.toLowerCase()};request-id:${requestId};ts:${timestamp};`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(manifest),
  );
  const expectedSignature = Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");

  return timingSafeEqual(receivedSignature, expectedSignature);
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const supabaseUrl = requiredEnv("SUPABASE_URL");
  const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const accessToken = requiredEnv("MP_ACCESS_TOKEN");
  const webhookSecret = requiredEnv("MP_WEBHOOK_SECRET");

  let event: Record<string, unknown>;
  try {
    event = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid notification body." }, 400);
  }

  const url = new URL(request.url);
  const data = event.data as Record<string, unknown> | undefined;
  const dataId = String(url.searchParams.get("data.id") ?? data?.id ?? "");
  const topic = String(event.type ?? event.topic ?? url.searchParams.get("topic") ?? "");

  if (topic !== "payment" || !dataId) {
    return jsonResponse({ received: true, ignored: true });
  }
  if (!await verifySignature(request, dataId, webhookSecret)) {
    return jsonResponse({ error: "Invalid webhook signature." }, 401);
  }

  const paymentResponse = await fetch(
    `https://api.mercadopago.com/v1/payments/${encodeURIComponent(dataId)}`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );
  const payment = await paymentResponse.json();
  if (!paymentResponse.ok) {
    console.error("Could not verify Mercado Pago payment:", paymentResponse.status);
    return jsonResponse({ error: "Could not verify payment." }, 502);
  }
  if (String(payment.id) !== dataId) {
    return jsonResponse({ error: "Payment ID mismatch." }, 400);
  }

  const orderId = Number(payment.external_reference);
  if (!Number.isSafeInteger(orderId) || orderId <= 0) {
    return jsonResponse({ error: "Invalid order reference." }, 400);
  }

  const supportedStatuses = new Set([
    "pending",
    "in_process",
    "approved",
    "rejected",
    "cancelled",
    "expired",
    "refunded",
    "charged_back",
  ]);
  if (!supportedStatuses.has(payment.status)) {
    return jsonResponse({ received: true, ignored: true });
  }

  const ticketUrl =
    payment.point_of_interaction?.transaction_data?.ticket_url ??
    payment.transaction_details?.external_resource_url ??
    null;
  const serviceClient = createClient(supabaseUrl, serviceRoleKey);
  const { data: result, error: processError } = await serviceClient.rpc(
    "process_mp_payment",
    {
      p_order_id: orderId,
      p_payment_id: String(payment.id),
      p_provider_status: payment.status,
      p_amount: payment.transaction_amount,
      p_currency: payment.currency_id,
      p_payment_created_at: payment.date_created,
      p_approved_at: payment.date_approved ?? new Date().toISOString(),
      p_payment_method: payment.payment_method_id ?? null,
      p_payment_ticket_url: ticketUrl,
    },
  );

  if (processError) {
    console.error("Could not update order payment:", processError.message);
    return jsonResponse({ error: "Could not update order payment." }, 500);
  }

  if (result?.result === "refund_required") {
    const refundResponse = await fetch(
      `https://api.mercadopago.com/v1/payments/${encodeURIComponent(dataId)}/refunds`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
          "X-Idempotency-Key": `order-${orderId}-payment-${dataId}-refund`,
        },
        body: JSON.stringify({}),
      },
    );

    if (!refundResponse.ok) {
      console.error("Automatic payment refund failed:", refundResponse.status);
      return jsonResponse({ error: "Payment requires manual refund review." }, 500);
    }

    const { error: refundUpdateError } = await serviceClient.rpc(
      "mark_mp_payment_refunded",
      { p_order_id: orderId, p_payment_id: String(payment.id) },
    );
    if (refundUpdateError) {
      console.error("Could not record payment refund:", refundUpdateError.message);
      return jsonResponse({ error: "Refund succeeded but order update failed." }, 500);
    }
  }

  return jsonResponse({ received: true, result: result?.result ?? "processed" });
});
