const router = require('express').Router();
const Cart = require('../models/Cart');
const Product = require('../models/Product');
const Coupon = require('../models/Coupon');
const { protect } = require('../middleware/auth');
const { asyncHandler, ApiError } = require('../utils/helpers');
const { buildCartSummary } = require('../utils/pricing');

router.use(protect);

const respond = async (req, res) => {
  const { summary } = await buildCartSummary(req.user._id);
  res.json({ success: true, data: summary });
};

router.get('/', asyncHandler(respond));

// POST /api/cart { productId, variantId, qty }  -> sets qty (0 removes)
router.post('/', asyncHandler(async (req, res) => {
  const { productId, variantId } = req.body;
  const qty = parseInt(req.body.qty, 10);
  if (Number.isNaN(qty) || qty < 0) throw new ApiError(400, 'Invalid quantity');
  const p = await Product.findById(productId);
  const v = p?.variants.id(variantId);
  if (!p || !p.isActive || !v) throw new ApiError(404, 'Product not available');
  if (qty > v.stock) throw new ApiError(400, `Only ${v.stock} left in stock`);
  if (qty > v.maxPerOrder) throw new ApiError(400, `You can buy max ${v.maxPerOrder} of this item`);

  let cart = await Cart.findOne({ user: req.user._id });
  if (!cart) cart = new Cart({ user: req.user._id, items: [] });
  const idx = cart.items.findIndex((i) => String(i.product) === String(productId) && String(i.variantId) === String(variantId));
  if (qty === 0) { if (idx > -1) cart.items.splice(idx, 1); }
  else if (idx > -1) cart.items[idx].qty = qty;
  else cart.items.push({ product: productId, variantId, qty });
  await cart.save();
  await respond(req, res);
}));

router.delete('/', asyncHandler(async (req, res) => {
  await Cart.findOneAndUpdate({ user: req.user._id }, { items: [], coupon: null });
  await respond(req, res);
}));

router.post('/coupon', asyncHandler(async (req, res) => {
  const code = (req.body.code || '').toUpperCase().trim();
  const c = await Coupon.findOne({ code });
  if (!c) throw new ApiError(404, 'Invalid coupon code');
  const { summary } = await buildCartSummary(req.user._id);
  const r = c.computeDiscount(summary.itemsTotal);
  if (!r.ok) throw new ApiError(400, r.message);
  await Cart.findOneAndUpdate({ user: req.user._id }, { coupon: code });
  await respond(req, res);
}));

router.delete('/coupon', asyncHandler(async (req, res) => {
  await Cart.findOneAndUpdate({ user: req.user._id }, { coupon: null });
  await respond(req, res);
}));

module.exports = router;
