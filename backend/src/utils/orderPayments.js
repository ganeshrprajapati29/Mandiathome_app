// Order <-> payment lifecycle shared by the orders API, the Razorpay webhook and the cleanup job.
const Order = require('../models/Order');
const Product = require('../models/Product');
const Cart = require('../models/Cart');
const Coupon = require('../models/Coupon');
const { refundPayment, isRazorpayConfigured } = require('./razorpay');

const PAYMENT_WINDOW_MIN = 30; // unpaid online orders are cancelled after this

async function restock(order) {
  for (const it of order.items) {
    await Product.updateOne({ _id: it.product, 'variants._id': it.variantId }, { $inc: { 'variants.$.stock': it.qty, soldCount: -it.qty } });
  }
}

/** Removes the ordered lines (and coupon) from the user's cart once an order is confirmed. */
async function clearCartFor(order) {
  const cart = await Cart.findOne({ user: order.user });
  if (!cart) return;
  const bought = new Set(order.items.map((i) => `${i.product}|${i.variantId}`));
  cart.items = cart.items.filter((i) => !bought.has(`${i.product}|${i.variantId}`));
  if (order.couponCode && cart.coupon === order.couponCode) cart.coupon = null;
  await cart.save();
}

/** Confirms an order (COD on creation, ONLINE once payment is verified). Idempotent. */
async function confirmOrder(order, { paymentId, note } = {}) {
  if (order.paymentMethod === 'ONLINE') {
    if (order.paymentStatus === 'paid') return order;
    order.paymentStatus = 'paid';
    order.razorpayPaymentId = paymentId || order.razorpayPaymentId;
    order.paidAt = new Date();
  }
  if (order.status === 'payment_pending') {
    order.status = 'placed';
    order.statusHistory.push({ status: 'placed', note: note || 'Payment received — order placed' });
  }
  await order.save();
  if (order.couponCode) await Coupon.updateOne({ code: order.couponCode }, { $inc: { usedCount: 1 } });
  await clearCartFor(order);
  return order;
}

/**
 * Cancels an order, returns stock and refunds an online payment if it was captured.
 * Safe to call twice.
 */
async function cancelOrder(order, reason) {
  if (order.status === 'cancelled') return order;
  order.status = 'cancelled';
  order.cancelReason = reason;
  order.statusHistory.push({ status: 'cancelled', note: reason });
  if (order.paymentMethod === 'ONLINE' && order.paymentStatus === 'pending') order.paymentStatus = 'failed';
  await order.save();
  await restock(order);
  await refundIfPaid(order);
  return order;
}

/** Refunds a captured online payment in full (no stock changes). */
async function refundIfPaid(order) {
  if (!(order.paymentMethod === 'ONLINE' && order.paymentStatus === 'paid' && order.razorpayPaymentId)) return order;
  if (!isRazorpayConfigured()) {
    order.paymentStatus = 'refund_pending';
  } else {
    try {
      const r = await refundPayment(order.razorpayPaymentId, order.grandTotal, { orderNo: order.orderNo });
      order.paymentStatus = 'refunded';
      order.refundId = r.id;
      order.statusHistory.push({ status: order.status, note: `Refund ${r.id} started (₹${order.grandTotal}) — reaches the customer in 5–7 working days` });
    } catch (e) {
      order.paymentStatus = 'refund_pending';
      order.statusHistory.push({ status: order.status, note: `Automatic refund failed: ${e.message}. Refund manually from the Razorpay dashboard.` });
    }
  }
  await order.save();
  return order;
}

/** Cancels online orders whose payment was never completed. */
async function expireUnpaidOrders(filter = {}) {
  const cutoff = new Date(Date.now() - PAYMENT_WINDOW_MIN * 60 * 1000);
  const stale = await Order.find({ status: 'payment_pending', createdAt: { $lt: cutoff }, ...filter });
  for (const o of stale) await cancelOrder(o, 'Payment not completed');
  return stale.length;
}

module.exports = { restock, confirmOrder, cancelOrder, refundIfPaid, expireUnpaidOrders, PAYMENT_WINDOW_MIN };
