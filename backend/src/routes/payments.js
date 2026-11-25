// Razorpay webhook: confirms orders even if the app closed before it could verify the payment.
// Dashboard → Settings → Webhooks → URL: https://<your-domain>/api/payments/razorpay/webhook
// Events: payment.captured, order.paid. Secret = RAZORPAY_WEBHOOK_SECRET in .env.
const router = require('express').Router();
const Order = require('../models/Order');
const { asyncHandler } = require('../utils/helpers');
const { verifyWebhookSignature } = require('../utils/razorpay');
const { confirmOrder, refundIfPaid } = require('../utils/orderPayments');

router.post('/razorpay/webhook', asyncHandler(async (req, res) => {
  if (!verifyWebhookSignature(req.rawBody || Buffer.from(''), req.headers['x-razorpay-signature'])) {
    return res.status(400).json({ success: false, message: 'Invalid signature' });
  }
  const event = req.body?.event;
  const payment = req.body?.payload?.payment?.entity;
  const rOrderId = payment?.order_id || req.body?.payload?.order?.entity?.id;
  if (['payment.captured', 'order.paid'].includes(event) && rOrderId && payment?.id) {
    const order = await Order.findOne({ razorpayOrderId: rOrderId });
    if (order && order.paymentStatus !== 'paid' && payment.amount === Math.round(order.grandTotal * 100)) {
      if (order.status === 'payment_pending') {
        await confirmOrder(order, { paymentId: payment.id, note: 'Payment received (webhook) — order placed' });
      } else if (order.status === 'cancelled' && !['refunded', 'refund_pending'].includes(order.paymentStatus)) {
        order.paymentStatus = 'paid';
        order.razorpayPaymentId = payment.id;
        await refundIfPaid(order); // paid after expiry -> refund
      }
    }
  }
  res.json({ success: true }); // always 200 for valid signatures so Razorpay doesn't retry forever
}));

module.exports = router;
