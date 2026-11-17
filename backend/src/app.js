const express = require('express');
const path = require('path');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const { notFound, errorHandler } = require('./middleware/error');

const app = express();

app.set('trust proxy', 1);
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' }, contentSecurityPolicy: false }));
app.use(cors());
app.use(compression());
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));
if (process.env.NODE_ENV !== 'test') app.use(morgan('tiny'));

app.use('/uploads', express.static(path.join(__dirname, '../uploads'), { maxAge: '7d' }));
app.use('/catalog', express.static(path.join(__dirname, '../public/catalog'), { maxAge: '30d' }));
app.use('/admin', express.static(path.join(__dirname, '../public/admin')));

const apiInfo = (req, res) => res.json({
  success: true,
  name: 'Mandi At Home API',
  version: '1.0.0',
  endpoints: { health: '/api/health', home: '/api/home', categories: '/api/categories', products: '/api/products', admin: '/admin/' },
});
app.get(['/', '/api', '/api/'], apiInfo);
app.get('/api/health', (req, res) => res.json({ success: true, status: 'ok', time: new Date() }));

app.use('/api/auth', require('./routes/auth'));
app.use('/api/categories', require('./routes/categories'));
app.use('/api/products', require('./routes/products'));
app.use('/api/cart', require('./routes/cart'));
app.use('/api/orders', require('./routes/orders'));
app.use('/api/user', require('./routes/user'));
app.use('/api/admin', require('./routes/admin'));
app.use('/api', require('./routes/store'));

app.use(notFound);
app.use(errorHandler);

module.exports = app;
