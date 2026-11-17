const mongoose = require('mongoose');

const STATUSES = ['placed', 'confirmed', 'packed', 'out_for_delivery', 'delivered', 'cancelled'];

const orderSchema = new mongoose.Schema(
  {
    orderNo: { type: String, unique: true },
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    items: [
      {
        product: { type: mongoose.Schema.Types.ObjectId, ref: 'Product' },
        variantId: mongoose.Schema.Types.ObjectId,
        name: String,
        emoji: String,
        image: String,
        variantLabel: String,
        mrp: Number,
        price: Number,
        qty: Number,
        total: Number,
      },
    ],
    address: {
      label: String, name: String, phone: String, line1: String, line2: String,
      landmark: String, city: String, state: String, pincode: String, lat: Number, lng: Number,
    },
    deliverySlot: { date: String, slot: String },
    itemsTotal: Number,      // sum of selling price
    mrpTotal: Number,
    savings: Number,
    couponCode: String,
    couponDiscount: { type: Number, default: 0 },
    deliveryFee: { type: Number, default: 0 },
    handlingFee: { type: Number, default: 0 },
    grandTotal: Number,
    paymentMethod: { type: String, enum: ['COD', 'ONLINE'], default: 'COD' },
    paymentStatus: { type: String, enum: ['pending', 'paid', 'failed', 'refunded'], default: 'pending' },
    status: { type: String, enum: STATUSES, default: 'placed' },
    statusHistory: [{ status: String, note: String, at: { type: Date, default: Date.now } }],
    note: String,
    cancelReason: String,
  },
  { timestamps: true }
);

orderSchema.pre('save', function (next) {
  if (!this.orderNo) {
    const d = new Date();
    const ymd = `${d.getFullYear().toString().slice(2)}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}`;
    this.orderNo = `MAH${ymd}${Math.floor(100000 + Math.random() * 900000)}`;
  }
  next();
});

orderSchema.statics.STATUSES = STATUSES;
module.exports = mongoose.model('Order', orderSchema);
