const router = require('express').Router();
const rateLimit = require('express-rate-limit');
const User = require('../models/User');
const { protect, signToken } = require('../middleware/auth');
const { asyncHandler, ApiError } = require('../utils/helpers');

const otpLimiter = rateLimit({ windowMs: 10 * 60 * 1000, max: 10, message: { success: false, message: 'Too many OTP requests, try later' } });

const normalizePhone = (p = '') => p.replace(/\D/g, '').slice(-10);

// Hook your SMS provider here (MSG91 / Twilio / Fast2SMS etc.)
async function sendSms(phone, otp) {
  console.log(`[OTP] ${phone} -> ${otp}`);
}

// POST /api/auth/send-otp { phone }
router.post('/send-otp', otpLimiter, asyncHandler(async (req, res) => {
  const phone = normalizePhone(req.body.phone);
  if (phone.length !== 10) throw new ApiError(400, 'Enter a valid 10-digit mobile number');
  const devMode = process.env.OTP_DEV_MODE === 'true';
  const code = devMode ? '1234' : String(Math.floor(1000 + Math.random() * 9000));
  let user = await User.findOne({ phone });
  if (!user) user = new User({ phone });
  user.otp = { code, expiresAt: new Date(Date.now() + 5 * 60 * 1000) };
  await user.save();
  await sendSms(phone, code);
  res.json({ success: true, message: 'OTP sent successfully', ...(devMode ? { devOtp: code } : {}) });
}));

// POST /api/auth/verify-otp { phone, otp }
router.post('/verify-otp', asyncHandler(async (req, res) => {
  const phone = normalizePhone(req.body.phone);
  const user = await User.findOne({ phone });
  if (!user || !user.otp?.code) throw new ApiError(400, 'Please request OTP first');
  if (user.otp.expiresAt < new Date()) throw new ApiError(400, 'OTP expired, please resend');
  if (user.otp.code !== String(req.body.otp)) throw new ApiError(400, 'Invalid OTP');
  if (user.isBlocked) throw new ApiError(403, 'Your account has been blocked');
  user.otp = undefined;
  await user.save();
  res.json({ success: true, token: signToken(user), user, isNewUser: !user.name });
}));

// POST /api/auth/admin-login { email, password }
router.post('/admin-login', asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  const user = await User.findOne({ email: (email || '').toLowerCase() }).select('+password');
  if (!user || user.role !== 'admin' || !(await user.matchPassword(password))) throw new ApiError(401, 'Invalid email or password');
  res.json({ success: true, token: signToken(user), user });
}));

router.get('/me', protect, (req, res) => res.json({ success: true, user: req.user }));

router.put('/me', protect, asyncHandler(async (req, res) => {
  const { name, email, fcmToken } = req.body;
  if (name !== undefined) req.user.name = name;
  if (email !== undefined) req.user.email = email || undefined;
  if (fcmToken !== undefined) req.user.fcmToken = fcmToken;
  await req.user.save();
  res.json({ success: true, user: req.user });
}));

module.exports = router;
