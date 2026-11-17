const router = require('express').Router();
const Product = require('../models/Product');
const { protect } = require('../middleware/auth');
const { asyncHandler, ApiError } = require('../utils/helpers');

router.use(protect);

// ---------- Addresses ----------
router.get('/addresses', (req, res) => res.json({ success: true, data: req.user.addresses }));

router.post('/addresses', asyncHandler(async (req, res) => {
  const u = req.user;
  const makeDefault = req.body.isDefault || u.addresses.length === 0;
  if (makeDefault) u.addresses.forEach((a) => { a.isDefault = false; });
  u.addresses.push({ ...req.body, isDefault: makeDefault });
  await u.save();
  res.status(201).json({ success: true, data: u.addresses });
}));

router.put('/addresses/:id', asyncHandler(async (req, res) => {
  const u = req.user;
  const a = u.addresses.id(req.params.id);
  if (!a) throw new ApiError(404, 'Address not found');
  if (req.body.isDefault) u.addresses.forEach((x) => { x.isDefault = false; });
  a.set(req.body);
  await u.save();
  res.json({ success: true, data: u.addresses });
}));

router.delete('/addresses/:id', asyncHandler(async (req, res) => {
  const u = req.user;
  const a = u.addresses.id(req.params.id);
  if (!a) throw new ApiError(404, 'Address not found');
  const wasDefault = a.isDefault;
  a.deleteOne();
  if (wasDefault && u.addresses.length) u.addresses[0].isDefault = true;
  await u.save();
  res.json({ success: true, data: u.addresses });
}));

// ---------- Wishlist ----------
router.get('/wishlist', asyncHandler(async (req, res) => {
  const products = await Product.find({ _id: { $in: req.user.wishlist }, isActive: true });
  res.json({ success: true, data: products });
}));

router.post('/wishlist/:productId', asyncHandler(async (req, res) => {
  const u = req.user;
  const id = req.params.productId;
  const i = u.wishlist.findIndex((x) => String(x) === id);
  if (i > -1) u.wishlist.splice(i, 1); else u.wishlist.push(id);
  await u.save();
  res.json({ success: true, wishlisted: i === -1, data: u.wishlist });
}));

module.exports = router;
