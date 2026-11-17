const router = require('express').Router();
const Category = require('../models/Category');
const Product = require('../models/Product');
const { protect, adminOnly } = require('../middleware/auth');
const { asyncHandler, ApiError, slugify } = require('../utils/helpers');

// GET /api/categories            -> top-level categories with their subcategories
// GET /api/categories?all=true   -> flat list (admin)
router.get('/', asyncHandler(async (req, res) => {
  if (req.query.all === 'true') {
    const cats = await Category.find().populate('parent', 'name').sort({ sortOrder: 1, name: 1 });
    return res.json({ success: true, data: cats });
  }
  const cats = await Category.find({ parent: null, isActive: true })
    .populate({ path: 'subcategories', match: { isActive: true }, options: { sort: { sortOrder: 1, name: 1 } } })
    .sort({ sortOrder: 1, name: 1 });
  res.json({ success: true, data: cats });
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const cat = await Category.findById(req.params.id)
    .populate({ path: 'subcategories', match: { isActive: true }, options: { sort: { sortOrder: 1 } } });
  if (!cat) throw new ApiError(404, 'Category not found');
  res.json({ success: true, data: cat });
}));

router.post('/', protect, adminOnly, asyncHandler(async (req, res) => {
  const body = { ...req.body, parent: req.body.parent || null };
  body.slug = slugify(body.slug || body.name) + (body.parent ? '-' + Date.now().toString(36) : '');
  const cat = await Category.create(body);
  res.status(201).json({ success: true, data: cat });
}));

router.put('/:id', protect, adminOnly, asyncHandler(async (req, res) => {
  const body = { ...req.body };
  if ('parent' in body) body.parent = body.parent || null;
  delete body.slug;
  const cat = await Category.findByIdAndUpdate(req.params.id, body, { new: true, runValidators: true });
  if (!cat) throw new ApiError(404, 'Category not found');
  res.json({ success: true, data: cat });
}));

router.delete('/:id', protect, adminOnly, asyncHandler(async (req, res) => {
  const id = req.params.id;
  const inUse = await Product.countDocuments({ $or: [{ category: id }, { subCategory: id }] });
  if (inUse) throw new ApiError(400, `Category has ${inUse} products. Move or delete them first.`);
  const subs = await Category.countDocuments({ parent: id });
  if (subs) throw new ApiError(400, `Category has ${subs} sub-categories. Delete them first.`);
  await Category.findByIdAndDelete(id);
  res.json({ success: true, message: 'Category deleted' });
}));

module.exports = router;
