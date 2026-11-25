const router = require('express').Router();
const Order = require('../models/Order');
const Product = require('../models/Product');
const Setting = require('../models/Setting');
const { protect, adminOnly } = require('../middleware/auth');
const { asyncHandler, ApiError } = require('../utils/helpers');
const { buildCartSummary } = require('../utils/pricing');
const { isRazorpayConfigured, createRazorpayOrder, verifyPaymentSignature, fetchPayment } = require('../utils/razorpay');
const { confirmOrder, cancelOrder, refundIfPaid } = require('../utils/orderPayments');

router.use(protect);

const onlineAvailable = (settings) => settings.onlinePaymentEnabled && isRazorpayConfigured();

// POST /api/orders { addressId, paymentMethod, deliverySlot: {date, slot}, note }
router.post('/', asyncHandler(async (req, res) => {
  const settings = await Setting.get();
  if (!settings.isStoreOpen) throw new ApiError(400, 'Store is closed right now. Please try later.');
  const { cart, summary } = await buildCartSummary(req.user._id);
  if (!summary.items.length) throw new ApiError(400, 'Your cart is empty');
  if (summary.itemsTotal < settings.minOrderAmount) throw new ApiError(400, `Minimum order amount is ₹${settings.minOrderAmount}`);

  const address = req.user.addresses.id(req.body.addressId);
  if (!address) throw new ApiError(400, 'Please select a delivery address');
  if (settings.serviceablePincodes.length && !settings.serviceablePincodes.includes(address.pincode)) {
    throw new ApiError(400, `Sorry, we don't deliver to ${address.pincode} yet`);
  }
  const paymentMethod = req.body.paymentMethod === 'ONLINE' ? 'ONLINE' : 'COD';
  if (paymentMethod === 'COD' && !settings.codEnabled) throw new ApiError(400, 'Cash on delivery is not available');
  if (paymentMethod === 'ONLINE' && !onlineAvailable(settings)) throw new ApiError(400, 'Online payment is not available right now. Please choose Cash on Delivery.');

  // A previous online attempt that was never paid holds stock — release it first.
  const unpaid = await Order.find({ user: req.user._id, status: 'payment_pending' });
  for (const o of unpaid) await cancelOrder(o, 'Replaced by a new order');

  // Reserve stock atomically per variant; roll back on failure.
  const reserved = [];
  try {
    for (const it of summary.items) {
      const r = await Product.updateOne(
        { _id: it.product._id, variants: { $elemMatch: { _id: it.variant._id, stock: { $gte: it.qty } } } },
        { $inc: { 'variants.$.stock': -it.qty, soldCount: it.qty } }
      );
      if (!r.modifiedCount) throw new ApiError(400, `${it.product.name} (${it.variant.label}) just went out of stock`);
      reserved.push(it);
    }
  } catch (e) {
    for (const it of reserved) {
      await Product.updateOne({ _id: it.product._id, 'variants._id': it.variant._id }, { $inc: { 'variants.$.stock': it.qty, soldCount: -it.qty } });
    }
    throw e;
  }

  const order = await Order.create({
    user: req.user._id,
    items: summary.items.map((i) => ({
      product: i.product._id, variantId: i.variant._id, name: i.product.name, emoji: i.product.emoji,
      image: i.product.images?.[0], variantLabel: i.variant.label, mrp: i.variant.mrp, price: i.variant.price,
      qty: i.qty, total: i.total,
    })),
    address: address.toObject(),
    deliverySlot: req.body.deliverySlot,
    itemsTotal: summary.itemsTotal,
    mrpTotal: summary.mrpTotal,
    savings: summary.savings,
    couponCode: summary.couponDiscount ? summary.coupon : undefined,
    couponDiscount: summary.couponDiscount,
    deliveryFee: summary.deliveryFee,
    handlingFee: summary.handlingFee,
    grandTotal: summary.grandTotal,
    paymentMethod,
    note: req.body.note,
    status: paymentMethod === 'ONLINE' ? 'payment_pending' : 'placed',
    statusHistory: [paymentMethod === 'ONLINE' ? { status: 'payment_pending', note: 'Waiting for online payment' } : { status: 'placed', note: 'Order placed' }],
  });

  if (paymentMethod === 'COD') {
    await confirmOrder(order);
    return res.status(201).json({ success: true, data: order });
  }

  // ONLINE: create the Razorpay order; the app opens Razorpay Checkout with this payload.
  let rzpOrder;
  try {
    rzpOrder = await createRazorpayOrder(order.grandTotal, order.orderNo, { orderId: String(order._id), orderNo: order.orderNo });
  } catch (e) {
    await cancelOrder(order, 'Could not start online payment');
    throw e;
  }
  order.razorpayOrderId = rzpOrder.id;
  await order.save();
  res.status(201).json({
    success: true,
    data: order,
    payment: {
      provider: 'razorpay',
      key: process.env.RAZORPAY_KEY_ID,
      razorpayOrderId: rzpOrder.id,
      amount: rzpOrder.amount, // paise
      currency: rzpOrder.currency,
      name: settings.storeName || 'Mandi At Home',
      description: `Order #${order.orderNo}`,
      prefill: { contact: req.user.phone ? `+91${req.user.phone}` : '', email: req.user.email || '', name: req.user.name || '' },
    },
  });
}));

// POST /api/orders/:id/verify-payment { razorpay_order_id, razorpay_payment_id, razorpay_signature }
router.post('/:id/verify-payment', asyncHandler(async (req, res) => {
  const order = await Order.findOne({ _id: req.params.id, user: req.user._id });
  if (!order) throw new ApiError(404, 'Order not found');
  if (order.paymentStatus === 'paid') return res.json({ success: true, data: order }); // already confirmed (e.g. by webhook)
  const { razorpay_order_id: rOrder, razorpay_payment_id: rPay, razorpay_signature: sig } = req.body;
  if (!rOrder || !rPay || rOrder !== order.razorpayOrderId || !verifyPaymentSignature(rOrder, rPay, sig)) {
    throw new ApiError(400, 'Payment verification failed. If money was deducted it will be refunded automatically.');
  }
  if (order.status === 'cancelled') {
    // Paid after the order expired (stock already released): record the payment, then refund it.
    if (!['refunded', 'refund_pending'].includes(order.paymentStatus)) {
      order.paymentStatus = 'paid';
      order.razorpayPaymentId = rPay;
      await refundIfPaid(order);
    }
    throw new ApiError(400, 'This order had expired, so your payment is being refunded. Please place the order again.');
  }
  // Double-check with Razorpay that the money was really captured/authorized for the right amount.
  try {
    const p = await fetchPayment(rPay);
    if (p.order_id !== rOrder || p.amount !== Math.round(order.grandTotal * 100) || !['captured', 'authorized'].includes(p.status)) {
      throw new ApiError(400, 'Payment details do not match this order');
    }
  } catch (e) {
    if (e.status === 400) throw e;
    console.warn('[razorpay] could not double-check payment, relying on signature:', e.message);
  }
  await confirmOrder(order, { paymentId: rPay });
  res.json({ success: true, data: order });
}));

// POST /api/orders/:id/payment-failed { reason } -> customer closed / failed checkout
router.post('/:id/payment-failed', asyncHandler(async (req, res) => {
  const order = await Order.findOne({ _id: req.params.id, user: req.user._id });
  if (!order) throw new ApiError(404, 'Order not found');
  if (order.status === 'payment_pending') await cancelOrder(order, `Payment not completed${req.body.reason ? `: ${String(req.body.reason).slice(0, 120)}` : ''}`);
  res.json({ success: true, data: order });
}));

// GET /api/orders  (own orders)   |  GET /api/orders?all=true&status=  (admin)
router.get('/', asyncHandler(async (req, res) => {
  const page = Math.max(1, parseInt(req.query.page) || 1);
  const limit = Math.min(100, parseInt(req.query.limit) || 20);
  const q = {};
  if (req.query.all === 'true' && req.user.role === 'admin') {
    if (req.query.status) q.status = req.query.status;
    if (req.query.search) q.orderNo = new RegExp(req.query.search.replace(/[^a-zA-Z0-9]/g, ''), 'i');
  } else q.user = req.user._id;
  const [items, total] = await Promise.all([
    Order.find(q).populate('user', 'name phone').sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit),
    Order.countDocuments(q),
  ]);
  res.json({ success: true, data: items, page, total, hasMore: page * limit < total });
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const order = await Order.findById(req.params.id).populate('user', 'name phone');
  if (!order) throw new ApiError(404, 'Order not found');
  if (req.user.role !== 'admin' && String(order.user._id) !== String(req.user._id)) throw new ApiError(404, 'Order not found');
  res.json({ success: true, data: order });
}));

// Customer cancel (only before packing)
router.post('/:id/cancel', asyncHandler(async (req, res) => {
  const order = await Order.findOne({ _id: req.params.id, user: req.user._id });
  if (!order) throw new ApiError(404, 'Order not found');
  if (!['placed', 'confirmed'].includes(order.status)) throw new ApiError(400, 'Order can no longer be cancelled');
  await cancelOrder(order, req.body.reason || 'Cancelled by customer');
  res.json({ success: true, data: order });
}));

// Admin: update status
router.put('/:id/status', adminOnly, asyncHandler(async (req, res) => {
  const { status, note, paymentStatus } = req.body;
  const order = await Order.findById(req.params.id);
  if (!order) throw new ApiError(404, 'Order not found');
  if (status && !Order.STATUSES.includes(status)) throw new ApiError(400, 'Invalid status');
  if (order.status === 'cancelled' && status && status !== 'cancelled') throw new ApiError(400, 'Cancelled order cannot be reopened');
  if (status === 'payment_pending' && order.status !== 'payment_pending') throw new ApiError(400, 'Invalid status');
  if (order.status === 'payment_pending' && status && !['payment_pending', 'cancelled'].includes(status)) {
    throw new ApiError(400, 'This order is waiting for online payment. It can only be cancelled.');
  }
  if (paymentStatus) order.paymentStatus = paymentStatus;
  if (status === 'cancelled' && order.status !== 'cancelled') {
    await cancelOrder(order, note || 'Cancelled by store'); // restocks and refunds online payments
  } else {
    if (status && status !== order.status) {
      order.status = status;
      order.statusHistory.push({ status, note });
      if (status === 'delivered' && order.paymentMethod === 'COD') order.paymentStatus = 'paid';
    }
    await order.save();
  }
  res.json({ success: true, data: order });
}));

module.exports = router;
