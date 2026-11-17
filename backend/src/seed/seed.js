/* eslint-disable no-console */
// Seeds categories, sub-categories, products (with kg/g/pc variants), banners, coupons, settings & admin.
// Usage: npm run seed          (only seeds if DB is empty)
//        npm run seed -- --fresh (wipes catalog collections first)
require('dotenv').config();
const mongoose = require('mongoose');
const Category = require('../models/Category');
const Product = require('../models/Product');
const Banner = require('../models/Banner');
const Coupon = require('../models/Coupon');
const Setting = require('../models/Setting');
const User = require('../models/User');
const { slugify } = require('../utils/helpers');

const fresh = process.argv.includes('--fresh');

// ---- variant builders ----
const r = (n) => Math.max(1, Math.round(n));
// weight-based: price per kg, sizes in kg
const byWeight = (perKg, sizes = [0.25, 0.5, 1], markup = 1.25) => sizes.map((kg, i) => {
  const label = kg < 1 ? `${kg * 1000} g` : `${kg} kg`;
  const price = r(perKg * kg * (kg >= 2 ? 0.95 : 1));
  return { label, quantity: kg < 1 ? kg * 1000 : kg, unit: kg < 1 ? 'g' : 'kg', price, mrp: r(price * markup), stock: 150, isDefault: i === Math.min(1, sizes.length - 1) };
});
// piece-based: price per piece, counts
const byPiece = (perPc, counts = [1, 3, 6], unit = 'pc', markup = 1.2) => counts.map((c, i) => ({
  label: unit === 'pc' ? `${c} pc${c > 1 ? 's' : ''}` : `${c} ${unit}`, quantity: c, unit,
  price: r(perPc * c * (c >= 6 ? 0.92 : 1)), mrp: r(perPc * c * markup), stock: 150, isDefault: i === 0,
}));
const single = (label, quantity, unit, price, mrp) => [{ label, quantity, unit, price, mrp, stock: 100, isDefault: true }];

const catalog = [
  {
    name: 'Fresh Vegetables', emoji: '🥦', color: '#E8F5E9',
    subs: [
      { name: 'Daily Veggies', emoji: '🧅', color: '#FFF3E0', products: [
        ['Onion', 'प्याज', '🧅', byWeight(40, [0.5, 1, 2, 5]), { best: 1, tags: 'pyaz,kanda' }],
        ['Potato', 'आलू', '🥔', byWeight(35, [0.5, 1, 2, 5]), { best: 1, tags: 'aloo,batata' }],
        ['Tomato', 'टमाटर', '🍅', byWeight(48, [0.5, 1, 2]), { best: 1, feat: 1, tags: 'tamatar' }],
        ['Green Chilli', 'हरी मिर्च', '🌶️', byWeight(80, [0.1, 0.25, 0.5]), { tags: 'mirchi' }],
        ['Lemon', 'नींबू', '🍋', byPiece(5, [4, 8, 12]), { tags: 'nimbu' }],
        ['Cucumber', 'खीरा', '🥒', byWeight(50, [0.5, 1]), {}],
      ] },
      { name: 'Leafy & Herbs', emoji: '🥬', color: '#E8F5E9', products: [
        ['Spinach', 'पालक', '🥬', byPiece(25, [1, 2], 'bunch'), { feat: 1, tags: 'palak' }],
        ['Coriander Leaves', 'हरा धनिया', '🌿', byWeight(120, [0.1, 0.25]), { best: 1, tags: 'dhaniya' }],
        ['Methi (Fenugreek)', 'मेथी', '🌱', byPiece(20, [1, 2], 'bunch'), { tags: 'methi' }],
        ['Mint Leaves', 'पुदीना', '🌿', byPiece(15, [1, 2], 'bunch'), { tags: 'pudina' }],
        ['Curry Leaves', 'करी पत्ता', '🍃', byPiece(10, [1, 2], 'bunch'), {}],
      ] },
      { name: 'Gourds & Beans', emoji: '🫛', color: '#F1F8E9', products: [
        ['Lady Finger', 'भिंडी', '🫛', byWeight(60, [0.25, 0.5, 1]), { feat: 1, tags: 'bhindi,okra' }],
        ['Bottle Gourd', 'लौकी', '🥒', byPiece(35, [1, 2]), { tags: 'lauki,dudhi' }],
        ['Bitter Gourd', 'करेला', '🥒', byWeight(70, [0.25, 0.5, 1]), { tags: 'karela' }],
        ['French Beans', 'फ्रेंच बीन्स', '🫛', byWeight(90, [0.25, 0.5, 1]), {}],
        ['Cauliflower', 'फूलगोभी', '🥦', byPiece(40, [1, 2]), { best: 1, tags: 'gobhi' }],
        ['Cabbage', 'पत्ता गोभी', '🥬', byPiece(30, [1, 2]), { tags: 'patta gobhi' }],
        ['Brinjal', 'बैंगन', '🍆', byWeight(50, [0.5, 1]), { tags: 'baingan' }],
      ] },
      { name: 'Roots & Tubers', emoji: '🥕', color: '#FFF8E1', products: [
        ['Carrot', 'गाजर', '🥕', byWeight(60, [0.5, 1]), { feat: 1, tags: 'gajar' }],
        ['Beetroot', 'चुकंदर', '🫜', byWeight(55, [0.5, 1]), { tags: 'chukandar' }],
        ['Ginger', 'अदरक', '🫚', byWeight(160, [0.1, 0.25, 0.5]), { best: 1, tags: 'adrak' }],
        ['Garlic', 'लहसुन', '🧄', byWeight(220, [0.1, 0.25, 0.5]), { best: 1, tags: 'lahsun' }],
        ['Sweet Potato', 'शकरकंद', '🍠', byWeight(60, [0.5, 1]), { tags: 'shakarkand' }],
        ['Radish', 'मूली', '🥕', byWeight(40, [0.5, 1]), { tags: 'mooli' }],
      ] },
      { name: 'Exotic Vegetables', emoji: '🫑', color: '#FCE4EC', products: [
        ['Broccoli', 'ब्रोकली', '🥦', byWeight(240, [0.25, 0.5]), { feat: 1 }],
        ['Red Bell Pepper', 'लाल शिमला मिर्च', '🫑', byWeight(260, [0.25, 0.5]), {}],
        ['Capsicum Green', 'शिमला मिर्च', '🫑', byWeight(80, [0.25, 0.5, 1]), { best: 1 }],
        ['Button Mushroom', 'मशरूम', '🍄', single('200 g pack', 200, 'g', 55, 70), {}],
        ['Sweet Corn', 'स्वीट कॉर्न', '🌽', byPiece(30, [1, 2, 4]), {}],
        ['Zucchini', 'ज़ुकिनी', '🥒', byWeight(180, [0.25, 0.5]), {}],
      ] },
    ],
  },
  {
    name: 'Fresh Fruits', emoji: '🍎', color: '#FFEBEE',
    subs: [
      { name: 'Daily Fruits', emoji: '🍌', color: '#FFFDE7', products: [
        ['Banana Robusta', 'केला', '🍌', byPiece(60, [6, 12], 'pc'), { best: 1, feat: 1, tags: 'kela' }],
        ['Apple Shimla', 'सेब', '🍎', byWeight(180, [0.5, 1, 2]), { best: 1, feat: 1, tags: 'seb' }],
        ['Orange Nagpur', 'संतरा', '🍊', byWeight(110, [0.5, 1, 2]), { tags: 'santra' }],
        ['Pomegranate', 'अनार', '🍎', byWeight(200, [0.5, 1]), { feat: 1, tags: 'anar' }],
        ['Papaya', 'पपीता', '🥭', byPiece(60, [1, 2]), {}],
        ['Guava', 'अमरूद', '🍐', byWeight(90, [0.5, 1]), { tags: 'amrood' }],
      ] },
      { name: 'Seasonal Fruits', emoji: '🥭', color: '#FFF3E0', products: [
        ['Mango Alphonso', 'आम', '🥭', byPiece(80, [1, 6, 12], 'pc'), { feat: 1, best: 1, tags: 'aam,hapus' }],
        ['Watermelon', 'तरबूज', '🍉', byPiece(70, [1]), { tags: 'tarbooj' }],
        ['Green Grapes', 'अंगूर', '🍇', byWeight(120, [0.5, 1]), { tags: 'angoor' }],
        ['Muskmelon', 'खरबूजा', '🍈', byPiece(60, [1]), { tags: 'kharbuja' }],
        ['Pineapple', 'अनानास', '🍍', byPiece(90, [1]), {}],
      ] },
      { name: 'Exotic Fruits', emoji: '🥝', color: '#E0F2F1', products: [
        ['Kiwi', 'कीवी', '🥝', byPiece(30, [3, 6]), { feat: 1 }],
        ['Dragon Fruit', 'ड्रैगन फ्रूट', '🐉', byPiece(90, [1, 2]), {}],
        ['Avocado', 'एवोकाडो', '🥑', byPiece(150, [1, 2]), {}],
        ['Blueberry', 'ब्लूबेरी', '🫐', single('125 g box', 125, 'g', 249, 299), {}],
        ['Strawberry', 'स्ट्रॉबेरी', '🍓', single('200 g box', 200, 'g', 99, 129), { feat: 1 }],
      ] },
    ],
  },
  {
    name: 'Organic Store', emoji: '🌿', color: '#F1F8E9',
    subs: [
      { name: 'Organic Vegetables', emoji: '🥗', color: '#E8F5E9', products: [
        ['Organic Tomato', 'जैविक टमाटर', '🍅', byWeight(80, [0.5, 1]), { organic: 1 }],
        ['Organic Spinach', 'जैविक पालक', '🥬', byPiece(40, [1, 2], 'bunch'), { organic: 1 }],
        ['Organic Carrot', 'जैविक गाजर', '🥕', byWeight(95, [0.5, 1]), { organic: 1 }],
      ] },
      { name: 'Organic Fruits', emoji: '🍏', color: '#F9FBE7', products: [
        ['Organic Banana', 'जैविक केला', '🍌', byPiece(9, [6, 12], 'pc'), { organic: 1 }],
        ['Organic Apple', 'जैविक सेब', '🍏', byWeight(260, [0.5, 1]), { organic: 1 }],
      ] },
    ],
  },
  {
    name: 'Cuts & Sprouts', emoji: '🥗', color: '#FFF8E1',
    subs: [
      { name: 'Fresh Cuts', emoji: '🔪', color: '#FFF3E0', products: [
        ['Mixed Veg Cut (for Sabzi)', 'कटी मिक्स सब्ज़ी', '🥗', single('250 g pack', 250, 'g', 45, 55), {}],
        ['Fruit Bowl Cut', 'कटे फल', '🍱', single('300 g bowl', 300, 'g', 99, 129), { feat: 1 }],
      ] },
      { name: 'Sprouts', emoji: '🌱', color: '#E8F5E9', products: [
        ['Moong Sprouts', 'अंकुरित मूंग', '🌱', single('200 g pack', 200, 'g', 35, 45), {}],
        ['Mixed Sprouts', 'मिक्स स्प्राउट्स', '🌱', single('200 g pack', 200, 'g', 45, 55), {}],
      ] },
    ],
  },
  {
    name: 'Baskets & Combos', emoji: '🧺', color: '#EDE7F6',
    subs: [
      { name: 'Weekly Baskets', emoji: '🧺', color: '#EDE7F6', products: [
        ['Weekly Veggie Basket', 'साप्ताहिक सब्ज़ी टोकरी', '🧺', single('5 kg basket', 5, 'kg', 299, 380), { feat: 1, desc: 'Onion 1kg, Potato 1kg, Tomato 1kg, plus 2kg of seasonal vegetables.' }],
        ['Fruit Family Pack', 'फल परिवार पैक', '🧺', single('4 kg pack', 4, 'kg', 449, 560), { desc: 'Apple 1kg, Banana 12pc, Orange 1kg and seasonal fruit 1kg.' }],
      ] },
    ],
  },
];

const banners = [
  { title: 'Mandi fresh, at your door', subtitle: 'Farm-fresh sabzi delivered in 30 mins', emoji: '🚚', bgColor: '#2E7D32' },
  { title: 'Flat ₹50 OFF', subtitle: 'On your first order • Use code FRESH50', emoji: '🎉', bgColor: '#E65100' },
  { title: 'Mango Mania 🥭', subtitle: 'Alphonso & Kesar — up to 25% off', emoji: '🥭', bgColor: '#F9A825' },
  { title: 'Go Organic', subtitle: 'Chemical-free fruits & veggies', emoji: '🌿', bgColor: '#558B2F' },
];

const coupons = [
  { code: 'FRESH50', description: 'Flat ₹50 off on orders above ₹199', type: 'flat', value: 50, minOrder: 199 },
  { code: 'MANDI10', description: '10% off up to ₹100 on orders above ₹499', type: 'percent', value: 10, minOrder: 499, maxDiscount: 100 },
  { code: 'FREESHIP', description: '₹30 off — free delivery on any order above ₹149', type: 'flat', value: 30, minOrder: 149 },
];

(async () => {
  await mongoose.connect(process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/mandiathome');
  if (fresh) {
    await Promise.all([Category.deleteMany({}), Product.deleteMany({}), Banner.deleteMany({}), Coupon.deleteMany({})]);
    console.log('🧹 Catalog wiped');
  }
  if (await Product.countDocuments()) {
    console.log('ℹ️  Products already exist, skipping catalog seed (use --fresh to reseed).');
  } else {
    let order = 0;
    for (const c of catalog) {
      const cat = await Category.create({ name: c.name, slug: slugify(c.name), emoji: c.emoji, color: c.color, sortOrder: order++ });
      let subOrder = 0;
      for (const s of c.subs) {
        const sub = await Category.create({ name: s.name, slug: slugify(`${c.name}-${s.name}`), emoji: s.emoji, color: s.color, parent: cat._id, sortOrder: subOrder++ });
        for (const [name, hindiName, emoji, variants, o] of s.products) {
          await Product.create({
            name, hindiName, emoji, variants,
            slug: slugify(name),
            category: cat._id, subCategory: sub._id,
            description: o.desc || `Fresh ${name.toLowerCase()} sourced directly from the mandi every morning. Hand-picked, cleaned and packed with care.`,
            tags: o.tags ? o.tags.split(',') : [],
            isFeatured: !!o.feat, isBestSeller: !!o.best, isOrganic: !!o.organic || c.name === 'Organic Store',
            origin: 'Local Mandi', shelfLife: c.name === 'Fresh Fruits' ? '4-6 days' : '2-4 days',
            storageTips: 'Store in a cool, dry place or refrigerate. Wash before use.',
            rating: Math.round((4.2 + Math.random() * 0.7) * 10) / 10,
            ratingCount: Math.floor(50 + Math.random() * 900),
            soldCount: Math.floor(Math.random() * 500),
          });
        }
      }
    }
    await Banner.insertMany(banners.map((b, i) => ({ ...b, sortOrder: i })));
    await Coupon.insertMany(coupons);
    console.log(`✅ Seeded ${await Category.countDocuments()} categories, ${await Product.countDocuments()} products`);
  }
  await Setting.get();
  const email = (process.env.ADMIN_EMAIL || 'admin@mandiathome.com').toLowerCase();
  if (!(await User.findOne({ email }))) {
    await User.create({ name: 'Admin', email, password: process.env.ADMIN_PASSWORD || 'Admin@123', role: 'admin' });
    console.log(`👤 Admin created: ${email}`);
  }
  await mongoose.disconnect();
})().catch((e) => { console.error(e); process.exit(1); });
