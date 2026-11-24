const router = require('express').Router();
const rateLimit = require('express-rate-limit');
const User = require('../models/User');
const Cart = require('../models/Cart');
const Order = require('../models/Order');
const { protect, signToken } = require('../middleware/auth');
const { asyncHandler, ApiError } = require('../utils/helpers');

const otpLimiter = rateLimit({ windowMs: 10 * 60 * 1000, max: 10, message: { success: false, message: 'Too many OTP requests, try later' } });

const crypto = require('crypto');
const { sendOtpSms, isSmsConfigured } = require('../utils/sms');

const normalizePhone = (p = '') => p.replace(/\D/g, '').slice(-10);
const OTP_LENGTH = Math.min(8, Math.max(4, parseInt(process.env.OTP_LENGTH, 10) || 6));
const OTP_TTL_MIN = parseInt(process.env.OTP_TTL_MINUTES, 10) || 10;
const RESEND_GAP_SEC = 30;

// App Store / Play Store review account: fixed number + fixed OTP, no SMS sent.
// Override with REVIEW_PHONE / REVIEW_OTP in .env; set REVIEW_PHONE=off to disable.
const REVIEW_PHONE = normalizePhone(process.env.REVIEW_PHONE || '9999999999');
const REVIEW_OTP = String(process.env.REVIEW_OTP || '123456');
const isReviewPhone = (phone) => process.env.REVIEW_PHONE !== 'off' && phone === REVIEW_PHONE;

// POST /api/auth/send-otp { phone }
router.post('/send-otp', otpLimiter, asyncHandler(async (req, res) => {
  const phone = normalizePhone(req.body.phone);
  if (!/^[6-9]\d{9}$/.test(phone)) throw new ApiError(400, 'Enter a valid 10-digit mobile number');
  let user = await User.findOne({ phone });
  if (user?.isBlocked) throw new ApiError(403, 'Your account has been blocked');
  if (isReviewPhone(phone)) {
    if (!user) user = new User({ phone });
    user.otp = { code: REVIEW_OTP, expiresAt: new Date(Date.now() + OTP_TTL_MIN * 60 * 1000), attempts: 0, sentAt: new Date() };
    await user.save();
    return res.json({ success: true, message: 'OTP sent to your mobile number', otpLength: REVIEW_OTP.length, expiresIn: OTP_TTL_MIN * 60, resendIn: RESEND_GAP_SEC });
  }
  if (user?.otp?.sentAt && Date.now() - user.otp.sentAt.getTime() < RESEND_GAP_SEC * 1000) {
    const wait = Math.ceil((RESEND_GAP_SEC * 1000 - (Date.now() - user.otp.sentAt.getTime())) / 1000);
    throw new ApiError(429, `Please wait ${wait} seconds before requesting a new OTP`);
  }
  const code = String(crypto.randomInt(10 ** (OTP_LENGTH - 1), 10 ** OTP_LENGTH)); // fresh random OTP every time
  if (!user) user = new User({ phone });
  user.otp = { code, expiresAt: new Date(Date.now() + OTP_TTL_MIN * 60 * 1000), attempts: 0, sentAt: new Date() };
  await user.save();

  // Real SMS when Fast2SMS is configured. OTP_DEV_MODE=true additionally returns the OTP (testing only).
  const devMode = process.env.OTP_DEV_MODE === 'true' || !isSmsConfigured();
  try {
    await sendOtpSms(phone, code);
  } catch (e) {
    user.otp = undefined; // don't leave a usable OTP that was never delivered
    await user.save();
    throw e;
  }
  res.json({
    success: true,
    message: devMode ? 'OTP generated (test mode)' : 'OTP sent to your mobile number',
    otpLength: OTP_LENGTH,
    expiresIn: OTP_TTL_MIN * 60,
    resendIn: RESEND_GAP_SEC,
    ...(devMode ? { devOtp: code } : {}),
  });
}));

// POST /api/auth/verify-otp { phone, otp }
router.post('/verify-otp', asyncHandler(async (req, res) => {
  const phone = normalizePhone(req.body.phone);
  const user = await User.findOne({ phone });
  if (!user || !user.otp?.code) throw new ApiError(400, 'Please request OTP first');
  if (user.otp.expiresAt < new Date()) throw new ApiError(400, 'OTP expired, please resend');
  if ((user.otp.attempts || 0) >= 5) throw new ApiError(429, 'Too many wrong attempts, please resend OTP');
  if (user.otp.code !== String(req.body.otp)) {
    user.otp.attempts = (user.otp.attempts || 0) + 1;
    await user.save();
    throw new ApiError(400, 'Invalid OTP, please try again');
  }
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

// DELETE /api/auth/me -> permanently deletes the logged-in customer's account (Google Play account deletion).
// Removed: profile (name, phone, email), saved addresses, wishlist, cart, OTP data.
// Kept: past order records needed for tax/accounting, with name, phone and street address removed.
router.delete('/me', protect, asyncHandler(async (req, res) => {
  const user = req.user;
  if (user.role === 'admin') throw new ApiError(400, 'Admin accounts cannot be deleted from here');
  await Cart.deleteOne({ user: user._id });
  await Order.updateMany(
    { user: user._id },
    {
      $set: { 'address.name': 'Deleted user', 'address.phone': '', 'address.line1': '', 'address.line2': '', 'address.landmark': '', 'address.lat': null, 'address.lng': null, note: '' },
    }
  );
  await User.deleteOne({ _id: user._id });
  console.log(`[account] deleted user ${user._id}`);
  res.json({ success: true, message: 'Your account and personal data have been deleted.' });
}));

module.exports = router;
