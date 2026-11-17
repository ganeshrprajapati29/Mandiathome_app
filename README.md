# Mandi At Home 🥦🍎

<p align="center">
  <img src="assets/logo.jpg" alt="Mandi At Home logo" width="200"/>
</p>

**Mandi At Home** is a grocery e-commerce app for fresh fruits and vegetables. Customers buy straight from the mandi, by kg, gram, piece, bunch or dozen, and the order is delivered to their home.

| Part | Tech | Folder |
|---|---|---|
| Mobile app (Android + iOS) | Flutter, Provider | [`app/`](app) |
| REST API | Node.js, Express, MongoDB (Mongoose) | [`backend/`](backend) |
| Admin panel (web) | Vanilla JS, served by the API at `/admin` | [`backend/public/admin`](backend/public/admin) |

---

## ✨ Features

**Customer app**
- Animated splash (the truck drives in, veggies drop in, the brand letters pop up), onboarding, and a custom app icon
- OTP login using a mobile number
- Home: auto-sliding banners, sub-category grid, Fresh Picks, Best Sellers, a rail for each category, and Organic
- **Category → Sub-category** screen with a sidebar (like Blinkit/Zepto), plus sorting
- **Pack sizes with their own prices**: 250 g / 500 g / 1 kg / 2 kg / 5 kg, pieces, bunches, dozens, packs. Each pack size has its own price, MRP, discount % and stock, and the app shows a per-kg price hint
- Search with debounce, recent searches and popular searches
- Product detail: pack size selector, discount, storage tips and similar products
- Cart kept on the server, a floating "View cart" bar, a free-delivery progress bar, coupons and full bill details
- Checkout: saved addresses, delivery date and slot, COD, and delivery notes
- Order success animation, order history, live status tracker, and customer cancellation (before the order is packed)
- Wishlist, address book, profile and support

**Admin panel** at `http://<server>:6055/admin`
- Dashboard: today's and total orders and revenue, orders by status, low-stock alerts
- Orders: filter, view, and update order and payment status (stock goes back automatically when an order is cancelled)
- **Products & prices**: change Price, MRP and Stock directly from the table, then add or edit products with any number of pack sizes and an image upload
- Categories and sub-categories, banners, coupons, customers (block/unblock)
- Store settings: delivery fee, free-delivery threshold, minimum order, delivery slots, serviceable pincodes, store open/closed, COD on/off

---

## 🚀 Backend: deploy on a VPS (one command)

Run this on the server as root:

```bash
curl -fsSL https://raw.githubusercontent.com/ganeshrprajapati29/Mandiathome_app/main/backend/deploy.sh | bash
```

The script is **safe for a server that already runs other apps**:
- The code goes into its own folder, `/var/www/mandiathome`
- The API runs on its own port, **6055**, as the PM2 process `mandiathome-api`
- It uses its own MongoDB database, `mandiathome`. If MongoDB is already running, it is reused, and other databases are not touched
- It does **not** change nginx, other PM2 apps, or existing Node and MongoDB installs (it only installs what is missing)
- It creates `.env` once, with a random JWT secret, and seeds the demo catalogue only when the database is empty

Run the same command again to **update** to the latest code.

After deployment:
- API health check: `http://<server-ip>:6055/api/health`
- Admin panel: `http://<server-ip>:6055/admin`. Login: `admin@mandiathome.com` / `Admin@123`. **Change `ADMIN_PASSWORD` in `/var/www/mandiathome/backend/.env` before the first run, or create a new admin.**
- Logs: `pm2 logs mandiathome-api`

> OTP: `OTP_DEV_MODE=true` uses OTP **1234** and returns it in the response (for testing). Connect an SMS provider (MSG91, Fast2SMS, Twilio) in `backend/src/routes/auth.js → sendSms()`, then set `OTP_DEV_MODE=false`.

### Run locally
```bash
cd backend
cp .env.example .env      # set MONGO_URI
npm install
npm run seed              # demo categories, products, banners, coupons and the admin account
npm run dev
```

### Main API endpoints
| Method | Path | Notes |
|---|---|---|
| POST | `/api/auth/send-otp`, `/api/auth/verify-otp` | Phone OTP login |
| GET | `/api/home` | Banners, categories and product rails in one call |
| GET | `/api/categories` | Categories with their sub-categories |
| GET | `/api/products?category=&subCategory=&search=&sort=` | Product list |
| GET/POST/DELETE | `/api/cart`, `/api/cart/coupon` | Server-side cart, prices always calculated on the server |
| POST/GET | `/api/orders`, `/api/orders/:id/cancel` | Place, list and cancel orders |
| CRUD | `/api/user/addresses`, `/api/user/wishlist/:id` | |
| Admin | `/api/admin/*`, `PATCH /api/products/:id/variants/:vid` | Stats, upload, settings, quick price update |

---

## 📱 Flutter app

```bash
cd app
flutter pub get
flutter run
```

**Set the server address** in `app/lib/config/api_config.dart` (`host`). It defaults to `http://72.60.41.224:6055`. You can also set it at build time:
```bash
flutter build apk --release --dart-define=API_HOST=https://api.yourdomain.com
```

Regenerate the icon and splash after changing the logo:
```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

> The `android/` and `ios/` folders were generated with a recent Flutter. If an older Flutter fails to build them, delete those two folders, run `flutter create --org com.mandiathome --platforms android,ios .`, then run the two commands above. After that, add `INTERNET` permission and `usesCleartextTraffic` back to `AndroidManifest.xml`.
