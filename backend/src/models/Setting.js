const mongoose = require('mongoose');

// Single document holding store-wide configuration editable from admin panel.
const settingSchema = new mongoose.Schema(
  {
    key: { type: String, default: 'store', unique: true },
    storeName: { type: String, default: 'Mandi At Home' },
    supportPhone: { type: String, default: '+91 90000 00000' },
    supportEmail: { type: String, default: 'support@mandiathome.com' },
    deliveryFee: { type: Number, default: 30 },
    freeDeliveryAbove: { type: Number, default: 299 },
    handlingFee: { type: Number, default: 0 },
    minOrderAmount: { type: Number, default: 99 },
    codEnabled: { type: Boolean, default: true },
    onlinePaymentEnabled: { type: Boolean, default: false },
    deliverySlots: { type: [String], default: ['7 AM - 10 AM', '10 AM - 1 PM', '4 PM - 7 PM', '7 PM - 9 PM'] },
    serviceablePincodes: { type: [String], default: [] }, // empty = all serviceable
    isStoreOpen: { type: Boolean, default: true },
    catalogVersion: { type: Number, default: 1 },
    settingsVersion: { type: Number, default: 0 },
  },
  { timestamps: true }
);

settingSchema.statics.get = async function () {
  let s = await this.findOne({ key: 'store' });
  if (!s) s = await this.create({ key: 'store' });
  return s;
};

module.exports = mongoose.model('Setting', settingSchema);
