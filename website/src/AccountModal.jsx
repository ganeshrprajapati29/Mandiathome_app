import { useEffect, useState } from 'react';
import { ArrowRight, ChevronLeft, ChevronRight, Heart, LogOut, MapPin, PackageCheck, Pencil, Plus, Trash2, UserRound, X } from 'lucide-react';
import { api, imageUrl } from './api.js';

const money = (value) => `₹${Number(value || 0).toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;
const tabs = [['orders', 'Orders'], ['addresses', 'Addresses'], ['saved', 'Saved items'], ['profile', 'Profile']];
const blankAddress = { label: 'Home', name: '', phone: '', line1: '', line2: '', landmark: '', city: '', state: '', pincode: '', isDefault: false };

function AddressForm({ value, busy, onSave, onCancel, onChange }) {
  return (
    <form className="address-form" onSubmit={(event) => { event.preventDefault(); onSave(value); }}>
      <div className="field-grid">
        <label className="field-label">Address type<select className="text-input" name="label" value={value.label} onChange={onChange}><option>Home</option><option>Work</option><option>Other</option></select></label>
        <label className="field-label">Full name<input className="text-input" name="name" required value={value.name} onChange={onChange} /></label>
        <label className="field-label">Phone number<input className="text-input" name="phone" type="tel" inputMode="numeric" required minLength="10" maxLength="10" value={value.phone} onChange={onChange} /></label>
        <label className="field-label field-span">House / street / area<input className="text-input" name="line1" required value={value.line1} onChange={onChange} /></label>
        <label className="field-label field-span">Apartment / floor <span className="optional">(optional)</span><input className="text-input" name="line2" value={value.line2} onChange={onChange} /></label>
        <label className="field-label field-span">Landmark <span className="optional">(optional)</span><input className="text-input" name="landmark" value={value.landmark} onChange={onChange} /></label>
        <label className="field-label">City<input className="text-input" name="city" required value={value.city} onChange={onChange} /></label>
        <label className="field-label">State<input className="text-input" name="state" value={value.state} onChange={onChange} /></label>
        <label className="field-label">PIN code<input className="text-input" name="pincode" inputMode="numeric" pattern="[0-9]{6}" required minLength="6" maxLength="6" value={value.pincode} onChange={onChange} /></label>
      </div>
      <label className="default-address-check"><input type="checkbox" name="isDefault" checked={value.isDefault} onChange={onChange} /> Make this my default address</label>
      <div className="address-actions"><button className="button button-light" type="button" onClick={onCancel}>Cancel</button><button className="button button-primary" type="submit" disabled={busy}>{busy ? 'Saving…' : 'Save address'}</button></div>
    </form>
  );
}

export default function AccountModal({
  initialTab = 'orders',
  user,
  token,
  onClose,
  onLogout,
  onUserUpdated,
  onAccountDeleted,
  onOpenProduct,
  onAddItem,
  cartCount,
  wishlistIds,
  onToggleWishlist,
}) {
  const [tab, setTab] = useState(initialTab);
  const [orders, setOrders] = useState([]);
  const [addresses, setAddresses] = useState([]);
  const [savedProducts, setSavedProducts] = useState([]);
  const [profile, setProfile] = useState({ name: user?.name || '', email: user?.email || '' });
  const [addressForm, setAddressForm] = useState(null);
  const [editingAddress, setEditingAddress] = useState('');
  const [selectedOrder, setSelectedOrder] = useState(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    Promise.all([
      api('/orders?limit=20', { token }),
      api('/user/addresses', { token }),
      api('/user/wishlist', { token }),
    ])
      .then(([orderResult, addressResult, wishlistResult]) => {
        if (!active) return;
        setOrders(orderResult.data || []);
        setAddresses(addressResult.data || []);
        setSavedProducts(wishlistResult.data || []);
      })
      .catch((requestError) => { if (active) setError(requestError.message); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [token]);

  useEffect(() => setProfile({ name: user?.name || '', email: user?.email || '' }), [user]);

  function changeAddress(event) {
    const { name, value, checked, type } = event.target;
    const next = type === 'checkbox' ? checked : name === 'phone' || name === 'pincode' ? value.replace(/\D/g, '').slice(0, name === 'phone' ? 10 : 6) : value;
    setAddressForm((current) => ({ ...current, [name]: next }));
  }

  async function saveAddress(value) {
    setBusy(true);
    setError('');
    const body = { ...blankAddress, ...value, isDefault: value.isDefault || addresses.length === 0 };
    try {
      const path = editingAddress ? `/user/addresses/${editingAddress}` : '/user/addresses';
      const result = await api(path, { method: editingAddress ? 'PUT' : 'POST', token, body });
      setAddresses(result.data || []);
      setAddressForm(null);
      setEditingAddress('');
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setBusy(false);
    }
  }

  async function updateAddress(address, changes) {
    setBusy(true);
    setError('');
    try {
      const body = { ...blankAddress, ...address, ...changes };
      const result = await api(`/user/addresses/${address._id}`, { method: 'PUT', token, body });
      setAddresses(result.data || []);
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setBusy(false);
    }
  }

  async function removeAddress(address) {
    if (!window.confirm(`Remove the ${address.label.toLowerCase()} address?`)) return;
    setBusy(true);
    setError('');
    try {
      const result = await api(`/user/addresses/${address._id}`, { method: 'DELETE', token });
      setAddresses(result.data || []);
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setBusy(false);
    }
  }

  async function saveProfile(event) {
    event.preventDefault();
    setBusy(true);
    setError('');
    try {
      const result = await api('/auth/me', { method: 'PUT', token, body: profile });
      onUserUpdated(result.user);
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setBusy(false);
    }
  }

  async function deleteAccount() {
    if (!window.confirm('Delete your account and personal information? This cannot be undone.')) return;
    setBusy(true);
    setError('');
    try {
      await api('/auth/me', { method: 'DELETE', token });
      onAccountDeleted();
    } catch (requestError) {
      setError(requestError.message);
      setBusy(false);
    }
  }

  async function openOrder(orderId) {
    setBusy(true);
    setError('');
    try {
      const result = await api(`/orders/${orderId}`, { token });
      setSelectedOrder(result.data);
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setBusy(false);
    }
  }

  async function cancelOrder() {
    if (!selectedOrder || !window.confirm(`Cancel order #${selectedOrder.orderNo}?`)) return;
    setBusy(true);
    setError('');
    try {
      const result = await api(`/orders/${selectedOrder._id}/cancel`, { method: 'POST', token, body: { reason: 'Cancelled from customer website' } });
      setSelectedOrder(result.data);
      const refreshed = await api('/orders?limit=20', { token });
      setOrders(refreshed.data || []);
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setBusy(false);
    }
  }

  async function removeSavedProduct(product) {
    setError('');
    try {
      const result = await onToggleWishlist(product);
      if (result?.wishlisted === false) setSavedProducts((items) => items.filter((item) => item._id !== product._id));
    } catch (requestError) {
      setError(requestError.message);
    }
  }

  return (
    <div className="overlay" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section className="modal modal-wide account-modal" role="dialog" aria-modal="true" aria-label="Your account">
        <button className="icon-button modal-close" type="button" onClick={onClose} aria-label="Close"><X size={20} /></button>
        <div className="account-heading">
          <div className="avatar"><UserRound size={23} /></div>
          <div><span className="eyebrow">YOUR ACCOUNT</span><h2>{user?.name || 'Welcome back'}</h2><p>{user?.phone ? `+91 ${user.phone}` : user?.email}</p></div>
          <button className="button button-light logout-button" type="button" onClick={onLogout}><LogOut size={15} /> Sign out</button>
        </div>
        <nav className="account-tabs" aria-label="Account sections">
          {tabs.map(([value, label]) => <button key={value} className={tab === value ? 'active' : ''} type="button" onClick={() => { setTab(value); setError(''); setSelectedOrder(null); }}>{label}{value === 'saved' && savedProducts.length ? ` (${savedProducts.length})` : ''}</button>)}
        </nav>
        {error && <p className="form-error account-error" role="alert">{error}</p>}
        {loading ? <p className="muted account-loading">Loading your account…</p> : <>
          {tab === 'orders' && <div className="account-section">
            {selectedOrder ? <>
              <button className="text-button" type="button" onClick={() => setSelectedOrder(null)}><ChevronLeft size={14} /> All orders</button>
              <div className="order-detail-heading"><div><span className="eyebrow">ORDER DETAILS</span><h3>#{selectedOrder.orderNo}</h3></div><span className={`order-status status-${selectedOrder.status}`}>{String(selectedOrder.status).replaceAll('_', ' ')}</span></div>
              <p className="order-detail-meta">Placed {new Date(selectedOrder.createdAt).toLocaleString('en-IN')} · {selectedOrder.paymentMethod === 'ONLINE' ? 'Online payment' : 'Cash on delivery'} · {String(selectedOrder.paymentStatus).replaceAll('_', ' ')}</p>
              <div className="order-detail-items">{selectedOrder.items?.map((item, index) => <div className="order-detail-item" key={`${item.variantId}-${index}`}><span>{item.emoji || '🥬'}</span><div><strong>{item.name}</strong><small>{item.variantLabel} × {item.qty}</small></div><b>{money(item.total)}</b></div>)}</div>
              {selectedOrder.address && <div className="order-address"><strong>Delivery address</strong><span>{selectedOrder.address.name} · +91 {selectedOrder.address.phone}</span><small>{[selectedOrder.address.line1, selectedOrder.address.line2, selectedOrder.address.city, selectedOrder.address.pincode].filter(Boolean).join(', ')}</small></div>}
              <div className="price-breakdown">
                <div><span>Items total</span><span>{money(selectedOrder.itemsTotal)}</span></div>
                {selectedOrder.savings > 0 && <div className="saving-row"><span>You saved</span><span>−{money(selectedOrder.savings)}</span></div>}
                {selectedOrder.couponDiscount > 0 && <div className="saving-row"><span>Coupon</span><span>−{money(selectedOrder.couponDiscount)}</span></div>}
                <div><span>Delivery</span><span>{money(selectedOrder.deliveryFee)}</span></div>
                <div className="grand-total"><strong>Total</strong><strong>{money(selectedOrder.grandTotal)}</strong></div>
              </div>
              {selectedOrder.statusHistory?.length > 0 && <div className="order-history"><strong>Order updates</strong>{selectedOrder.statusHistory.map((event, index) => <p key={`${event.status}-${index}`}><span>{String(event.status).replaceAll('_', ' ')}</span>{event.note && <small>{event.note}</small>}</p>)}</div>}
              {['placed', 'confirmed'].includes(selectedOrder.status) && <button className="button button-light cancel-order-button" type="button" disabled={busy} onClick={cancelOrder}>{busy ? 'Updating…' : 'Cancel order'}</button>}
            </> : <>
              <h3>Recent orders</h3>
              {orders.length === 0 ? <div className="empty-orders"><PackageCheck size={22} /><p>Your first order is waiting to happen.</p></div>
                : orders.map((order) => <button className="order-row order-row-button" key={order._id} type="button" onClick={() => openOrder(order._id)}>
                  <span><strong>#{order.orderNo}</strong><small>{new Date(order.createdAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })}</small></span>
                  <span><strong>{money(order.grandTotal)}</strong><small>{order.items?.length || 0} items · {order.paymentMethod === 'ONLINE' ? 'Online' : 'Cash on delivery'}</small></span>
                  <span className={`order-status status-${order.status}`}>{String(order.status).replaceAll('_', ' ')}</span><ChevronRight size={16} />
                </button>)}
            </>}
          </div>}

          {tab === 'addresses' && <div className="account-section">
            <div className="account-section-heading"><h3>Your delivery addresses</h3>{!addressForm && <button className="text-button" type="button" onClick={() => { setEditingAddress(''); setAddressForm({ ...blankAddress, isDefault: addresses.length === 0 }); }}><Plus size={14} /> Add address</button>}</div>
            {addressForm ? <AddressForm value={addressForm} busy={busy} onSave={saveAddress} onCancel={() => { setAddressForm(null); setEditingAddress(''); }} onChange={changeAddress} />
              : addresses.length === 0 ? <div className="empty-orders"><MapPin size={22} /><p>Add an address for a smoother checkout.</p></div>
                : <div className="saved-addresses">{addresses.map((address) => <div className="saved-address" key={address._id}>
                  <div className="saved-address-content"><strong>{address.label} · {address.name} {address.isDefault && <span className="default-badge">DEFAULT</span>}</strong><span>{[address.line1, address.line2, address.landmark, `${address.city}, ${address.state || ''} ${address.pincode}`].filter(Boolean).join(', ')}</span><small>+91 {address.phone}</small></div>
                  <div className="saved-address-actions">{!address.isDefault && <button className="text-button" type="button" disabled={busy} onClick={() => updateAddress(address, { isDefault: true })}>Make default</button>}<button className="icon-button" type="button" aria-label={`Edit ${address.label} address`} onClick={() => { setEditingAddress(address._id); setAddressForm({ ...blankAddress, ...address }); }}><Pencil size={14} /></button><button className="icon-button address-delete" type="button" disabled={busy} aria-label={`Delete ${address.label} address`} onClick={() => removeAddress(address)}><Trash2 size={14} /></button></div>
                </div>)}</div>}
          </div>}

          {tab === 'saved' && <div className="account-section"><h3>Things you’ve saved</h3>
            {savedProducts.length === 0 ? <div className="empty-orders"><Heart size={22} /><p>Tap the heart on a product to save it here.</p></div>
              : <div className="saved-products">{savedProducts.map((product) => {
                const variant = product.variants?.find((item) => item.isDefault) || product.variants?.[0];
                return <article className="saved-product" key={product._id}>
                  <button className="saved-product-open" type="button" onClick={() => onOpenProduct(product)}>{product.images?.[0] ? <img src={imageUrl(product.images[0])} alt={product.name} /> : <span>{product.emoji || '🥬'}</span>}</button>
                  <div><strong>{product.name}</strong><small>{variant?.label || ''} · {money(variant?.price)}</small><button className="text-button" type="button" disabled={!variant} onClick={() => onAddItem(product, variant)}><Plus size={13} /> Add to basket</button></div>
                  <button className={`wishlist-toggle is-saved`} type="button" aria-label={`Remove ${product.name} from wishlist`} onClick={() => removeSavedProduct(product)}><Heart size={16} fill="currentColor" /></button>
                </article>;
              })}</div>}
          </div>}

          {tab === 'profile' && <div className="account-section">
            <h3>Profile details</h3>
            <form className="profile-form" onSubmit={saveProfile}>
              <label className="field-label">Name<input className="text-input" value={profile.name} onChange={(event) => setProfile((value) => ({ ...value, name: event.target.value }))} /></label>
              <label className="field-label">Email address<input className="text-input" type="email" value={profile.email || ''} onChange={(event) => setProfile((value) => ({ ...value, email: event.target.value }))} /></label>
              <label className="field-label">Mobile number<input className="text-input" value={user?.phone ? `+91 ${user.phone}` : ''} disabled /></label>
              <button className="button button-primary" type="submit" disabled={busy}>{busy ? 'Saving…' : 'Save profile'}</button>
            </form>
            <div className="delete-account-box"><div><strong>Delete account</strong><small>Permanently remove your personal information.</small></div><button className="button button-light" type="button" disabled={busy} onClick={deleteAccount}>Delete</button></div>
          </div>}
        </>}
      </section>
    </div>
  );
}
