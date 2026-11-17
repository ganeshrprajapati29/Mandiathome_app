const Cart = require('../models/Cart');
const Coupon = require('../models/Coupon');
const Setting = require('../models/Setting');

/**
 * Builds a fully priced cart summary from the DB (never trusts client prices).
 * Removes items whose product/variant no longer exists or is inactive.
 */
async function buildCartSummary(userId) {
  let cart = await Cart.findOne({ user: userId }).populate('items.product');
  if (!cart) cart = await Cart.create({ user: userId, items: [] });
  const settings = await Setting.get();

  const items = [];
  const warnings = [];
  let changed = false;
  let itemsTotal = 0;
  let mrpTotal = 0;

  for (const it of cart.items) {
    const p = it.product;
    const v = p && p.isActive ? p.variants.id(it.variantId) : null;
    if (!v) { changed = true; warnings.push('Some items are no longer available and were removed'); continue; }
    let qty = it.qty;
    if (qty > v.maxPerOrder) { qty = v.maxPerOrder; }
    if (qty > v.stock) { qty = v.stock; warnings.push(`${p.name} (${v.label}): only ${v.stock} left`); }
    if (qty <= 0) { changed = true; continue; }
    if (qty !== it.qty) { it.qty = qty; changed = true; }
    itemsTotal += v.price * qty;
    mrpTotal += v.mrp * qty;
    items.push({
      product: { _id: p._id, name: p.name, emoji: p.emoji, images: p.images },
      variant: { _id: v._id, label: v.label, price: v.price, mrp: v.mrp, stock: v.stock, maxPerOrder: v.maxPerOrder },
      qty,
      total: v.price * qty,
    });
  }
  if (changed) {
    cart.items = cart.items.filter((it) => items.some((x) => String(x.variant._id) === String(it.variantId) && String(x.product._id) === String(it.product?._id)));
    await cart.save();
  }

  let couponDiscount = 0;
  let couponMessage = null;
  if (cart.coupon) {
    const c = await Coupon.findOne({ code: cart.coupon });
    const r = c ? c.computeDiscount(itemsTotal) : { ok: false, message: 'Invalid coupon' };
    if (r.ok) couponDiscount = r.discount; else couponMessage = r.message;
  }

  const deliveryFee = items.length === 0 || itemsTotal >= settings.freeDeliveryAbove ? 0 : settings.deliveryFee;
  const handlingFee = items.length ? settings.handlingFee : 0;
  const grandTotal = Math.max(0, itemsTotal - couponDiscount + deliveryFee + handlingFee);

  return {
    cart,
    summary: {
      items,
      count: items.reduce((s, i) => s + i.qty, 0),
      itemsTotal,
      mrpTotal,
      savings: mrpTotal - itemsTotal + couponDiscount,
      coupon: cart.coupon || null,
      couponDiscount,
      couponMessage,
      deliveryFee,
      handlingFee,
      freeDeliveryAbove: settings.freeDeliveryAbove,
      amountForFreeDelivery: Math.max(0, settings.freeDeliveryAbove - itemsTotal),
      minOrderAmount: settings.minOrderAmount,
      grandTotal,
      warnings: [...new Set(warnings)],
    },
  };
}

module.exports = { buildCartSummary };
