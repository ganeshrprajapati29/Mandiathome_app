require('dotenv').config();
const app = require('./src/app');
const connectDB = require('./src/config/db');

const PORT = process.env.PORT || 6055;

connectDB().then(() => {
  app.listen(PORT, () => console.log(`🥦 Mandi At Home API running on port ${PORT}`));
  // Release stock held by online orders that were never paid.
  const { expireUnpaidOrders } = require('./src/utils/orderPayments');
  setInterval(() => expireUnpaidOrders().catch((e) => console.error('[expire]', e.message)), 5 * 60 * 1000);
});
