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

function asRecord(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === "object"
    ? value as Record<string, unknown>
    : null;
}

function firstString(...values: unknown[]): string | null {
  for (const value of values) {
    if (typeof value === "string" && value.length > 0) return value;
  }
  return null;
}

function firstNumber(...values: unknown[]): number | null {
  for (const value of values) {
    if (value === null || value === undefined || value === "") continue;
    const number = Number(value);
    if (Number.isFinite(number)) return number;
  }
  return null;
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
  const data = asRecord(event.data);
  const dataId = String(url.searchParams.get("data.id") ?? data?.id ?? "");
  const topic = String(
    event.type ??
      event.topic ??
      url.searchParams.get("topic") ??
      url.searchParams.get("type") ??
      "",
  ).toLowerCase();

  if (!["orders_v2", "order", "orders"].includes(topic) || !dataId) {
    return jsonResponse({ received: true, ignored: true });
  }
  if (!await verifySignature(request, dataId, webhookSecret)) {
    return jsonResponse({ error: "Invalid webhook signature." }, 401);
  }

  let orderResponse: Response;
  try {
    orderResponse = await fetch(
      `https://api.mercadopago.com/v1/orders/${encodeURIComponent(dataId)}`,
      { headers: { Authorization: `Bearer ${accessToken}` } },
    );
  } catch (error) {
    console.error("Mercado Pago order request failed:", error);
    return jsonResponse({ error: "Could not verify order." }, 502);
  }

  const mercadoPagoOrder = await orderResponse.json();
  if (!orderResponse.ok) {
    console.error("Could not verify Mercado Pago order:", orderResponse.status);
    return jsonResponse({ error: "Could not verify order." }, 502);
  }
  if (String(mercadoPagoOrder.id) !== dataId) {
    return jsonResponse({ error: "Order ID mismatch." }, 400);
  }

  const orderId = Number(mercadoPagoOrder.external_reference);
  if (!Number.isSafeInteger(orderId) || orderId <= 0) {
    return jsonResponse({ error: "Invalid order reference." }, 400);
  }

  const serviceClient = createClient(supabaseUrl, serviceRoleKey);
  const { data: localOrder, error: localOrderError } = await serviceClient
    .from("orders")
    .select("provider_order_id, provider_payment_id")
    .eq("id", orderId)
    .maybeSingle();

  if (localOrderError) {
    console.error("Could not load local order:", localOrderError.message);
    return jsonResponse({ error: "Could not load local order." }, 500);
  }
  if (!localOrder) {
    return jsonResponse({ received: true, ignored: true });
  }
  if (!localOrder.provider_order_id) {
    return jsonResponse({ error: "Order checkout is not saved yet." }, 503);
  }
  if (localOrder.provider_order_id !== dataId) {
    return jsonResponse({ received: true, ignored: true });
  }

  const transactionData = asRecord(mercadoPagoOrder.transactions);
  const paymentEntries = Array.isArray(transactionData?.payments)
    ? transactionData.payments
    : [];
  const payment = asRecord(paymentEntries[paymentEntries.length - 1]);
  const paymentMethod = asRecord(payment?.payment_method);
  const paymentId = firstString(payment?.id, localOrder.provider_payment_id);

  const statusMap: Record<string, string> = {
    created: "pending",
    processing: "in_process",
    action_required: "in_process",
    processed: "approved",
    failed: "rejected",
    canceled: "cancelled",
    refunded: "refunded",
  };
  const providerStatus = statusMap[String(mercadoPagoOrder.status)];
  if (!providerStatus) {
    return jsonResponse({ received: true, ignored: true });
  }
  if (
    (providerStatus === "approved" || providerStatus === "refunded") &&
    !paymentId
  ) {
    console.error("Mercado Pago order has no payment transaction ID.");
    return jsonResponse(
      { error: "Order payment details are incomplete." },
      502,
    );
  }

  const paymentCreatedAt = firstString(
    payment?.date_created,
    mercadoPagoOrder.last_updated_date,
    mercadoPagoOrder.created_date,
  );
  const approvedAt = firstString(
    payment?.date_approved,
    payment?.date_last_updated,
    mercadoPagoOrder.last_updated_date,
  ) ?? new Date().toISOString();
  const paymentAmount = firstNumber(
    payment?.paid_amount,
    mercadoPagoOrder.total_paid_amount,
    payment?.amount,
    mercadoPagoOrder.total_amount,
  );
  const ticketUrl = firstString(paymentMethod?.ticket_url);

  const { data: result, error: processError } = await serviceClient.rpc(
    "process_mp_payment",
    {
      p_order_id: orderId,
      p_payment_id: paymentId,
      p_provider_status: providerStatus,
      p_amount: paymentAmount,
      p_currency: firstString(mercadoPagoOrder.currency, payment?.currency_id),
      p_payment_created_at: paymentCreatedAt,
      p_approved_at: approvedAt,
      p_payment_method: firstString(
        paymentMethod?.id,
        payment?.payment_method_id,
      ),
      p_payment_ticket_url: ticketUrl,
    },
  );

  if (processError) {
    console.error("Could not update order payment:", processError.message);
    return jsonResponse({ error: "Could not update order payment." }, 500);
  }

  if (result?.result === "refund_required") {
    const refundResponse = await fetch(
      `https://api.mercadopago.com/v1/orders/${
        encodeURIComponent(dataId)
      }/refund`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
          "X-Idempotency-Key": `refund-${dataId}-${paymentId}`,
        },
        body: JSON.stringify({}),
      },
    );

    if (!refundResponse.ok) {
      console.error("Automatic payment refund failed:", refundResponse.status);
      return jsonResponse(
        { error: "Payment requires manual refund review." },
        500,
      );
    }

    const { error: refundUpdateError } = await serviceClient.rpc(
      "mark_mp_payment_refunded",
      { p_order_id: orderId, p_payment_id: paymentId },
    );
    if (refundUpdateError) {
      console.error(
        "Could not record payment refund:",
        refundUpdateError.message,
      );
      return jsonResponse({
        error: "Refund succeeded but order update failed.",
      }, 500);
    }
  }

  return jsonResponse({
    received: true,
    result: result?.result ?? "processed",
  });
});
