const router = require('express').Router();
const User = require('../models/User');
const Order = require('../models/Order');
const Product = require('../models/Product');
const Banner = require('../models/Banner');
const Coupon = require('../models/Coupon');
const Setting = require('../models/Setting');
const upload = require('../middleware/upload');
const { protect, adminOnly } = require('../middleware/auth');
const { asyncHandler, ApiError } = require('../utils/helpers');

router.use(protect, adminOnly);

router.get('/stats', asyncHandler(async (req, res) => {
  const start = new Date(); start.setHours(0, 0, 0, 0);
  const [users, products, orders, todayOrders, revenueAgg, todayAgg, byStatus, lowStock, recent] = await Promise.all([
    User.countDocuments({ role: 'user' }),
    Product.countDocuments(),
    Order.countDocuments(),
    Order.countDocuments({ createdAt: { $gte: start } }),
    Order.aggregate([{ $match: { status: { $nin: ['cancelled', 'payment_pending'] } } }, { $group: { _id: null, sum: { $sum: '$grandTotal' } } }]),
    Order.aggregate([{ $match: { status: { $nin: ['cancelled', 'payment_pending'] }, createdAt: { $gte: start } } }, { $group: { _id: null, sum: { $sum: '$grandTotal' } } }]),
    Order.aggregate([{ $group: { _id: '$status', count: { $sum: 1 } } }]),
    Product.find({ 'variants.stock': { $lte: 5 } }).select('name emoji variants').limit(20),
    Order.find().sort({ createdAt: -1 }).limit(8).populate('user', 'name phone'),
  ]);
  res.json({
    success: true,
    data: {
      users, products, orders, todayOrders,
      revenue: revenueAgg[0]?.sum || 0,
      todayRevenue: todayAgg[0]?.sum || 0,
      byStatus: Object.fromEntries(byStatus.map((s) => [s._id, s.count])),
      lowStock, recent,
    },
  });
}));

router.post('/upload', upload.single('image'), (req, res) => {
  if (!req.file) throw new ApiError(400, 'No file uploaded');
  res.json({ success: true, url: `/uploads/${req.file.filename}` });
});

// Users
router.get('/users', asyncHandler(async (req, res) => {
  const q = { role: 'user' };
  if (req.query.search) {
    const rx = new RegExp(req.query.search.replace(/[^a-zA-Z0-9 ]/g, ''), 'i');
    q.$or = [{ name: rx }, { phone: rx }, { email: rx }];
  }
  res.json({ success: true, data: await User.find(q).sort({ createdAt: -1 }).limit(200) });
}));
router.put('/users/:id/block', asyncHandler(async (req, res) => {
  const u = await User.findByIdAndUpdate(req.params.id, { isBlocked: !!req.body.isBlocked }, { new: true });
  res.json({ success: true, data: u });
}));

// Generic CRUD helper for banners & coupons
const crud = (path, Model) => {
  router.get(`/${path}`, asyncHandler(async (req, res) => res.json({ success: true, data: await Model.find().sort({ createdAt: -1 }) })));
  router.post(`/${path}`, asyncHandler(async (req, res) => res.status(201).json({ success: true, data: await Model.create(req.body) })));
  router.put(`/${path}/:id`, asyncHandler(async (req, res) => {
    const d = await Model.findByIdAndUpdate(req.params.id, req.body, { new: true, runValidators: true });
    if (!d) throw new ApiError(404, 'Not found');
    res.json({ success: true, data: d });
  }));
  router.delete(`/${path}/:id`, asyncHandler(async (req, res) => {
    await Model.findByIdAndDelete(req.params.id);
    res.json({ success: true });
  }));
};
crud('banners', Banner);
crud('coupons', Coupon);

router.put('/settings', asyncHandler(async (req, res) => {
  const s = await Setting.get();
  const body = { ...req.body };
  delete body.key; delete body._id;
  s.set(body);
  await s.save();
  res.json({ success: true, data: s });
}));

module.exports = router;
