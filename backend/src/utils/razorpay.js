// Razorpay integration (REST API, no SDK). Keys live only in .env:
//   RAZORPAY_KEY_ID        rzp_live_xxx / rzp_test_xxx  (public, sent to the app)
//   RAZORPAY_KEY_SECRET    secret — never leaves the server
//   RAZORPAY_WEBHOOK_SECRET (optional) secret set on the webhook in the Razorpay dashboard
const crypto = require('crypto');
const { ApiError } = require('./helpers');

const API = 'https://api.razorpay.com/v1';
const isRazorpayConfigured = () => Boolean(process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET);

async function rzp(method, path, body) {
  const auth = Buffer.from(`${process.env.RAZORPAY_KEY_ID}:${process.env.RAZORPAY_KEY_SECRET}`).toString('base64');
  let res, data;
  try {
    res = await fetch(API + path, {
      method,
      headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(20000),
    });
    data = await res.json().catch(() => ({}));
  } catch (e) {
    console.error('[razorpay] request failed:', e.message);
    throw new ApiError(502, 'Payment service is not reachable. Please try again.');
  }
  if (!res.ok) {
    const msg = data?.error?.description || `Razorpay error ${res.status}`;
    console.error('[razorpay]', method, path, msg);
    throw new ApiError(502, msg);
  }
  return data;
}

/** Creates a Razorpay order for our order. amount is in rupees. */
const createRazorpayOrder = (amountRupees, receipt, notes = {}) =>
  rzp('POST', '/orders', { amount: Math.round(amountRupees * 100), currency: 'INR', receipt: String(receipt).slice(0, 40), notes });

const safeEqual = (a, b) => {
  const x = Buffer.from(String(a)); const y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
};

/** Checkout signature: HMAC_SHA256(order_id + "|" + payment_id, key_secret) */
const verifyPaymentSignature = (razorpayOrderId, razorpayPaymentId, signature) =>
  safeEqual(crypto.createHmac('sha256', process.env.RAZORPAY_KEY_SECRET || '').update(`${razorpayOrderId}|${razorpayPaymentId}`).digest('hex'), signature || '');

/** Webhook signature: HMAC_SHA256(raw body, webhook_secret) */
const verifyWebhookSignature = (rawBody, signature) =>
  Boolean(process.env.RAZORPAY_WEBHOOK_SECRET) &&
  safeEqual(crypto.createHmac('sha256', process.env.RAZORPAY_WEBHOOK_SECRET).update(rawBody).digest('hex'), signature || '');

const fetchPayment = (paymentId) => rzp('GET', `/payments/${paymentId}`);
const refundPayment = (paymentId, amountRupees, notes = {}) =>
  rzp('POST', `/payments/${paymentId}/refund`, { amount: Math.round(amountRupees * 100), speed: 'normal', notes });

module.exports = { isRazorpayConfigured, createRazorpayOrder, verifyPaymentSignature, verifyWebhookSignature, fetchPayment, refundPayment };
