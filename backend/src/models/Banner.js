const mongoose = require('mongoose');

const bannerSchema = new mongoose.Schema(
  {
    title: { type: String, required: true },
    subtitle: String,
    image: String,
    emoji: String,
    bgColor: { type: String, default: '#2E7D32' },
    textColor: { type: String, default: '#FFFFFF' },
    category: { type: mongoose.Schema.Types.ObjectId, ref: 'Category' },
    sortOrder: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Banner', bannerSchema);
