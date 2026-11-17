const mongoose = require('mongoose');

const couponSchema = new mongoose.Schema(
  {
    code: { type: String, required: true, unique: true, uppercase: true, trim: true },
    description: String,
    type: { type: String, enum: ['percent', 'flat'], default: 'flat' },
    value: { type: Number, required: true },
    minOrder: { type: Number, default: 0 },
    maxDiscount: { type: Number, default: 0 }, // 0 = no cap
    expiresAt: Date,
    usageLimit: { type: Number, default: 0 },   // 0 = unlimited
    usedCount: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true }
);

couponSchema.methods.computeDiscount = function (amount) {
  if (!this.isActive) return { ok: false, message: 'Coupon is not active' };
  if (this.expiresAt && this.expiresAt < new Date()) return { ok: false, message: 'Coupon has expired' };
  if (this.usageLimit && this.usedCount >= this.usageLimit) return { ok: false, message: 'Coupon usage limit reached' };
  if (amount < this.minOrder) return { ok: false, message: `Add items worth ₹${this.minOrder - amount} more to use this coupon` };
  let d = this.type === 'percent' ? (amount * this.value) / 100 : this.value;
  if (this.maxDiscount && d > this.maxDiscount) d = this.maxDiscount;
  return { ok: true, discount: Math.min(Math.round(d), amount) };
};

module.exports = mongoose.model('Coupon', couponSchema);
