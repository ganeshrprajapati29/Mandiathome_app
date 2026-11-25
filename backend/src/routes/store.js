// Public store data: home feed, banners, coupons, settings
const router = require('express').Router();
const Banner = require('../models/Banner');
const Category = require('../models/Category');
const Product = require('../models/Product');
const Coupon = require('../models/Coupon');
const Setting = require('../models/Setting');
const { asyncHandler } = require('../utils/helpers');
const { isRazorpayConfigured } = require('../utils/razorpay');

// Settings as sent to the app (adds whether online payment can actually be used).
const publicSettings = (s) => ({ ...s.toObject(), onlinePaymentAvailable: Boolean(s.onlinePaymentEnabled && isRazorpayConfigured()) });

// GET /api/home -> everything the home screen needs in one call
router.get('/home', asyncHandler(async (req, res) => {
  const [banners, categories, featured, bestSellers, organic, settings] = await Promise.all([
    Banner.find({ isActive: true }).sort({ sortOrder: 1 }),
    Category.find({ parent: null, isActive: true }).sort({ sortOrder: 1 })
      .populate({ path: 'subcategories', match: { isActive: true }, options: { sort: { sortOrder: 1 } } }),
    Product.find({ isActive: true, isFeatured: true }).sort({ soldCount: -1 }).limit(12),
    Product.find({ isActive: true, isBestSeller: true }).sort({ soldCount: -1 }).limit(12),
    Product.find({ isActive: true, isOrganic: true }).limit(12),
    Setting.get(),
  ]);
  // A product rail per top-level category
  const sections = await Promise.all(categories.map(async (c) => ({
    category: { _id: c._id, name: c.name, emoji: c.emoji, color: c.color },
    products: await Product.find({ isActive: true, category: c._id }).sort({ soldCount: -1 }).limit(10),
  })));
  res.json({ success: true, data: { banners, categories, featured, bestSellers, organic, sections: sections.filter((s) => s.products.length), settings: publicSettings(settings) } });
}));

router.get('/banners', asyncHandler(async (req, res) => {
  res.json({ success: true, data: await Banner.find({ isActive: true }).sort({ sortOrder: 1 }) });
}));

router.get('/coupons', asyncHandler(async (req, res) => {
  const now = new Date();
  const data = await Coupon.find({ isActive: true, $or: [{ expiresAt: null }, { expiresAt: { $gt: now } }] }).select('-usedCount -usageLimit');
  res.json({ success: true, data });
}));

router.get('/settings', asyncHandler(async (req, res) => {
  res.json({ success: true, data: publicSettings(await Setting.get()) });
}));

module.exports = router;
