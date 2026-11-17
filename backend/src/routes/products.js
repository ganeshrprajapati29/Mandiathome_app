const router = require('express').Router();
const Product = require('../models/Product');
const { protect, adminOnly } = require('../middleware/auth');
const { asyncHandler, ApiError, slugify } = require('../utils/helpers');

const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// GET /api/products?category=&subCategory=&search=&featured=true&bestSeller=true&organic=true&sort=price_asc|price_desc|discount|popular|new&page=&limit=
router.get('/', asyncHandler(async (req, res) => {
  const { category, subCategory, search, featured, bestSeller, organic, sort, admin } = req.query;
  const page = Math.max(1, parseInt(req.query.page) || 1);
  const limit = Math.min(100, parseInt(req.query.limit) || 20);
  const q = {};
  if (admin !== 'true') q.isActive = true;
  if (category) q.category = category;
  if (subCategory) q.subCategory = subCategory;
  if (featured === 'true') q.isFeatured = true;
  if (bestSeller === 'true') q.isBestSeller = true;
  if (organic === 'true') q.isOrganic = true;
  if (search) {
    const rx = new RegExp(escapeRegex(search.trim()), 'i');
    q.$or = [{ name: rx }, { hindiName: rx }, { tags: rx }];
  }
  const sortMap = {
    price_asc: { 'variants.0.price': 1 },
    price_desc: { 'variants.0.price': -1 },
    popular: { soldCount: -1 },
    rating: { rating: -1 },
    new: { createdAt: -1 },
  };
  const [items, total] = await Promise.all([
    Product.find(q).populate('category', 'name').populate('subCategory', 'name')
      .sort(sortMap[sort] || { isFeatured: -1, soldCount: -1, name: 1 })
      .skip((page - 1) * limit).limit(limit),
    Product.countDocuments(q),
  ]);
  res.json({ success: true, data: items, page, limit, total, hasMore: page * limit < total });
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const p = await Product.findById(req.params.id).populate('category', 'name').populate('subCategory', 'name');
  if (!p) throw new ApiError(404, 'Product not found');
  const sq = { _id: { $ne: p._id }, isActive: true, category: p.category._id };
  if (p.subCategory) sq.subCategory = p.subCategory._id;
  const similar = await Product.find(sq).limit(10);
  res.json({ success: true, data: p, similar });
}));

const normalize = (body) => {
  const b = { ...body };
  if (b.subCategory === '') b.subCategory = null;
  if (Array.isArray(b.variants)) {
    if (!b.variants.some((v) => v.isDefault) && b.variants.length) b.variants[0].isDefault = true;
  }
  if (typeof b.tags === 'string') b.tags = b.tags.split(',').map((t) => t.trim()).filter(Boolean);
  return b;
};

router.post('/', protect, adminOnly, asyncHandler(async (req, res) => {
  const body = normalize(req.body);
  body.slug = `${slugify(body.name)}-${Date.now().toString(36)}`;
  const p = await Product.create(body);
  res.status(201).json({ success: true, data: p });
}));

router.put('/:id', protect, adminOnly, asyncHandler(async (req, res) => {
  const body = normalize(req.body);
  delete body.slug;
  const p = await Product.findById(req.params.id);
  if (!p) throw new ApiError(404, 'Product not found');
  p.set(body);
  await p.save();
  res.json({ success: true, data: p });
}));

// Quick price / stock update for one variant: PATCH /api/products/:id/variants/:variantId { price, mrp, stock }
router.patch('/:id/variants/:variantId', protect, adminOnly, asyncHandler(async (req, res) => {
  const p = await Product.findById(req.params.id);
  if (!p) throw new ApiError(404, 'Product not found');
  const v = p.variants.id(req.params.variantId);
  if (!v) throw new ApiError(404, 'Variant not found');
  ['price', 'mrp', 'stock', 'label', 'maxPerOrder'].forEach((k) => { if (req.body[k] !== undefined) v[k] = req.body[k]; });
  await p.save();
  res.json({ success: true, data: p });
}));

router.delete('/:id', protect, adminOnly, asyncHandler(async (req, res) => {
  await Product.findByIdAndDelete(req.params.id);
  res.json({ success: true, message: 'Product deleted' });
}));

module.exports = router;
