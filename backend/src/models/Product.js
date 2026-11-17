const mongoose = require('mongoose');

// A variant = one sellable pack size, e.g. "500 g" or "1 kg" or "6 pcs", each with its own price & stock.
const variantSchema = new mongoose.Schema({
  label: { type: String, required: true },          // "500 g"
  quantity: { type: Number, required: true },       // 500
  unit: { type: String, enum: ['kg', 'g', 'pc', 'dozen', 'bunch', 'l', 'ml', 'pack', 'box'], required: true },
  mrp: { type: Number, required: true, min: 0 },
  price: { type: Number, required: true, min: 0 },  // selling price
  stock: { type: Number, default: 100, min: 0 },
  maxPerOrder: { type: Number, default: 10 },
  isDefault: { type: Boolean, default: false },
});

variantSchema.virtual('discount').get(function () {
  if (!this.mrp || this.mrp <= this.price) return 0;
  return Math.round(((this.mrp - this.price) / this.mrp) * 100);
});
variantSchema.set('toJSON', { virtuals: true });
variantSchema.set('toObject', { virtuals: true });

const productSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    hindiName: String,
    slug: { type: String, required: true, unique: true },
    description: String,
    images: [String],
    emoji: String,
    category: { type: mongoose.Schema.Types.ObjectId, ref: 'Category', required: true },
    subCategory: { type: mongoose.Schema.Types.ObjectId, ref: 'Category' },
    variants: { type: [variantSchema], validate: (v) => v.length > 0 },
    tags: [String],
    origin: String,
    shelfLife: String,
    storageTips: String,
    nutrition: String,
    isOrganic: { type: Boolean, default: false },
    isFeatured: { type: Boolean, default: false },
    isBestSeller: { type: Boolean, default: false },
    isActive: { type: Boolean, default: true },
    rating: { type: Number, default: 4.5 },
    ratingCount: { type: Number, default: 0 },
    soldCount: { type: Number, default: 0 },
  },
  { timestamps: true, toJSON: { virtuals: true }, toObject: { virtuals: true } }
);

productSchema.index({ name: 'text', hindiName: 'text', tags: 'text' });

productSchema.virtual('defaultVariant').get(function () {
  if (!this.variants || !this.variants.length) return null;
  return this.variants.find((v) => v.isDefault) || this.variants[0];
});

productSchema.virtual('inStock').get(function () {
  return (this.variants || []).some((v) => v.stock > 0);
});

module.exports = mongoose.model('Product', productSchema);
