const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const addressSchema = new mongoose.Schema({
  label: { type: String, enum: ['Home', 'Work', 'Other'], default: 'Home' },
  name: { type: String, required: true },
  phone: { type: String, required: true },
  line1: { type: String, required: true },
  line2: String,
  landmark: String,
  city: { type: String, required: true },
  state: String,
  pincode: { type: String, required: true },
  lat: Number,
  lng: Number,
  isDefault: { type: Boolean, default: false },
});

const userSchema = new mongoose.Schema(
  {
    name: { type: String, default: '' },
    phone: { type: String, unique: true, sparse: true },
    email: { type: String, unique: true, sparse: true, lowercase: true },
    password: { type: String, select: false },
    role: { type: String, enum: ['user', 'admin'], default: 'user' },
    avatar: String,
    addresses: [addressSchema],
    wishlist: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Product' }],
    otp: { code: String, expiresAt: Date, attempts: { type: Number, default: 0 } },
    isBlocked: { type: Boolean, default: false },
    fcmToken: String,
  },
  { timestamps: true }
);

userSchema.pre('save', async function (next) {
  if (!this.isModified('password') || !this.password) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

userSchema.methods.matchPassword = function (pw) {
  return bcrypt.compare(pw, this.password || '');
};

userSchema.methods.toJSON = function () {
  const o = this.toObject();
  delete o.password;
  delete o.otp;
  return o;
};

module.exports = mongoose.model('User', userSchema);
