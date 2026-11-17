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
const Order = require('../models/Order');
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
// explicit packs: [[label, quantity, unit, price, mrp], ...]
const packs = (rows) => rows.map(([label, quantity, unit, price, mrp], i) => ({ label, quantity, unit, price, mrp, stock: 100, isDefault: i === 0 }));
const single = (label, quantity, unit, price, mrp) => [{ label, quantity, unit, price, mrp, stock: 100, isDefault: true }];

// Catalogue modelled on typical Indian retail (BigBasket / mandi) pack sizes and prices.
// Columns: [name, hindiName, emoji, variants, options]  options.img -> /catalog/<img>.jpg
const IMG = (n) => `/catalog/${n}.jpg`;
const catalog = [
  {
    name: 'Fresh Vegetables', emoji: '🥦', color: '#E8F5E9', image: '/catalog/cat-vegetables.png',
    subs: [
      { name: 'Daily Veggies', emoji: '🧅', color: '#FFF3E0', image: '/catalog/sub-daily-veggies.png', products: [
        ['Onion', 'प्याज़', '🧅', byWeight(42, [0.5, 1, 2, 5]), { img: 'onion', best: 1, feat: 1, tags: 'pyaz,kanda,onion', desc: 'Nashik red onions, medium size, dry outer skin. The base of every Indian kitchen.' }],
        ['Potato', 'आलू', '🥔', byWeight(32, [0.5, 1, 2, 5]), { img: 'potato', best: 1, tags: 'aloo,batata', desc: 'Fresh Agra / Indore potatoes, firm and clean. Great for sabzi, paratha and fries.' }],
        ['Tomato', 'टमाटर', '🍅', byWeight(38, [0.5, 1, 2]), { img: 'tomato', best: 1, feat: 1, tags: 'tamatar', desc: 'Red, ripe desi tomatoes — perfect for gravy, chutney and salad.' }],
        ['Lemon', 'नींबू', '🍋', byPiece(5, [4, 8, 12]), { img: 'lemon', tags: 'nimbu', desc: 'Juicy yellow lemons, rich in Vitamin C.' }],
        ['Cucumber', 'खीरा', '🥒', byWeight(48, [0.5, 1]), { img: 'cucumber', tags: 'kheera,kakdi', desc: 'Crunchy green cucumbers for salad and raita.' }],
        ['Ginger', 'अदरक', '🫚', byWeight(140, [0.1, 0.25, 0.5]), { img: 'ginger', best: 1, tags: 'adrak', desc: 'Fresh aromatic ginger for chai and cooking.' }],
        ['Garlic', 'लहसुन', '🧄', byWeight(260, [0.1, 0.25, 0.5]), { img: 'garlic', best: 1, tags: 'lahsun', desc: 'Big-clove garlic bulbs, strong flavour.' }],
        ['Green Chilli', 'हरी मिर्च', '🌶️', byWeight(80, [0.1, 0.25]), { tags: 'mirchi,hari mirch', desc: 'Spicy green chillies, freshly picked.' }],
      ] },
      { name: 'Leafy & Herbs', emoji: '🥬', color: '#E8F5E9', image: '/catalog/sub-leafy.png', products: [
        ['Cabbage', 'पत्ता गोभी', '🥬', byPiece(35, [1, 2]), { img: 'cabbage', tags: 'patta gobhi,band gobhi', desc: 'Tight green cabbage, approx. 600–900 g per piece.' }],
        ['Kohlrabi', 'गांठ गोभी', '🥬', byWeight(60, [0.5, 1]), { img: 'kohlrabi', tags: 'ganth gobhi,knol khol', desc: 'Tender kohlrabi (ganth gobhi) — great in sabzi and salads.' }],
        ['Spinach', 'पालक', '🥬', byPiece(30, [1, 2], 'bunch'), { tags: 'palak', desc: 'Fresh palak bunch (approx. 250 g).' }],
        ['Coriander Leaves', 'हरा धनिया', '🌿', byWeight(150, [0.1, 0.25]), { tags: 'dhaniya', desc: 'Fragrant green coriander for garnish and chutney.' }],
        ['Methi', 'मेथी', '🌱', byPiece(25, [1, 2], 'bunch'), { tags: 'methi,fenugreek', desc: 'Fresh fenugreek leaves bunch.' }],
        ['Mint Leaves', 'पुदीना', '🌿', byPiece(15, [1, 2], 'bunch'), { tags: 'pudina', desc: 'Fresh pudina for chutney and drinks.' }],
      ] },
      { name: 'Gourds, Beans & Brinjal', emoji: '🍆', color: '#F3E5F5', image: '/catalog/sub-gourds.png', products: [
        ['Cauliflower', 'फूलगोभी', '🥦', byPiece(40, [1, 2]), { img: 'cauliflower', best: 1, tags: 'gobhi,phool gobhi', desc: 'White, compact cauliflower, approx. 500–700 g per piece.' }],
        ['Brinjal Bharta (Round)', 'भरता बैंगन', '🍆', byWeight(50, [0.5, 1]), { img: 'brinjal-round', tags: 'baingan,bharta', desc: 'Large round brinjal, ideal for baingan bharta.' }],
        ['Brinjal Long', 'लम्बा बैंगन', '🍆', byWeight(48, [0.5, 1]), { img: 'brinjal-long', tags: 'baingan', desc: 'Long purple brinjal for sabzi and fry.' }],
        ['Flat Beans (Sem Phali)', 'सेम फली', '🫛', byWeight(90, [0.25, 0.5, 1]), { img: 'flat-beans', tags: 'sem,beans', desc: 'Tender flat beans, rich in fibre.' }],
        ['Lady Finger', 'भिंडी', '🫛', byWeight(64, [0.25, 0.5, 1]), { tags: 'bhindi,okra', desc: 'Tender green bhindi.' }],
        ['Bottle Gourd', 'लौकी', '🥒', byPiece(38, [1, 2]), { tags: 'lauki,dudhi', desc: 'Fresh lauki, approx. 700 g–1 kg per piece.' }],
      ] },
      { name: 'Roots & Tubers', emoji: '🥕', color: '#FFF8E1', image: '/catalog/sub-roots.png', products: [
        ['Carrot', 'गाजर', '🥕', byWeight(56, [0.5, 1]), { img: 'carrot', feat: 1, tags: 'gajar', desc: 'Sweet orange carrots for salad, halwa and sabzi.' }],
        ['Beetroot', 'चुकंदर', '🫜', byWeight(48, [0.5, 1]), { img: 'beetroot', tags: 'chukandar', desc: 'Deep red beetroot, rich in iron.' }],
        ['Sweet Potato', 'शकरकंद', '🍠', byWeight(58, [0.5, 1]), { img: 'sweet-potato', tags: 'shakarkand', desc: 'Naturally sweet shakarkand — roast or boil.' }],
      ] },
      { name: 'Exotic Vegetables', emoji: '🫑', color: '#FCE4EC', image: '/catalog/sub-exotic-veg.png', products: [
        ['Capsicum Green', 'शिमला मिर्च', '🫑', byWeight(76, [0.25, 0.5, 1]), { img: 'capsicum', best: 1, tags: 'shimla mirch', desc: 'Glossy green capsicum.' }],
        ['Red Bell Pepper', 'लाल शिमला मिर्च', '🫑', byWeight(260, [0.25, 0.5]), { img: 'red-bell-pepper', desc: 'Sweet red bell peppers for pizza, pasta and salads.' }],
        ['Yellow Bell Pepper', 'पीली शिमला मिर्च', '🫑', byWeight(260, [0.25, 0.5]), { img: 'yellow-bell-pepper', desc: 'Sweet yellow-orange bell peppers.' }],
        ['Button Mushroom', 'मशरूम', '🍄', single('200 g pack', 200, 'g', 55, 70), { img: 'mushroom', tags: 'mushroom', desc: 'Fresh button mushrooms, 200 g pack.' }],
        ['Sweet Corn', 'स्वीट कॉर्न', '🌽', byPiece(25, [1, 2, 4]), { img: 'sweet-corn', tags: 'bhutta,makka', desc: 'American sweet corn cobs.' }],
        ['Zucchini Green', 'ज़ुकिनी', '🥒', byWeight(150, [0.25, 0.5]), { img: 'zucchini', desc: 'Tender green zucchini.' }],
      ] },
    ],
  },
  {
    name: 'Fresh Fruits', emoji: '🍎', color: '#FFEBEE', image: '/catalog/cat-fruits.png',
    subs: [
      { name: 'Daily Fruits', emoji: '🍌', color: '#FFFDE7', image: '/catalog/sub-daily-fruits.png', products: [
        ['Banana Robusta', 'केला', '🍌', byPiece(6, [6, 12]), { img: 'banana', best: 1, feat: 1, tags: 'kela', desc: 'Ripe robusta bananas — an instant energy snack.' }],
        ['Apple Shimla', 'शिमला सेब', '🍎', byWeight(180, [0.5, 1, 2]), { img: 'apple-shimla', best: 1, feat: 1, tags: 'seb,apple', desc: 'Crisp, juicy Himachal apples.' }],
        ['Apple Red Delicious', 'रेड डिलीशियस सेब', '🍎', byWeight(240, [0.5, 1]), { img: 'apple-red-delicious', tags: 'seb,apple', desc: 'Deep-red, sweet Red Delicious apples.' }],
        ['Green Apple', 'हरा सेब', '🍏', byWeight(300, [0.5, 1]), { img: 'apple-green', tags: 'seb,granny smith', desc: 'Tangy Granny Smith green apples.' }],
        ['Orange', 'संतरा', '🍊', byWeight(100, [0.5, 1, 2]), { img: 'orange', tags: 'santra,narangi', desc: 'Juicy oranges, full of Vitamin C.' }],
        ['Kinnow', 'किन्नू', '🍊', byWeight(80, [1, 2]), { img: 'kinnow', tags: 'kinnow,mandarin', desc: 'Punjab kinnow — sweet and tangy, great for juice.' }],
        ['Pomegranate', 'अनार', '🍎', byWeight(220, [0.5, 1]), { img: 'pomegranate', feat: 1, best: 1, tags: 'anar', desc: 'Bhagwa pomegranates with ruby-red seeds.' }],
        ['Papaya', 'पपीता', '🥭', byPiece(60, [1, 2]), { img: 'papaya', tags: 'papita', desc: 'Ripe papaya, approx. 1 kg per piece.' }],
        ['Guava', 'अमरूद', '🍐', byWeight(90, [0.5, 1]), { img: 'guava', tags: 'amrood', desc: 'Allahabadi guavas, sweet and crunchy.' }],
        ['Pear', 'नाशपाती', '🍐', byWeight(180, [0.5, 1]), { img: 'pear', tags: 'nashpati', desc: 'Juicy green pears.' }],
        ['Coconut', 'नारियल', '🥥', byPiece(45, [1, 2]), { img: 'coconut', tags: 'nariyal', desc: 'Mature brown coconut for cooking and pooja.' }],
      ] },
      { name: 'Seasonal Fruits', emoji: '🥭', color: '#FFF3E0', image: '/catalog/sub-seasonal.png', products: [
        ['Mango', 'आम', '🥭', byWeight(140, [1, 2]), { img: 'mango', feat: 1, tags: 'aam', desc: 'Sweet, ripe mangoes of the season.' }],
        ['Watermelon', 'तरबूज़', '🍉', byPiece(75, [1]), { img: 'watermelon', tags: 'tarbooj', desc: 'Kiran watermelon, approx. 2–3 kg per piece.' }],
        ['Green Grapes', 'हरे अंगूर', '🍇', byWeight(120, [0.5, 1]), { img: 'grapes-green', tags: 'angoor', desc: 'Seedless green grapes from Nashik.' }],
        ['Black Grapes', 'काले अंगूर', '🍇', byWeight(150, [0.5, 1]), { img: 'grapes-black', tags: 'angoor', desc: 'Sweet seedless black grapes.' }],
        ['Muskmelon', 'खरबूजा', '🍈', byPiece(60, [1]), { img: 'muskmelon', tags: 'kharbuja', desc: 'Fragrant muskmelon, approx. 1 kg.' }],
        ['Pineapple', 'अनानास', '🍍', byPiece(80, [1]), { img: 'pineapple', tags: 'ananas', desc: 'Sweet & tangy pineapple, approx. 1 kg.' }],
        ['Lychee', 'लीची', '🍒', byWeight(250, [0.5, 1]), { img: 'lychee', tags: 'litchi', desc: 'Juicy Muzaffarpur lychees.' }],
        ['Plum', 'आलूबुखारा', '🍑', byWeight(240, [0.25, 0.5]), { img: 'plum', tags: 'aloo bukhara', desc: 'Sweet-sour plums.' }],
      ] },
      { name: 'Exotic Fruits', emoji: '🥝', color: '#E0F2F1', image: '/catalog/sub-exotic-fruits.png', products: [
        ['Kiwi', 'कीवी', '🥝', byPiece(30, [3, 6]), { img: 'kiwi', feat: 1, desc: 'Imported green kiwis.' }],
        ['Dragon Fruit', 'ड्रैगन फ्रूट', '🐉', byPiece(110, [1, 2]), { img: 'dragon-fruit', desc: 'Pink dragon fruit, approx. 350 g each.' }],
        ['Avocado', 'एवोकाडो', '🥑', byPiece(140, [1, 2]), { img: 'avocado', desc: 'Creamy imported avocados.' }],
        ['Blueberry', 'ब्लूबेरी', '🫐', single('125 g box', 125, 'g', 299, 349), { img: 'blueberry', desc: 'Fresh blueberries, 125 g box.' }],
        ['Strawberry', 'स्ट्रॉबेरी', '🍓', single('200 g box', 200, 'g', 99, 129), { img: 'strawberry', feat: 1, desc: 'Mahabaleshwar strawberries, 200 g box.' }],
      ] },
    ],
  },
  {
    name: 'Grocery & Staples', emoji: '🛒', color: '#FFF8E1', image: '/catalog/cat-grocery.png',
    subs: [
      { name: 'Atta & Flours', emoji: '🌾', color: '#FFF8E1', image: '/catalog/sub-atta.png', products: [
        ['Whole Wheat Atta', 'गेहूं आटा', '🌾', packs([['5 kg', 5, 'kg', 265, 310], ['10 kg', 10, 'kg', 510, 600]]), { img: 'g-atta', best: 1, feat: 1, tags: 'atta,aata,gehu,wheat flour', desc: 'Stone-ground whole wheat atta for soft rotis.' }],
        ['Besan (Gram Flour)', 'बेसन', '🌾', packs([['500 g', 500, 'g', 55, 65], ['1 kg', 1, 'kg', 105, 125]]), { tags: 'besan,gram flour', desc: 'Fine besan for pakoda, kadhi and sweets.' }],
        ['Maida', 'मैदा', '🌾', packs([['500 g', 500, 'g', 25, 30], ['1 kg', 1, 'kg', 45, 55]]), { img: 'g-maida', tags: 'maida,refined flour', desc: 'Refined wheat flour for baking and naan.' }],
        ['Sooji (Rava)', 'सूजी', '🌾', packs([['500 g', 500, 'g', 30, 36], ['1 kg', 1, 'kg', 58, 68]]), { tags: 'suji,rava,semolina', desc: 'Fine sooji for upma, halwa and idli.' }],
      ] },
      { name: 'Rice & Dal', emoji: '🍚', color: '#FBE9E7', image: '/catalog/sub-rice-dal.png', products: [
        ['Basmati Rice', 'बासमती चावल', '🍚', packs([['1 kg', 1, 'kg', 140, 175], ['5 kg', 5, 'kg', 650, 820]]), { img: 'g-basmati', best: 1, tags: 'chawal,basmati,rice', desc: 'Long-grain aged basmati rice.' }],
        ['Sona Masoori Rice', 'सोना मसूरी चावल', '🍚', packs([['5 kg', 5, 'kg', 320, 380]]), { img: 'g-sona-masoori', tags: 'chawal,rice', desc: 'Light, aromatic everyday rice.' }],
        ['Toor Dal', 'तुअर दाल', '🫘', packs([['500 g', 500, 'g', 85, 99], ['1 kg', 1, 'kg', 165, 195]]), { img: 'g-toor-dal', best: 1, tags: 'arhar,toor,dal', desc: 'Unpolished toor / arhar dal.' }],
        ['Moong Dal', 'मूंग दाल', '🫘', packs([['500 g', 500, 'g', 70, 82], ['1 kg', 1, 'kg', 135, 160]]), { img: 'g-moong-dal', tags: 'moong,dal', desc: 'Yellow moong dal, easy to digest.' }],
        ['Chana Dal', 'चना दाल', '🫘', packs([['500 g', 500, 'g', 50, 60], ['1 kg', 1, 'kg', 95, 115]]), { img: 'g-chana-dal', tags: 'chana,dal', desc: 'Clean, uniform chana dal.' }],
        ['Masoor Dal', 'मसूर दाल', '🫘', packs([['500 g', 500, 'g', 58, 68], ['1 kg', 1, 'kg', 110, 130]]), { img: 'g-masoor-dal', tags: 'masoor,dal', desc: 'Red masoor dal, cooks fast.' }],
        ['Rajma', 'राजमा', '🫘', packs([['500 g', 500, 'g', 85, 99]]), { img: 'g-rajma', tags: 'rajma,kidney beans', desc: 'Jammu rajma for rajma-chawal.' }],
        ['Kabuli Chana', 'काबुली चना', '🫘', packs([['500 g', 500, 'g', 80, 95]]), { img: 'g-kabuli-chana', tags: 'chole,chana', desc: 'Bold kabuli chana for chole.' }],
      ] },
      { name: 'Oil & Ghee', emoji: '🛢️', color: '#FFFDE7', image: '/catalog/sub-oil.png', products: [
        ['Mustard Oil', 'सरसों का तेल', '🛢️', packs([['1 L', 1, 'l', 165, 190], ['5 L', 5, 'l', 790, 925]]), { best: 1, tags: 'sarso,mustard oil,kachi ghani', desc: 'Kachi ghani mustard oil.' }],
        ['Refined Sunflower Oil', 'रिफाइंड सूरजमुखी तेल', '🛢️', packs([['1 L', 1, 'l', 145, 170], ['5 L', 5, 'l', 690, 820]]), { img: 'g-sunflower-oil', tags: 'refined,sunflower oil', desc: 'Light refined sunflower oil for everyday cooking.' }],
        ['Desi Ghee', 'देसी घी', '🧈', packs([['500 ml', 500, 'ml', 330, 380], ['1 L', 1, 'l', 640, 740]]), { tags: 'ghee,cow ghee', desc: 'Pure cow desi ghee with rich aroma.' }],
      ] },
      { name: 'Masala, Salt & Sugar', emoji: '🌶️', color: '#FFEBEE', image: '/catalog/sub-masala.png', products: [
        ['Sugar', 'चीनी', '🧂', packs([['1 kg', 1, 'kg', 46, 52], ['5 kg', 5, 'kg', 225, 255]]), { img: 'g-sugar', best: 1, tags: 'cheeni,shakkar,sugar', desc: 'Clean white sulphur-free sugar.' }],
        ['Iodised Salt', 'नमक', '🧂', packs([['1 kg', 1, 'kg', 25, 28]]), { tags: 'namak,salt', desc: 'Free-flowing iodised salt.' }],
        ['Turmeric Powder', 'हल्दी पाउडर', '🌶️', packs([['100 g', 100, 'g', 32, 38], ['200 g', 200, 'g', 60, 72]]), { img: 'g-turmeric', tags: 'haldi', desc: 'Bright, aromatic haldi powder.' }],
        ['Dry Red Chilli (Whole)', 'सूखी लाल मिर्च', '🌶️', packs([['100 g', 100, 'g', 48, 56], ['250 g', 250, 'g', 115, 135]]), { img: 'g-red-chilli', tags: 'lal mirch,sukhi mirch,red chilli', desc: 'Sun-dried whole red chillies for tadka and masala.' }],
        ['Coriander Powder', 'धनिया पाउडर', '🌿', packs([['100 g', 100, 'g', 30, 36], ['200 g', 200, 'g', 56, 68]]), { img: 'g-coriander-powder', tags: 'dhaniya powder', desc: 'Freshly ground dhaniya powder.' }],
        ['Whole Garam Masala', 'खड़ा गरम मसाला', '🌶️', packs([['100 g', 100, 'g', 95, 115]]), { img: 'g-garam-masala', tags: 'garam masala,khada masala', desc: 'Whole spices mix — cardamom, cinnamon, clove, bay leaf, black pepper.' }],
        ['Jeera (Cumin)', 'जीरा', '🌿', packs([['100 g', 100, 'g', 55, 65], ['200 g', 200, 'g', 105, 125]]), { img: 'g-jeera', tags: 'jeera,cumin', desc: 'Bold, aromatic whole cumin seeds.' }],
      ] },
      { name: 'Tea & Breakfast', emoji: '🍵', color: '#EFEBE9', image: '/catalog/sub-tea.png', products: [
        ['Tea (CTC)', 'चाय पत्ती', '🍵', packs([['250 g', 250, 'g', 130, 150], ['500 g', 500, 'g', 250, 290]]), { img: 'g-tea', best: 1, tags: 'chai,tea,chai patti', desc: 'Strong Assam CTC tea for kadak chai.' }],
        ['Poha', 'पोहा', '🍚', packs([['500 g', 500, 'g', 40, 48], ['1 kg', 1, 'kg', 76, 90]]), { img: 'g-poha', tags: 'poha,chiwda,flattened rice', desc: 'Thick poha — perfect Indori breakfast.' }],
        ['Jaggery (Gud)', 'गुड़', '🟫', packs([['500 g', 500, 'g', 38, 45], ['1 kg', 1, 'kg', 70, 85]]), { img: 'g-jaggery', tags: 'gud,jaggery', desc: 'Chemical-free sugarcane jaggery.' }],
      ] },
    ],
  },
  {
    name: 'Dry Fruits & Nuts', emoji: '🥜', color: '#EFEBE9', image: '/catalog/cat-dryfruits.png',
    subs: [
      { name: 'Nuts', emoji: '🌰', color: '#EFEBE9', image: '/catalog/sub-nuts.png', products: [
        ['Almonds (Badam)', 'बादाम', '🌰', [
          { label: '250 g', quantity: 250, unit: 'g', price: 245, mrp: 299, stock: 100, isDefault: true },
          { label: '500 g', quantity: 500, unit: 'g', price: 470, mrp: 590, stock: 100 }], { img: 'almonds', best: 1, tags: 'badam', desc: 'California almonds, premium quality.' }],
        ['Cashew (Kaju)', 'काजू', '🥜', [
          { label: '250 g', quantity: 250, unit: 'g', price: 270, mrp: 330, stock: 100, isDefault: true },
          { label: '500 g', quantity: 500, unit: 'g', price: 520, mrp: 650, stock: 100 }], { img: 'cashew', tags: 'kaju', desc: 'Whole W320 cashews.' }],
        ['Pistachio (Pista)', 'पिस्ता', '🥜', single('200 g pack', 200, 'g', 280, 340), { img: 'pistachio', tags: 'pista', desc: 'Roasted & salted pistachios.' }],
        ['Walnut (Akhrot)', 'अखरोट', '🌰', single('250 g pack', 250, 'g', 190, 240), { img: 'walnut', tags: 'akhrot', desc: 'Kashmiri in-shell walnuts.' }],
      ] },
      { name: 'Dates', emoji: '🌴', color: '#FBE9E7', image: '/catalog/sub-dates.png', products: [
        ['Dates (Khajoor)', 'खजूर', '🌴', [
          { label: '500 g', quantity: 500, unit: 'g', price: 160, mrp: 199, stock: 100, isDefault: true },
          { label: '1 kg', quantity: 1, unit: 'kg', price: 300, mrp: 380, stock: 100 }], { img: 'dates', tags: 'khajoor,khajur', desc: 'Soft, sweet seeded dates.' }],
      ] },
    ],
  },
  {
    name: 'Organic Store', emoji: '🌿', color: '#F1F8E9', image: '/catalog/cat-organic.png',
    subs: [
      { name: 'Organic Vegetables', emoji: '🥗', color: '#E8F5E9', image: '/catalog/sub-organic-veg.png', products: [
        ['Organic Tomato', 'जैविक टमाटर', '🍅', byWeight(70, [0.5, 1]), { img: 'organic-tomato', organic: 1, desc: 'Certified organic tomatoes, grown without chemicals.' }],
        ['Organic Carrot', 'जैविक गाजर', '🥕', byWeight(90, [0.5, 1]), { img: 'organic-carrot', organic: 1, desc: 'Certified organic carrots.' }],
      ] },
      { name: 'Organic Fruits', emoji: '🍏', color: '#F9FBE7', image: '/catalog/sub-organic-fruits.png', products: [
        ['Organic Banana', 'जैविक केला', '🍌', byPiece(9, [6, 12]), { img: 'organic-banana', organic: 1, desc: 'Certified organic bananas.' }],
        ['Organic Green Apple', 'जैविक हरा सेब', '🍏', byWeight(360, [0.5, 1]), { img: 'organic-apple', organic: 1, desc: 'Certified organic green apples.' }],
      ] },
    ],
  },
  {
    name: 'Baskets & Combos', emoji: '🧺', color: '#EDE7F6', image: '/catalog/cat-baskets.png',
    subs: [
      { name: 'Weekly Baskets', emoji: '🧺', color: '#EDE7F6', image: '/catalog/sub-baskets.png', products: [
        ['Weekly Veggie Basket', 'साप्ताहिक सब्ज़ी टोकरी', '🧺', single('5 kg basket', 5, 'kg', 299, 380), { img: 'basket-veggie', feat: 1, desc: 'Onion 1 kg, Potato 1 kg, Tomato 1 kg, Carrot 500 g, Capsicum 250 g and 1 Cabbage.' }],
        ['Fruit Family Pack', 'फल परिवार पैक', '🧺', single('4 kg pack', 4, 'kg', 449, 560), { img: 'basket-fruit', desc: 'Apple 1 kg, Orange 1 kg, Pomegranate 500 g, Banana 6 pcs and seasonal Mango 1 kg.' }],
        ['Salad Combo', 'सलाद कॉम्बो', '🥗', single('2 kg pack', 2, 'kg', 149, 189), { img: 'basket-salad', desc: 'Cucumber 500 g, Tomato 500 g, Carrot 500 g, Beetroot 250 g and 4 Lemons.' }],
      ] },
    ],
  },
];

const banners = [
  { title: 'Mandi fresh, at your door', subtitle: 'Farm-fresh sabzi delivered in 30 mins', emoji: '🚚', bgColor: '#2E7D32' },
  { title: 'Flat ₹50 OFF', subtitle: 'On your first order • Use code FRESH50', emoji: '🎉', bgColor: '#E65100' },
  { title: 'Dry Fruits Fest 🥜', subtitle: 'Badam, Kaju, Pista — up to 20% off', emoji: '🥜', bgColor: '#8D6E63' },
  { title: 'Monthly Kirana Sale', subtitle: 'Atta, Dal, Oil & Masala at mandi prices', emoji: '🛒', bgColor: '#6D4C41' },
  { title: 'Go Organic', subtitle: 'Chemical-free fruits & veggies', emoji: '🌿', bgColor: '#558B2F' },
];

const coupons = [
  { code: 'FRESH50', description: 'Flat ₹50 off on orders above ₹199', type: 'flat', value: 50, minOrder: 199 },
  { code: 'MANDI10', description: '10% off up to ₹100 on orders above ₹499', type: 'percent', value: 10, minOrder: 499, maxDiscount: 100 },
  { code: 'FREESHIP', description: '₹30 off — free delivery on any order above ₹149', type: 'flat', value: 30, minOrder: 149 },
];

// Bump when the demo catalogue changes; existing installs without orders are re-seeded automatically.
const CATALOG_VERSION = 2;

async function seedCatalog() {
  let order = 0;
  for (const c of catalog) {
    const cat = await Category.create({ name: c.name, slug: slugify(c.name), emoji: c.emoji, color: c.color, image: c.image, sortOrder: order++ });
    let subOrder = 0;
    for (const s of c.subs) {
      const sub = await Category.create({ name: s.name, slug: slugify(`${c.name}-${s.name}`), emoji: s.emoji, color: s.color, image: s.image, parent: cat._id, sortOrder: subOrder++ });
      for (const [name, hindiName, emoji, variants, o] of s.products) {
        await Product.create({
          name, hindiName, emoji, variants,
          images: o.img ? [IMG(o.img)] : [],
          slug: slugify(name),
          category: cat._id, subCategory: sub._id,
          description: o.desc || `Fresh ${name.toLowerCase()} sourced directly from the mandi every morning.`,
          tags: o.tags ? o.tags.split(',') : [],
          isFeatured: !!o.feat, isBestSeller: !!o.best, isOrganic: !!o.organic || c.name === 'Organic Store',
          origin: ['Dry Fruits & Nuts', 'Grocery & Staples'].includes(c.name) ? 'Quality checked' : 'Local Mandi',
          shelfLife: ['Dry Fruits & Nuts', 'Grocery & Staples'].includes(c.name) ? '6 months' : c.name === 'Fresh Fruits' ? '4-6 days' : '2-4 days',
          storageTips: ['Dry Fruits & Nuts', 'Grocery & Staples'].includes(c.name) ? 'Store in an airtight container in a cool, dry place.' : 'Store in a cool place or refrigerate. Wash well before use.',
          rating: Math.round((4.2 + Math.random() * 0.7) * 10) / 10,
          ratingCount: Math.floor(50 + Math.random() * 900),
          soldCount: Math.floor(Math.random() * 500),
        });
      }
    }
  }
  await Banner.insertMany(banners.map((b, i) => ({ ...b, sortOrder: i })));
  for (const c of coupons) await Coupon.updateOne({ code: c.code }, { $setOnInsert: c }, { upsert: true });
  console.log(`✅ Seeded ${await Category.countDocuments()} categories, ${await Product.countDocuments()} products`);
}

const wipeCatalog = () => Promise.all([Category.deleteMany({}), Product.deleteMany({}), Banner.deleteMany({})]);

(async () => {
  await mongoose.connect(process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/mandiathome');
  const settings = await Setting.get();
  const hasProducts = (await Product.countDocuments()) > 0;

  if (fresh) {
    await wipeCatalog();
    console.log('🧹 Catalog wiped (--fresh)');
    await seedCatalog();
  } else if (!hasProducts) {
    await seedCatalog();
  } else if ((settings.catalogVersion || 1) < CATALOG_VERSION) {
    if ((await Order.countDocuments()) === 0) {
      console.log(`⬆️  Upgrading demo catalogue to v${CATALOG_VERSION} (no orders yet)`);
      await wipeCatalog();
      await seedCatalog();
    } else {
      // Live store: never wipe. Only fill missing photos for products with the same name.
      let n = 0;
      for (const c of catalog) for (const s of c.subs) for (const [name, , , , o] of s.products) {
        if (!o.img) continue;
        const r = await Product.updateOne({ name, $or: [{ images: { $size: 0 } }, { images: { $exists: false } }] }, { $set: { images: [IMG(o.img)] } });
        n += r.modifiedCount;
      }
      console.log(`ℹ️  Store has orders — catalogue kept, photos added to ${n} products.`);
    }
  } else {
    console.log('ℹ️  Catalogue up to date.');
  }
  if ((settings.catalogVersion || 1) < CATALOG_VERSION) {
    settings.catalogVersion = CATALOG_VERSION;
    await settings.save();
  }

  const email = (process.env.ADMIN_EMAIL || 'admin@mandiathome.com').toLowerCase();
  if (!(await User.findOne({ email }))) {
    await User.create({ name: 'Admin', email, password: process.env.ADMIN_PASSWORD || 'Admin@123', role: 'admin' });
    console.log(`👤 Admin created: ${email}`);
  }
  await mongoose.disconnect();
})().catch((e) => { console.error(e); process.exit(1); });
