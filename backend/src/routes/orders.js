const router = require('express').Router();
const Order = require('../models/Order');
const Product = require('../models/Product');
const Coupon = require('../models/Coupon');
const Setting = require('../models/Setting');
const { protect, adminOnly } = require('../middleware/auth');
const { asyncHandler, ApiError } = require('../utils/helpers');
const { buildCartSummary } = require('../utils/pricing');

router.use(protect);

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
    statusHistory: [{ status: 'placed', note: 'Order placed' }],
  });

  if (order.couponCode) await Coupon.updateOne({ code: order.couponCode }, { $inc: { usedCount: 1 } });
  cart.items = [];
  cart.coupon = null;
  await cart.save();

  res.status(201).json({ success: true, data: order });
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

const restock = async (order) => {
  for (const it of order.items) {
    await Product.updateOne({ _id: it.product, 'variants._id': it.variantId }, { $inc: { 'variants.$.stock': it.qty, soldCount: -it.qty } });
  }
};

// Customer cancel (only before packing)
router.post('/:id/cancel', asyncHandler(async (req, res) => {
  const order = await Order.findOne({ _id: req.params.id, user: req.user._id });
  if (!order) throw new ApiError(404, 'Order not found');
  if (!['placed', 'confirmed'].includes(order.status)) throw new ApiError(400, 'Order can no longer be cancelled');
  order.status = 'cancelled';
  order.cancelReason = req.body.reason || 'Cancelled by customer';
  order.statusHistory.push({ status: 'cancelled', note: order.cancelReason });
  await order.save();
  await restock(order);
  res.json({ success: true, data: order });
}));

// Admin: update status
router.put('/:id/status', adminOnly, asyncHandler(async (req, res) => {
  const { status, note, paymentStatus } = req.body;
  const order = await Order.findById(req.params.id);
  if (!order) throw new ApiError(404, 'Order not found');
  if (status && !Order.STATUSES.includes(status)) throw new ApiError(400, 'Invalid status');
  if (order.status === 'cancelled' && status && status !== 'cancelled') throw new ApiError(400, 'Cancelled order cannot be reopened');
  if (status && status !== order.status) {
    if (status === 'cancelled') await restock(order);
    order.status = status;
    order.statusHistory.push({ status, note });
    if (status === 'delivered' && order.paymentMethod === 'COD') order.paymentStatus = 'paid';
  }
  if (paymentStatus) order.paymentStatus = paymentStatus;
  await order.save();
  res.json({ success: true, data: order });
}));

module.exports = router;
