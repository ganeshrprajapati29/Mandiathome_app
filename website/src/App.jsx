import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ArrowDown, ArrowRight, BadgeCheck, Check, ChevronDown, ChevronRight,
  Clock3, Heart, Leaf, MapPin, Menu, Minus, Plus, Search,
  ShieldCheck, ShoppingBag, ShoppingBasket, Sparkles, Star, Truck, UserRound, X,
} from 'lucide-react';
import logo from '../../assets/logo.jpg';
import { api, guestCartSummary, imageUrl, normalizeCart } from './api.js';
import AccountModal from './AccountModal.jsx';

const TOKEN_KEY = 'mah_customer_token';
const USER_KEY = 'mah_customer_user';
const GUEST_CART_KEY = 'mah_guest_cart';
const money = (value) => `₹${Number(value || 0).toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;
const getId = (value) => typeof value === 'string' ? value : value?._id || '';
const readStored = (key, fallback) => {
  try {
    const value = localStorage.getItem(key);
    return value ? JSON.parse(value) : fallback;
  } catch {
    return fallback;
  }
};

function ProductImage({ product, className = '' }) {
  const [failed, setFailed] = useState(false);
  const src = imageUrl(product?.images?.[0] || product?.image);
  return (
    <div className={`product-image ${className}`}>
      {src && !failed
        ? <img src={src} alt={product?.name || 'Fresh produce'} loading="lazy" onError={() => setFailed(true)} />
        : <span aria-hidden="true">{product?.emoji || '🥬'}</span>}
    </div>
  );
}

function Modal({ children, onClose, wide = false, label = 'Dialog' }) {
  useEffect(() => {
    const closeOnEscape = (event) => event.key === 'Escape' && onClose();
    window.addEventListener('keydown', closeOnEscape);
    return () => window.removeEventListener('keydown', closeOnEscape);
  }, [onClose]);

  return (
    <div className="overlay" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section className={`modal ${wide ? 'modal-wide' : ''}`} role="dialog" aria-modal="true" aria-label={label}>
        <button className="icon-button modal-close" type="button" onClick={onClose} aria-label="Close"><X size={20} /></button>
        {children}
      </section>
    </div>
  );
}

function ProductCard({ product, onOpen, onAdd, cartCount, wishlistIds, onToggleWishlist }) {
  const variants = product.variants || [];
  const defaultVariant = variants.find((variant) => variant.isDefault) || variants[0];
  const [variantId, setVariantId] = useState(defaultVariant?._id || '');
  const selected = variants.find((variant) => variant._id === variantId) || defaultVariant;

  useEffect(() => setVariantId(defaultVariant?._id || ''), [defaultVariant?._id]);

  if (!selected) return null;
  const discount = selected.mrp > selected.price ? Math.round((1 - selected.price / selected.mrp) * 100) : 0;
  const quantity = cartCount(product._id, selected._id);

  return (
    <article className="product-card">
      <button className="product-open" type="button" onClick={() => onOpen(product)} aria-label={`View ${product.name}`}>
        <ProductImage product={product} />
        {discount > 0 && <span className="discount-tag">{discount}% off</span>}
        {product.isOrganic && <span className="organic-tag"><Leaf size={11} /> Organic</span>}
        <span className="quick-view">Quick view <ArrowRight size={13} /></span>
      </button>
      {onToggleWishlist && <button className={`wishlist-toggle ${wishlistIds?.has(product._id) ? 'is-saved' : ''}`} type="button" onClick={() => onToggleWishlist(product)} aria-label={`${wishlistIds?.has(product._id) ? 'Remove' : 'Add'} ${product.name} ${wishlistIds?.has(product._id) ? 'from' : 'to'} wishlist`}><Heart size={16} fill={wishlistIds?.has(product._id) ? 'currentColor' : 'none'} /></button>}
      <div className="product-info">
        <span className="product-kicker">{product.category?.name || product.categoryName || 'Fresh today'}</span>
        <h3>{product.name}</h3>
        {product.hindiName && <p className="hindi-name">{product.hindiName}</p>}
        <div className="rating"><Star size={12} fill="currentColor" /> {Number(product.rating || 4.5).toFixed(1)} <span>({product.ratingCount || 0})</span></div>
        <div className="product-buy-row">
          <div className="price-stack">
            <strong>{money(selected.price)}</strong>
            {selected.mrp > selected.price && <del>{money(selected.mrp)}</del>}
          </div>
          <button className={`add-button ${quantity ? 'in-cart' : ''}`} type="button" onClick={() => onAdd(product, selected)}>
            {quantity ? <><Check size={14} /> {quantity}</> : <><Plus size={15} /> Add</>}
          </button>
        </div>
        {variants.length > 1 && (
          <label className="variant-select">
            <span className="sr-only">Choose pack size</span>
            <select value={selected._id} onChange={(event) => setVariantId(event.target.value)}>
              {variants.map((variant) => <option key={variant._id} value={variant._id}>{variant.label}</option>)}
            </select>
            <ChevronDown size={14} />
          </label>
        )}
        {variants.length === 1 && <span className="single-variant">{selected.label}</span>}
      </div>
    </article>
  );
}

function ProductRail({ title, eyebrow, products, onOpen, onAdd, cartCount, action, wishlistIds, onToggleWishlist }) {
  if (!products?.length) return null;
  return (
    <section className="rail-section">
      <div className="section-heading">
        <div><span className="eyebrow">{eyebrow}</span><h2>{title}</h2></div>
        {action && <button className="text-button" type="button" onClick={action}>View all <ArrowRight size={15} /></button>}
      </div>
      <div className="product-grid">
        {products.map((product) => <ProductCard key={product._id} product={product} onOpen={onOpen} onAdd={onAdd} cartCount={cartCount} wishlistIds={wishlistIds} onToggleWishlist={onToggleWishlist} />)}
      </div>
    </section>
  );
}

function AuthModal({ onClose, onAuthenticated }) {
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState('');
  const [requested, setRequested] = useState(false);
  const [devOtp, setDevOtp] = useState('');
  const [resendIn, setResendIn] = useState(0);
  const [expiresIn, setExpiresIn] = useState(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!requested || resendIn <= 0) return undefined;
    const timer = window.setTimeout(() => setResendIn((seconds) => Math.max(0, seconds - 1)), 1000);
    return () => window.clearTimeout(timer);
  }, [requested, resendIn]);

  async function sendOtp(event) {
    event.preventDefault();
    setError('');
    setBusy(true);
    try {
      const result = await api('/auth/send-otp', { method: 'POST', body: { phone } });
      setDevOtp(import.meta.env.DEV ? result.devOtp || '' : '');
      setResendIn(Number(result.resendIn || 30));
      setExpiresIn(Number(result.expiresIn || 600));
      setOtp('');
      setRequested(true);
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setBusy(false);
    }
  }

  async function verifyOtp(event) {
    event.preventDefault();
    setError('');
    setBusy(true);
    try {
      const result = await api('/auth/verify-otp', { method: 'POST', body: { phone, otp } });
      await onAuthenticated(result.token, result.user);
      onClose();
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal onClose={onClose} label="Sign in">
      <div className="auth-art"><img src={logo} alt="Mandi At Home" /><span>Good food starts with good choices.</span></div>
      <span className="eyebrow">WELCOME TO YOUR MANDI</span>
      <h2>{requested ? 'Verify your number' : 'Sign in to continue'}</h2>
      <p className="muted">{requested ? `We sent a one-time code to +91 ${phone}` : 'Enter your mobile number for a secure one-time login.'}</p>
      <form className="form-stack" onSubmit={requested ? verifyOtp : sendOtp}>
        {!requested
          ? <label className="field-label">Mobile number <span className="phone-input"><span>+91</span><input autoFocus type="tel" inputMode="numeric" minLength="10" maxLength="10" pattern="[6-9][0-9]{9}" required value={phone} onChange={(event) => setPhone(event.target.value.replace(/\D/g, '').slice(0, 10))} placeholder="10-digit number" /></span></label>
          : <label className="field-label">One-time password<input autoFocus className="text-input otp-input" inputMode="numeric" maxLength="8" required value={otp} onChange={(event) => setOtp(event.target.value.replace(/\D/g, '').slice(0, 8))} placeholder="Enter OTP" /></label>}
        {devOtp && requested && <div className="dev-code"><ShieldCheck size={16} /> Local test OTP: <strong>{devOtp}</strong></div>}
        {requested && !devOtp && <p className="otp-timer">Code expires in {Math.ceil(expiresIn / 60)} min.</p>}
        {error && <p className="form-error" role="alert">{error}</p>}
        <button className="button button-primary button-full" disabled={busy} type="submit">{busy ? 'Please wait…' : requested ? 'Verify & sign in' : 'Send OTP'} <ArrowRight size={16} /></button>
        {requested && <div className="otp-actions">
          <button className="text-button" type="button" disabled={busy || resendIn > 0} onClick={sendOtp}>{resendIn > 0 ? `Resend in ${resendIn}s` : 'Resend code'}</button>
          <button className="text-button" type="button" onClick={() => { setRequested(false); setOtp(''); setDevOtp(''); setResendIn(0); }}>Change number</button>
        </div>}
      </form>
      <p className="legal-note"><ShieldCheck size={13} /> Your number is only used to manage your orders.</p>
    </Modal>
  );
}

function AddressFields({ onSave, busy, onCancel }) {
  const [form, setForm] = useState({ label: 'Home', name: '', phone: '', line1: '', line2: '', city: '', state: '', pincode: '' });
  const change = (event) => setForm((value) => ({ ...value, [event.target.name]: event.target.value }));
  return (
    <form className="address-form" onSubmit={(event) => { event.preventDefault(); onSave(form); }}>
      <div className="field-grid">
        <label className="field-label">Address type<select className="text-input" name="label" value={form.label} onChange={change}><option>Home</option><option>Work</option><option>Other</option></select></label>
        <label className="field-label">Full name<input className="text-input" name="name" required value={form.name} onChange={change} /></label>
        <label className="field-label">Phone number<input className="text-input" name="phone" type="tel" inputMode="numeric" required minLength="10" maxLength="10" value={form.phone} onChange={(event) => setForm((value) => ({ ...value, phone: event.target.value.replace(/\D/g, '').slice(0, 10) }))} /></label>
        <label className="field-label field-span">House / street / area<input className="text-input" name="line1" required value={form.line1} onChange={change} /></label>
        <label className="field-label field-span">Apartment, floor or landmark <span className="optional">(optional)</span><input className="text-input" name="line2" value={form.line2} onChange={change} /></label>
        <label className="field-label">City<input className="text-input" name="city" required value={form.city} onChange={change} /></label>
        <label className="field-label">State<input className="text-input" name="state" value={form.state} onChange={change} /></label>
        <label className="field-label">PIN code<input className="text-input" name="pincode" inputMode="numeric" pattern="[0-9]{6}" required minLength="6" maxLength="6" value={form.pincode} onChange={(event) => setForm((value) => ({ ...value, pincode: event.target.value.replace(/\D/g, '').slice(0, 6) }))} /></label>
      </div>
      <div className="address-actions"><button className="button button-light" type="button" onClick={onCancel}>Cancel</button><button className="button button-primary" disabled={busy} type="submit">{busy ? 'Saving…' : 'Save address'}</button></div>
    </form>
  );
}

function CheckoutModal({ cart, settings, token, onClose, onOrdered }) {
  const [addresses, setAddresses] = useState([]);
  const [selectedAddress, setSelectedAddress] = useState('');
  const [addingAddress, setAddingAddress] = useState(false);
  const [date, setDate] = useState(() => new Date(Date.now() + 86400000).toISOString().slice(0, 10));
  const [slot, setSlot] = useState(settings.deliverySlots?.[0] || '10 AM - 1 PM');
  const [paymentMethod, setPaymentMethod] = useState(settings.codEnabled ? 'COD' : 'ONLINE');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    api('/user/addresses', { token })
      .then((result) => {
        const saved = result.data || [];
        setAddresses(saved);
        setSelectedAddress(saved.find((address) => address.isDefault)?._id || saved[0]?._id || '');
      })
      .catch((requestError) => setError(requestError.message));
  }, [token]);

  async function saveAddress(address) {
    setBusy(true);
    setError('');
    try {
      const result = await api('/user/addresses', { method: 'POST', token, body: address });
      setAddresses(result.data || []);
      const newest = (result.data || []).at(-1);
      setSelectedAddress(newest?._id || '');
      setAddingAddress(false);
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setBusy(false);
    }
  }

  async function placeOrder(event) {
    event.preventDefault();
    if (!selectedAddress) {
      setError('Add and select a delivery address first.');
      return;
    }
    setBusy(true);
    setError('');
    try {
      const result = await api('/orders', {
        method: 'POST',
        token,
        body: { addressId: selectedAddress, paymentMethod, deliverySlot: { date, slot }, note },
      });
      let order = result.data;
      if (result.payment) {
        try {
          await loadRazorpay();
          order = await new Promise((resolve, reject) => {
            const checkout = new window.Razorpay({
              key: result.payment.key,
              amount: result.payment.amount,
              currency: result.payment.currency,
              name: result.payment.name,
              description: result.payment.description,
              order_id: result.payment.razorpayOrderId,
              prefill: result.payment.prefill,
              theme: { color: '#28633f' },
              handler: async (response) => {
                try {
                  const verified = await api(`/orders/${result.data._id}/verify-payment`, { method: 'POST', token, body: response });
                  resolve(verified.data);
                } catch (verificationError) {
                  reject(verificationError);
                }
              },
              modal: { ondismiss: () => reject(new Error('Payment was cancelled. Your basket is still saved.')) },
            });
            checkout.on('payment.failed', (failure) => reject(new Error(failure.error?.description || 'Payment did not go through.')));
            checkout.open();
          });
        } catch (paymentError) {
          await api(`/orders/${result.data._id}/payment-failed`, { method: 'POST', token, body: { reason: paymentError.message } });
          throw paymentError;
        }
      }
      onOrdered(order);
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal onClose={onClose} wide label="Checkout">
      <div className="checkout-title"><span className="eyebrow">ALMOST AT YOUR DOOR</span><h2>Checkout</h2><p>Freshness, packed with care.</p></div>
      <form className="checkout-layout" onSubmit={placeOrder}>
        <div className="checkout-main">
          <section className="checkout-section">
            <div className="checkout-section-title"><span className="step-number">1</span><div><h3>Delivery address</h3><p>Where should we bring your mandi?</p></div></div>
            {addresses.length > 0 && !addingAddress && <div className="address-list">
              {addresses.map((address) => <label className={`address-option ${selectedAddress === address._id ? 'selected' : ''}`} key={address._id}>
                <input type="radio" name="address" checked={selectedAddress === address._id} onChange={() => setSelectedAddress(address._id)} />
                <span className="address-radio" />
                <span><strong>{address.label} · {address.name}</strong><small>{[address.line1, address.line2, `${address.city} ${address.pincode}`].filter(Boolean).join(', ')}</small><small>+91 {address.phone}</small></span>
              </label>)}
            </div>}
            {addingAddress ? <AddressFields onSave={saveAddress} busy={busy} onCancel={() => setAddingAddress(false)} />
              : <button className="add-address-link" type="button" onClick={() => setAddingAddress(true)}><Plus size={15} /> Add a new address</button>}
          </section>

          <section className="checkout-section">
            <div className="checkout-section-title"><span className="step-number">2</span><div><h3>Delivery time</h3><p>Pick a day and a time that works for you.</p></div></div>
            <div className="field-grid">
              <label className="field-label">Delivery date<input className="text-input" type="date" min={new Date().toISOString().slice(0, 10)} value={date} onChange={(event) => setDate(event.target.value)} required /></label>
              <label className="field-label">Time slot<select className="text-input" value={slot} onChange={(event) => setSlot(event.target.value)}>{(settings.deliverySlots?.length ? settings.deliverySlots : ['10 AM - 1 PM']).map((item) => <option key={item}>{item}</option>)}</select></label>
              <label className="field-label field-span">Delivery note <span className="optional">(optional)</span><input className="text-input" value={note} onChange={(event) => setNote(event.target.value)} placeholder="Anything we should know?" /></label>
            </div>
          </section>

          <section className="checkout-section">
            <div className="checkout-section-title"><span className="step-number">3</span><div><h3>Payment</h3><p>Secure checkout, your way.</p></div></div>
            <div className="payment-options">
              {settings.codEnabled && <label className={`payment-option ${paymentMethod === 'COD' ? 'selected' : ''}`}><input type="radio" name="payment" value="COD" checked={paymentMethod === 'COD'} onChange={() => setPaymentMethod('COD')} /><span className="payment-icon">₹</span><span><strong>Cash on delivery</strong><small>Pay when your order arrives</small></span><span className="address-radio" /></label>}
              {settings.onlinePaymentAvailable && <label className={`payment-option ${paymentMethod === 'ONLINE' ? 'selected' : ''}`}><input type="radio" name="payment" value="ONLINE" checked={paymentMethod === 'ONLINE'} onChange={() => setPaymentMethod('ONLINE')} /><span className="payment-icon"><ShieldCheck size={18} /></span><span><strong>Pay online</strong><small>UPI, cards and net banking</small></span><span className="address-radio" /></label>}
              {!settings.codEnabled && !settings.onlinePaymentAvailable && <p className="form-error">No payment methods are available right now.</p>}
            </div>
          </section>
          {error && <p className="form-error checkout-error" role="alert">{error}</p>}
        </div>

        <aside className="checkout-summary">
          <h3>Your basket <span>{cart.count} items</span></h3>
          <div className="summary-items">{cart.items.map((item) => <div className="summary-item" key={`${item.productId}-${item.variantId}`}>
            <ProductImage product={{ image: item.image, emoji: item.emoji }} />
            <div><strong>{item.name}</strong><small>{item.variantLabel} × {item.qty}</small></div>
            <b>{money(item.total)}</b>
          </div>)}</div>
          <PriceBreakdown cart={cart} />
          <button className="button button-primary button-full place-order" disabled={busy || !cart.items.length} type="submit">{busy ? 'Placing order…' : <>Place order <ArrowRight size={16} /></>}</button>
          <p className="secure-note"><ShieldCheck size={14} /> Your details are encrypted and secure.</p>
        </aside>
      </form>
    </Modal>
  );
}

function PriceBreakdown({ cart }) {
  return (
    <div className="price-breakdown">
      <div><span>Items total</span><span>{money(cart.itemsTotal)}</span></div>
      {cart.savings > 0 && <div className="saving-row"><span>You saved</span><span>−{money(cart.savings)}</span></div>}
      {cart.couponDiscount > 0 && <div className="saving-row"><span>Coupon{cart.coupon ? ` (${cart.coupon})` : ''}</span><span>−{money(cart.couponDiscount)}</span></div>}
      <div><span>Delivery</span><span>{cart.deliveryFee ? money(cart.deliveryFee) : cart.itemsTotal ? 'FREE' : money(0)}</span></div>
      {cart.handlingFee > 0 && <div><span>Handling</span><span>{money(cart.handlingFee)}</span></div>}
      <div className="grand-total"><strong>Total to pay</strong><strong>{money(cart.grandTotal)}</strong></div>
    </div>
  );
}

function loadRazorpay() {
  if (window.Razorpay) return Promise.resolve();
  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = 'https://checkout.razorpay.com/v1/checkout.js';
    script.onload = () => resolve();
    script.onerror = () => reject(new Error('Could not load secure payment checkout.'));
    document.body.appendChild(script);
  });
}

function App() {
  const initialToken = localStorage.getItem(TOKEN_KEY) || '';
  const [token, setToken] = useState(initialToken);
  const [user, setUser] = useState(() => readStored(USER_KEY, null));
  const [guestItems, setGuestItems] = useState(() => readStored(GUEST_CART_KEY, []));
  const [serverCart, setServerCart] = useState(null);
  const [home, setHome] = useState(null);
  const [homeError, setHomeError] = useState('');
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState(null);
  const [catalog, setCatalog] = useState(null);
  const [catalogLoading, setCatalogLoading] = useState(false);
  const [query, setQuery] = useState('');
  const [product, setProduct] = useState(null);
  const [productVariantId, setProductVariantId] = useState('');
  const [similarProducts, setSimilarProducts] = useState([]);
  const [productLoading, setProductLoading] = useState(false);
  const [cartOpen, setCartOpen] = useState(false);
  const [loginOpen, setLoginOpen] = useState(false);
  const [accountOpen, setAccountOpen] = useState(false);
  const [accountInitialTab, setAccountInitialTab] = useState('orders');
  const [accountRequested, setAccountRequested] = useState(false);
  const [wishlistIds, setWishlistIds] = useState(() => new Set());
  const [checkoutOpen, setCheckoutOpen] = useState(false);
  const [checkoutRequested, setCheckoutRequested] = useState(false);
  const [orderComplete, setOrderComplete] = useState(null);
  const [notice, setNotice] = useState('');
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [couponCode, setCouponCode] = useState('');
  const [couponBusy, setCouponBusy] = useState(false);
  const [coupons, setCoupons] = useState([]);
  const noticeTimer = useRef(null);
  const skipAuthBootstrap = useRef(false);
  const productRequest = useRef(0);

  const settings = home?.settings || {};
  const cart = useMemo(
    () => token && serverCart ? normalizeCart(serverCart) : guestCartSummary(guestItems, settings),
    [token, serverCart, guestItems, settings],
  );

  const notify = useCallback((message) => {
    setNotice(message);
    window.clearTimeout(noticeTimer.current);
    noticeTimer.current = window.setTimeout(() => setNotice(''), 2800);
  }, []);

  const loadHome = useCallback(async () => {
    setLoading(true);
    setHomeError('');
    try {
      const result = await api('/home');
      setHome(result.data);
    } catch (error) {
      setHomeError(error.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadHome(); }, [loadHome]);

  useEffect(() => {
    if (!token) {
      setServerCart(null);
      return;
    }
    if (skipAuthBootstrap.current) {
      skipAuthBootstrap.current = false;
      return;
    }
    Promise.all([api('/auth/me', { token }), api('/cart', { token })])
      .then(([profile, basket]) => {
        setUser(profile.user);
        localStorage.setItem(USER_KEY, JSON.stringify(profile.user));
        setServerCart(basket.data);
      })
      .catch((error) => {
        if (error.status === 401) {
          localStorage.removeItem(TOKEN_KEY);
          localStorage.removeItem(USER_KEY);
          setToken('');
          setUser(null);
          notify('Your session expired. Please sign in again.');
        } else {
          notify(error.message);
        }
      });
    api('/user/wishlist', { token })
      .then((result) => setWishlistIds(new Set((result.data || []).map((item) => getId(item)))))
      .catch((error) => { if (error.status !== 401) notify(error.message); });
  }, [token, notify]);

  useEffect(() => {
    localStorage.setItem(GUEST_CART_KEY, JSON.stringify(guestItems));
  }, [guestItems]);

  useEffect(() => {
    if (!cartOpen) return;
    api('/coupons')
      .then((result) => setCoupons(result.data || []))
      .catch((error) => notify(error.message));
  }, [cartOpen, notify]);

  useEffect(() => {
    if (!filter) {
      setCatalog(null);
      return;
    }
    const controller = new AbortController();
    const params = new URLSearchParams({ limit: '24', page: String(filter.page || 1) });
    if (filter.search) params.set('search', filter.search);
    if (filter.category) params.set('category', filter.category);
    if (filter.subCategory) params.set('subCategory', filter.subCategory);
    if (filter.sort) params.set('sort', filter.sort);

    setCatalogLoading(true);
    api(`/products?${params}`, { signal: controller.signal })
      .then((result) => setCatalog((current) => filter.page > 1 && current ? { ...result, data: [...current.data, ...result.data] } : result))
      .catch((error) => { if (error.name !== 'AbortError') notify(error.message); })
      .finally(() => setCatalogLoading(false));
    return () => controller.abort();
  }, [filter, notify]);

  const cartCount = useCallback((productId, variantId) => (
    cart.items.find((item) => item.productId === productId && item.variantId === variantId)?.qty || 0
  ), [cart.items]);

  async function refreshServerCart(currentToken = token) {
    const result = await api('/cart', { token: currentToken });
    setServerCart(result.data);
    return result.data;
  }

  async function addItem(productInfo, variant, amount = 1) {
    const productId = getId(productInfo);
    const variantId = getId(variant);
    const existing = cart.items.find((item) => item.productId === productId && item.variantId === variantId);
    const nextQty = Math.min((existing?.qty || 0) + amount, Number(variant.maxPerOrder || 10), Number(variant.stock || 0));
    if (nextQty <= 0) {
      notify('This pack is currently out of stock.');
      return;
    }

    try {
      if (token) {
        const result = await api('/cart', { method: 'POST', token, body: { productId, variantId, qty: nextQty } });
        setServerCart(result.data);
      } else {
        setGuestItems((items) => {
          const index = items.findIndex((item) => item.product._id === productId && item.variant._id === variantId);
          if (index < 0) return [...items, { product: productInfo, variant, qty: nextQty }];
          return items.map((item, itemIndex) => itemIndex === index ? { ...item, qty: nextQty } : item);
        });
      }
      notify(`${productInfo.name} added to your basket`);
    } catch (error) {
      notify(error.message);
    }
  }

  async function updateQuantity(item, qty) {
    const nextQty = Math.min(qty, item.maxPerOrder, item.stock);
    try {
      if (token) {
        const result = await api('/cart', { method: 'POST', token, body: { productId: item.productId, variantId: item.variantId, qty: Math.max(0, nextQty) } });
        setServerCart(result.data);
      } else {
        setGuestItems((items) => items
          .map((entry) => entry.product._id === item.productId && entry.variant._id === item.variantId ? { ...entry, qty: nextQty } : entry)
          .filter((entry) => entry.qty > 0));
      }
    } catch (error) {
      notify(error.message);
    }
  }

  async function clearBasket() {
    try {
      if (token) {
        const result = await api('/cart', { method: 'DELETE', token });
        setServerCart(result.data);
      } else {
        setGuestItems([]);
      }
      notify('Basket cleared.');
    } catch (error) {
      notify(error.message);
    }
  }

  async function removeCoupon() {
    try {
      const result = await api('/cart/coupon', { method: 'DELETE', token });
      setServerCart(result.data);
      notify('Coupon removed.');
    } catch (error) {
      notify(error.message);
    }
  }

  async function toggleWishlist(item) {
    if (!token) {
      notify('Sign in to save products to your wishlist.');
      setLoginOpen(true);
      return null;
    }
    try {
      const result = await api(`/user/wishlist/${getId(item)}`, { method: 'POST', token });
      setWishlistIds(new Set((result.data || []).map((id) => getId(id))));
      notify(result.wishlisted ? 'Added to your saved items.' : 'Removed from your saved items.');
      return result;
    } catch (error) {
      notify(error.message);
      return null;
    }
  }

  async function authenticate(customerToken, customer) {
    localStorage.setItem(TOKEN_KEY, customerToken);
    localStorage.setItem(USER_KEY, JSON.stringify(customer));
    skipAuthBootstrap.current = true;
    setToken(customerToken);
    setUser(customer);
    const syncWarnings = [];
    try {
      let result = await api('/cart', { token: customerToken });
      const existing = normalizeCart(result.data);
      for (const item of guestItems) {
        const inServer = existing.items.find((line) => line.productId === item.product._id && line.variantId === item.variant._id);
        const qty = Math.min((inServer?.qty || 0) + item.qty, item.variant.maxPerOrder, item.variant.stock);
        if (qty > 0) {
          result = await api('/cart', { method: 'POST', token: customerToken, body: { productId: item.product._id, variantId: item.variant._id, qty } });
        }
      }
      setServerCart(result.data);
      setGuestItems([]);
    } catch (error) {
      syncWarnings.push(`basket sync failed: ${error.message}`);
    }
    try {
      const saved = await api('/user/wishlist', { token: customerToken });
      setWishlistIds(new Set((saved.data || []).map((item) => getId(item))));
    } catch (error) {
      syncWarnings.push(`saved items could not be loaded: ${error.message}`);
    }
    if (checkoutRequested) {
      setCheckoutRequested(false);
      setCheckoutOpen(true);
    } else if (accountRequested) {
      setAccountRequested(false);
      setAccountOpen(true);
    }
    if (syncWarnings.length) {
      notify(`Signed in, but ${syncWarnings.join('; ')}.`);
    } else if (!checkoutRequested && !accountRequested) {
      notify(`Welcome${customer.name ? `, ${customer.name}` : ''}!`);
    }
  }

  function signOut() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    setToken('');
    setUser(null);
    setServerCart(null);
    setWishlistIds(new Set());
    setAccountOpen(false);
    notify('You have been signed out.');
  }

  function showCategory(category, subCategory) {
    setFilter({ category: getId(category), subCategory: subCategory ? getId(subCategory) : '' });
    setCatalog(null);
    setMobileMenuOpen(false);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function submitSearch(event) {
    event.preventDefault();
    const search = query.trim();
    if (search) {
      setFilter({ search });
      setMobileMenuOpen(false);
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  }

  async function openProduct(item) {
    const requestId = ++productRequest.current;
    setProduct(item);
    setSimilarProducts([]);
    setProductLoading(true);
    const variant = item.variants?.find((entry) => entry.isDefault) || item.variants?.[0];
    setProductVariantId(variant?._id || '');
    try {
      const result = await api(`/products/${getId(item)}`);
      if (requestId === productRequest.current) {
        setProduct(result.data);
        setSimilarProducts(result.similar || []);
        const currentVariant = result.data.variants?.find((entry) => entry.isDefault) || result.data.variants?.[0];
        setProductVariantId(currentVariant?._id || '');
      }
    } catch (error) {
      if (requestId === productRequest.current) notify(error.message);
    } finally {
      if (requestId === productRequest.current) setProductLoading(false);
    }
  }

  function closeProduct() {
    productRequest.current += 1;
    setProduct(null);
    setSimilarProducts([]);
    setProductLoading(false);
  }

  function updateUser(updatedUser) {
    localStorage.setItem(USER_KEY, JSON.stringify(updatedUser));
    setUser(updatedUser);
    notify('Profile saved.');
  }

  function accountDeleted() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    setToken('');
    setUser(null);
    setServerCart(null);
    setWishlistIds(new Set());
    setAccountOpen(false);
    notify('Your account and personal information were deleted.');
  }

  function showAccount(tab = 'orders') {
    setAccountInitialTab(tab);
    if (user) setAccountOpen(true);
    else {
      setAccountRequested(true);
      setLoginOpen(true);
    }
  }

  function beginCheckout() {
    if (!cart.items.length) return;
    setCartOpen(false);
    if (!token) {
      setCheckoutRequested(true);
      setLoginOpen(true);
    } else {
      setCheckoutOpen(true);
    }
  }

  async function applyCoupon(event) {
    event.preventDefault();
    if (!couponCode.trim()) return;
    if (!token) {
      notify('Sign in to apply a coupon to your basket.');
      setLoginOpen(true);
      return;
    }
    setCouponBusy(true);
    try {
      const result = await api('/cart/coupon', { method: 'POST', token, body: { code: couponCode } });
      setServerCart(result.data);
      setCouponCode('');
      notify('Coupon applied to your basket.');
    } catch (error) {
      notify(error.message);
    } finally {
      setCouponBusy(false);
    }
  }

  async function completeOrder(order) {
    setCheckoutOpen(false);
    setProduct(null);
    setCartOpen(false);
    setOrderComplete(order);
    setCouponCode('');
    try {
      await refreshServerCart();
    } catch (error) {
      notify(error.message);
    }
  }

  const categories = home?.categories || [];
  const filteredProducts = catalog?.data || [];
  const activeCategory = categories.find((category) => getId(category) === filter?.category);
  const categoryTitle = filter?.search ? `Results for “${filter.search}”` : filter?.subCategory
    ? activeCategory?.subcategories?.find((item) => getId(item) === filter.subCategory)?.name || activeCategory?.name
    : activeCategory?.name || 'Fresh picks';
  const selectedVariant = product?.variants?.find((item) => item._id === productVariantId) || product?.variants?.[0];

  return (
    <div className="site-shell">
      <div className="announcement"><Sparkles size={14} /> Fresh from the mandi, delivered to your door <span>·</span> <strong>Order direct. Eat seasonal.</strong></div>
      <header className="site-header">
        <div className="header-main page-width">
          <button className="mobile-menu icon-button" type="button" onClick={() => setMobileMenuOpen((open) => !open)} aria-label="Toggle menu"><Menu size={21} /></button>
          <button className="brand-lockup" type="button" onClick={() => { setFilter(null); window.scrollTo({ top: 0, behavior: 'smooth' }); }} aria-label="Mandi At Home home">
            <img src={logo} alt="" /><span><b>mandi<span>at</span>home</b><small>Freshness, delivered.</small></span>
          </button>
          <div className="delivery-location"><span className="location-icon"><MapPin size={17} /></span><span><small>DELIVERING TO</small><strong>Your neighbourhood <ChevronDown size={13} /></strong></span></div>
          <form className="search-box" onSubmit={submitSearch}>
            <Search size={18} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search fruits, vegetables & more" aria-label="Search products" /><kbd>↵</kbd>
          </form>
          <div className="header-actions">
            <button className="account-button" type="button" onClick={() => showAccount('orders')}>
              <UserRound size={19} /><span>{user?.name?.split(' ')[0] || 'Sign in'}</span>
            </button>
            <button className="account-button saved-header-button" type="button" onClick={() => showAccount('saved')} aria-label="Open saved items">
              <Heart size={18} fill={wishlistIds.size ? 'currentColor' : 'none'} /><span>Saved</span>
            </button>
            <button className="basket-button" type="button" onClick={() => setCartOpen(true)} aria-label={`Open basket, ${cart.count} items`}>
              <ShoppingBasket size={20} /><span>Basket</span>{cart.count > 0 && <b>{cart.count}</b>}
            </button>
          </div>
        </div>
        <div className={`category-nav-wrap ${mobileMenuOpen ? 'mobile-open' : ''}`}>
          <nav className="category-nav page-width" aria-label="Product categories">
            <button className={!filter ? 'nav-active' : ''} type="button" onClick={() => { setFilter(null); setMobileMenuOpen(false); }}>Shop all</button>
            {categories.map((category) => <button key={category._id} className={filter?.category === category._id ? 'nav-active' : ''} type="button" onClick={() => showCategory(category)}>{category.emoji || '🥬'} {category.name}</button>)}
            <span className="nav-promise"><Truck size={15} /> Freshness at your doorstep</span>
          </nav>
        </div>
      </header>

      <main>
        {homeError && <div className="page-width error-banner"><span>{homeError}</span><button type="button" onClick={loadHome}>Try again</button></div>}
        {loading && !home ? <div className="page-width loading-state"><span className="loader" /> Loading your local mandi…</div> : null}
        {home && !filter && (
          <>
            <section className="hero page-width">
              <div className="hero-copy">
                <span className="hero-label"><span /> STRAIGHT FROM THE MANDI</span>
                <h1>Good food.<br /><em>Good mood.</em></h1>
                <p>Hand-picked seasonal produce and everyday essentials, brought fresh to your home.</p>
                <button className="button button-primary" type="button" onClick={() => document.getElementById('shop-categories')?.scrollIntoView({ behavior: 'smooth' })}>Explore fresh picks <ArrowRight size={17} /></button>
                <div className="hero-footnote"><ShieldCheck size={15} /> Quality you can taste, prices you’ll love.</div>
              </div>
              <div className="hero-visual">
                <div className="hero-sun" />
                <div className="hero-blob" />
                <img src={imageUrl(home.banners?.[0]?.image) || imageUrl(home.featured?.[0]?.images?.[0])} alt="Fresh produce from Mandi At Home" onError={(event) => { event.currentTarget.style.display = 'none'; }} />
                <span className="floating-sticker sticker-top"><Leaf size={15} /> 100% fresh</span>
                <span className="floating-sticker sticker-bottom"><Star size={14} fill="currentColor" /> Handpicked daily</span>
                <span className="hero-decoration decor-one">✳</span><span className="hero-decoration decor-two">✦</span>
              </div>
              <div className="hero-pagination"><span className="current">01</span><span className="pagination-line" /><span>{String(home.banners?.length || 1).padStart(2, '0')}</span><ArrowDown size={14} /></div>
            </section>

            {home.banners?.length > 0 && <section className="promo-strip page-width">
              {home.banners.slice(0, 3).map((banner, index) => <button className={`promo-card promo-${index + 1}`} type="button" key={banner._id} onClick={() => banner.category && showCategory(banner.category)}>
                <span className="promo-copy"><small>{banner.subtitle || 'A little goodness'}</small><strong>{banner.title}</strong><span>Shop now <ArrowRight size={13} /></span></span>
                {banner.emoji && <span className="promo-emoji">{banner.emoji}</span>}
              </button>)}
            </section>}

            <section className="category-section page-width" id="shop-categories">
              <div className="section-heading category-heading"><div><span className="eyebrow">A LITTLE BIT OF EVERYTHING</span><h2>Shop by category</h2></div><p>Good things, grouped just for you.</p></div>
              <div className="category-grid">
                {categories.map((category, index) => <button className={`category-tile category-tone-${index % 6}`} type="button" key={category._id} onClick={() => showCategory(category)}>
                  <span className="category-art">{category.image ? <img src={imageUrl(category.image)} alt="" /> : <span>{category.emoji || '🥬'}</span>}<i><ArrowRight size={15} /></i></span>
                  <strong>{category.name}</strong><small>{category.subcategories?.length || 0} collections</small>
                </button>)}
              </div>
            </section>

            <section className="promise-band page-width">
              <div><span className="promise-icon"><Truck size={20} /></span><span><strong>Right to your doorstep</strong><small>Fresh, speedy delivery</small></span></div>
              <div><span className="promise-icon"><Leaf size={20} /></span><span><strong>Picked with care</strong><small>Quality you can trust</small></span></div>
              <div><span className="promise-icon"><BadgeCheck size={20} /></span><span><strong>Fair mandi prices</strong><small>No middlemen, no fuss</small></span></div>
              <div><span className="promise-icon"><Clock3 size={20} /></span><span><strong>Easy delivery slots</strong><small>At a time that suits you</small></span></div>
            </section>

            <div className="page-width home-rails">
              <ProductRail title="Fresh picks for you" eyebrow="THE GOOD STUFF" products={home.featured} onOpen={openProduct} onAdd={addItem} cartCount={cartCount} wishlistIds={wishlistIds} onToggleWishlist={toggleWishlist} action={() => { setFilter({ sort: 'popular' }); window.scrollTo({ top: 0, behavior: 'smooth' }); }} />
              <ProductRail title="The crowd favourites" eyebrow="LOVED BY YOUR NEIGHBOURS" products={home.bestSellers} onOpen={openProduct} onAdd={addItem} cartCount={cartCount} wishlistIds={wishlistIds} onToggleWishlist={toggleWishlist} />
              {home.sections?.map((section) => <ProductRail key={section.category._id} title={section.category.name} eyebrow={section.category.emoji || 'FRESH EVERY DAY'} products={section.products} onOpen={openProduct} onAdd={addItem} cartCount={cartCount} wishlistIds={wishlistIds} onToggleWishlist={toggleWishlist} action={() => showCategory(section.category)} />)}
              <ProductRail title="Goodness, naturally" eyebrow="ORGANIC & LOVELY" products={home.organic} onOpen={openProduct} onAdd={addItem} cartCount={cartCount} wishlistIds={wishlistIds} onToggleWishlist={toggleWishlist} />
            </div>
          </>
        )}

        {filter && (
          <section className="catalog-page page-width">
            <div className="breadcrumbs"><button type="button" onClick={() => setFilter(null)}>Home</button><ChevronRight size={13} /> <span>{categoryTitle}</span></div>
            <div className="catalog-heading"><div><span className="eyebrow">{filter.search ? 'YOUR SEARCH' : 'FRESH FROM THE MANDI'}</span><h1>{categoryTitle}</h1><p>{catalog?.total ?? '…'} fresh finds, selected for you.</p></div>
              <label className="sort-control"><span>Sort by</span><select value={filter.sort || ''} onChange={(event) => setFilter((current) => ({ ...current, sort: event.target.value, page: 1 }))}><option value="">Recommended</option><option value="popular">Most popular</option><option value="price_asc">Price: low to high</option><option value="price_desc">Price: high to low</option><option value="new">Just arrived</option></select><ChevronDown size={14} /></label>
            </div>
            <div className="catalog-layout">
              <aside className="catalog-sidebar"><h3>Categories</h3><button className={!filter.category ? 'selected' : ''} type="button" onClick={() => setFilter({ search: filter.search || '' })}>All products</button>
                {categories.map((category) => <div key={category._id}><button className={filter.category === category._id && !filter.subCategory ? 'selected' : ''} type="button" onClick={() => showCategory(category)}>{category.emoji || '🥬'} {category.name}</button>
                  {filter.category === category._id && category.subcategories?.map((sub) => <button className={`subcategory-link ${filter.subCategory === sub._id ? 'selected' : ''}`} key={sub._id} type="button" onClick={() => showCategory(category, sub)}>{sub.name}</button>)}
                </div>)}
              </aside>
              <div className="catalog-results">
                {catalogLoading && !catalog ? <div className="loading-state"><span className="loader" /> Finding your favourites…</div>
                  : filteredProducts.length ? <div className="product-grid">{filteredProducts.map((item) => <ProductCard key={item._id} product={item} onOpen={openProduct} onAdd={addItem} cartCount={cartCount} wishlistIds={wishlistIds} onToggleWishlist={toggleWishlist} />)}</div>
                    : !catalogLoading && <div className="empty-state"><span>🥕</span><h3>Nothing in the basket… yet</h3><p>Try a different search or browse another category.</p><button className="button button-primary" type="button" onClick={() => setFilter(null)}>Back to the market</button></div>}
                {catalog?.hasMore && <button className="button button-light load-more" type="button" disabled={catalogLoading} onClick={() => setFilter((current) => ({ ...current, page: (current.page || 1) + 1 }))}>{catalogLoading ? 'Loading…' : 'Show me more'} <ArrowDown size={15} /></button>}
              </div>
            </div>
          </section>
        )}
      </main>

      <footer className="site-footer">
        <div className="footer-main page-width">
          <div className="footer-brand"><img src={logo} alt="" /><div><b>mandi<span>at</span>home</b><p>Bringing the mandi a little closer to home.</p></div></div>
          <div><span className="eyebrow">A FRESHER WAY TO SHOP</span><p>Seasonal produce. Honest prices.<br />A little more joy in every meal.</p></div>
          <div className="footer-support"><span className="eyebrow">NEED A HAND?</span><p>{settings.supportPhone || 'We are here to help'}</p><small>{settings.supportEmail || 'Your neighbourhood mandi team'}</small></div>
        </div>
        <div className="footer-bottom page-width"><span>© {new Date().getFullYear()} Mandi At Home</span><span>Made for good food & good days <span className="footer-heart">♥</span></span></div>
      </footer>

      {cart.count > 0 && !cartOpen && !checkoutOpen && <button className="floating-cart" type="button" onClick={() => setCartOpen(true)}><span className="floating-cart-icon"><ShoppingBag size={19} /><b>{cart.count}</b></span><span><strong>View basket</strong><small>{cart.count} items</small></span><strong>{money(cart.grandTotal)}</strong><ArrowRight size={17} /></button>}

      {cartOpen && <div className="overlay drawer-overlay" onMouseDown={(event) => event.target === event.currentTarget && setCartOpen(false)}>
        <aside className="cart-drawer" role="dialog" aria-modal="true" aria-label="Your basket">
          <div className="drawer-heading"><div><span className="eyebrow">GOOD CHOICES</span><h2>Your basket <span>({cart.count})</span></h2>{cart.count > 0 && <button className="text-button clear-basket" type="button" onClick={clearBasket}>Clear basket</button>}</div><button className="icon-button" type="button" onClick={() => setCartOpen(false)} aria-label="Close basket"><X size={20} /></button></div>
          {cart.items.length === 0 ? <div className="empty-state drawer-empty"><span>🧺</span><h3>Your basket is taking a break</h3><p>Fill it with something fresh and lovely.</p><button className="button button-primary" type="button" onClick={() => setCartOpen(false)}>Start shopping</button></div> : <>
            {cart.amountForFreeDelivery > 0 && <div className="delivery-progress"><div><Truck size={16} /><span>Add <strong>{money(cart.amountForFreeDelivery)}</strong> for free delivery</span></div><div className="progress-track"><span style={{ width: `${Math.min(100, (cart.itemsTotal / (cart.freeDeliveryAbove || 299)) * 100)}%` }} /></div></div>}
            {cart.amountForFreeDelivery === 0 && cart.freeDeliveryAbove > 0 && <div className="free-delivery-note"><Check size={15} /> You’ve unlocked free delivery!</div>}
            {cart.coupon && <div className="applied-coupon"><span><BadgeCheck size={15} /> {cart.coupon} applied</span><button type="button" onClick={removeCoupon}>Remove</button></div>}
            <div className="drawer-items">{cart.items.map((item) => <div className="drawer-item" key={`${item.productId}-${item.variantId}`}>
              <ProductImage product={{ image: item.image, emoji: item.emoji }} />
              <div className="drawer-item-info"><strong>{item.name}</strong><small>{item.variantLabel}</small><b>{money(item.price)}</b></div>
              <div className="quantity-control"><button type="button" onClick={() => updateQuantity(item, item.qty - 1)} aria-label={`Remove one ${item.name}`}><Minus size={13} /></button><span>{item.qty}</span><button type="button" disabled={item.qty >= item.maxPerOrder || item.qty >= item.stock} onClick={() => updateQuantity(item, item.qty + 1)} aria-label={`Add one ${item.name}`}><Plus size={13} /></button></div>
            </div>)}</div>
            <form className="coupon-form" onSubmit={applyCoupon}><input value={couponCode} onChange={(event) => setCouponCode(event.target.value.toUpperCase())} placeholder="Have a coupon code?" aria-label="Coupon code" /><button type="submit" disabled={couponBusy}>{couponBusy ? 'Applying…' : 'Apply'}</button></form>
            {coupons.length > 0 && <div className="coupon-suggestions"><span>AVAILABLE OFFERS</span>{coupons.slice(0, 3).map((coupon) => <button key={coupon.code} type="button" onClick={() => setCouponCode(coupon.code)}><strong>{coupon.code}</strong><small>{coupon.description || `${coupon.type === 'percent' ? `${coupon.value}% off` : `${money(coupon.value)} off`} · min. ${money(coupon.minOrder)}`}</small></button>)}</div>}
            <PriceBreakdown cart={cart} />
            {cart.itemsTotal < cart.minOrderAmount && <p className="minimum-note">Add {money(cart.minOrderAmount - cart.itemsTotal)} more to meet the minimum order.</p>}
            <button className="button button-primary button-full checkout-button" type="button" disabled={cart.itemsTotal < cart.minOrderAmount} onClick={beginCheckout}>Continue to checkout <ArrowRight size={16} /></button>
            <p className="secure-note"><ShieldCheck size={14} /> Freshness checked before every delivery.</p>
          </>}
        </aside>
      </div>}

      {product && selectedVariant && <Modal onClose={closeProduct} wide label={`${product.name} details`}>
        <div className="detail-modal-content"><div className="product-detail">
          <div className="detail-image-wrap"><ProductImage product={product} className="detail-image" />{product.isOrganic && <span className="organic-tag"><Leaf size={12} /> Organic</span>}</div>
          <div className="detail-content"><span className="eyebrow">{product.category?.name || 'FRESH FROM THE MANDI'}</span><div className="detail-title-row"><h2>{product.name}</h2><button className={`wishlist-toggle detail-wishlist ${wishlistIds.has(product._id) ? 'is-saved' : ''}`} type="button" aria-label={`${wishlistIds.has(product._id) ? 'Remove' : 'Add'} ${product.name} ${wishlistIds.has(product._id) ? 'from' : 'to'} wishlist`} onClick={() => toggleWishlist(product)}><Heart size={18} fill={wishlistIds.has(product._id) ? 'currentColor' : 'none'} /></button></div>{product.hindiName && <p className="hindi-name detail-hindi">{product.hindiName}</p>}
            <div className="rating detail-rating"><Star size={14} fill="currentColor" /> {Number(product.rating || 4.5).toFixed(1)} <span>({product.ratingCount || 0} happy shoppers)</span></div>
            <p className="detail-description">{product.description || 'Freshly picked and carefully packed to bring you the best of the season.'}</p>
            <label className="field-label">Choose your pack</label>
            <div className="variant-options">{product.variants.map((variant) => <button className={`variant-option ${variant._id === selectedVariant._id ? 'selected' : ''}`} key={variant._id} type="button" onClick={() => setProductVariantId(variant._id)}><span>{variant.label}</span><strong>{money(variant.price)}</strong>{variant.mrp > variant.price && <del>{money(variant.mrp)}</del>}</button>)}</div>
            <div className="detail-price-row"><span><strong>{money(selectedVariant.price)}</strong> <del>{selectedVariant.mrp > selectedVariant.price ? money(selectedVariant.mrp) : ''}</del><small>Inclusive of all taxes</small></span><button className="button button-primary" type="button" disabled={!selectedVariant.stock} onClick={() => addItem(product, selectedVariant)}>{selectedVariant.stock ? <><ShoppingBag size={16} /> Add to basket</> : 'Out of stock'}</button></div>
            <div className="detail-note"><Truck size={16} /><span>Delivered fresh, straight to your doorstep.</span></div>
          </div>
        </div>{productLoading && <p className="muted detail-loading">Loading product details…</p>}{similarProducts.length > 0 && <ProductRail title="Goes well with" eyebrow="MORE TO LOVE" products={similarProducts} onOpen={openProduct} onAdd={addItem} cartCount={cartCount} wishlistIds={wishlistIds} onToggleWishlist={toggleWishlist} />}</div>
      </Modal>}

      {loginOpen && <AuthModal onClose={() => { setLoginOpen(false); setCheckoutRequested(false); setAccountRequested(false); }} onAuthenticated={authenticate} />}
      {accountOpen && user && <AccountModal initialTab={accountInitialTab} user={user} token={token} onClose={() => setAccountOpen(false)} onLogout={signOut} onUserUpdated={updateUser} onAccountDeleted={accountDeleted} onOpenProduct={openProduct} onAddItem={addItem} cartCount={cartCount} wishlistIds={wishlistIds} onToggleWishlist={toggleWishlist} />}
      {checkoutOpen && token && <CheckoutModal cart={cart} settings={settings} token={token} onClose={() => setCheckoutOpen(false)} onOrdered={completeOrder} />}
      {orderComplete && <Modal onClose={() => setOrderComplete(null)} label="Order confirmed">
        <div className="success-modal"><span className="success-mark"><Check size={31} /></span><span className="eyebrow">THAT'S A WRAP</span><h2>Your order is in!</h2><p>We’re getting your fresh picks ready. You can follow everything in your account.</p><div className="success-order"><span>Order number</span><strong>#{orderComplete.orderNo}</strong><span>Amount paid</span><strong>{money(orderComplete.grandTotal)}</strong></div><button className="button button-primary button-full" type="button" onClick={() => { setOrderComplete(null); showAccount('orders'); }}>Track your order <ArrowRight size={16} /></button></div>
      </Modal>}

      {notice && <div className="toast-message" role="status">{notice}</div>}
    </div>
  );
}

export default App;
