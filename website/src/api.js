const API_BASE = (import.meta.env.VITE_API_BASE_URL || '/api').replace(/\/$/, '');

export class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

export async function api(path, { token, body, ...options } = {}) {
  const response = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });

  const result = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new ApiError(result.message || 'Request failed. Please try again.', response.status);
  }
  return result;
}

export function imageUrl(image) {
  if (!image) return '';
  if (/^https?:\/\//i.test(image)) return image;
  const origin = API_BASE.startsWith('http') ? new URL(API_BASE).origin : window.location.origin;
  return `${origin}${image.startsWith('/') ? '' : '/'}${image}`;
}

export function normalizeCart(summary = {}) {
  return {
    ...summary,
    items: (summary.items || []).map((item) => {
      const product = item.product || {};
      const variant = item.variant || {};
      return {
        productId: product._id || '',
        variantId: variant._id || '',
        name: product.name || 'Product',
        emoji: product.emoji || '🥬',
        image: product.images?.[0] || '',
        variantLabel: variant.label || '',
        price: Number(variant.price || 0),
        mrp: Number(variant.mrp || 0),
        qty: Number(item.qty || 0),
        stock: Number(variant.stock || 0),
        maxPerOrder: Number(variant.maxPerOrder || 10),
        total: Number(item.total || 0),
      };
    }),
  };
}

export function guestCartSummary(items, settings = {}) {
  const normalized = items.map(({ product, variant, qty }) => ({
    productId: product._id,
    variantId: variant._id,
    name: product.name,
    emoji: product.emoji || '🥬',
    image: product.images?.[0] || '',
    variantLabel: variant.label,
    price: Number(variant.price || 0),
    mrp: Number(variant.mrp || 0),
    qty,
    stock: Number(variant.stock || 0),
    maxPerOrder: Number(variant.maxPerOrder || 10),
    total: Number(variant.price || 0) * qty,
  }));
  const itemsTotal = normalized.reduce((sum, item) => sum + item.total, 0);
  const mrpTotal = normalized.reduce((sum, item) => sum + item.mrp * item.qty, 0);
  const freeAbove = Number(settings.freeDeliveryAbove || 299);
  const deliveryFee = itemsTotal === 0 || itemsTotal >= freeAbove ? 0 : Number(settings.deliveryFee || 0);
  const handlingFee = itemsTotal ? Number(settings.handlingFee || 0) : 0;

  return {
    items: normalized,
    count: normalized.reduce((sum, item) => sum + item.qty, 0),
    itemsTotal,
    mrpTotal,
    savings: Math.max(0, mrpTotal - itemsTotal),
    couponDiscount: 0,
    deliveryFee,
    handlingFee,
    grandTotal: itemsTotal + deliveryFee + handlingFee,
    freeDeliveryAbove: freeAbove,
    amountForFreeDelivery: Math.max(0, freeAbove - itemsTotal),
    minOrderAmount: Number(settings.minOrderAmount || 0),
  };
}
