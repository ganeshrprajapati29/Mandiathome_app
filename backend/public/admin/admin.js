/* Mandi At Home – Admin panel (vanilla JS, served by the API at /admin) */
const API = location.origin + '/api';
let TOKEN = localStorage.getItem('mah_admin_token') || '';
let CATS = [];
const $ = (s, el = document) => el.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => '₹' + Number(n || 0).toLocaleString('en-IN');
const STATUSES = ['placed', 'confirmed', 'packed', 'out_for_delivery', 'delivered', 'cancelled'];
const UNITS = ['kg', 'g', 'pc', 'dozen', 'bunch', 'l', 'ml', 'pack', 'box'];
const imgUrl = (u) => (!u ? '' : u.startsWith('http') ? u : location.origin + u);

function toast(msg) { const t = $('#toast'); t.textContent = msg; t.classList.add('show'); setTimeout(() => t.classList.remove('show'), 2500); }

async function api(path, opts = {}) {
  const res = await fetch(API + path, {
    ...opts,
    headers: { ...(opts.body instanceof FormData ? {} : { 'Content-Type': 'application/json' }), Authorization: 'Bearer ' + TOKEN },
    body: opts.body instanceof FormData ? opts.body : opts.body ? JSON.stringify(opts.body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (res.status === 401) { logout(); throw new Error('Session expired'); }
  if (!res.ok) throw new Error(data.message || 'Request failed');
  return data;
}
const safe = (fn) => async (...a) => { try { await fn(...a); } catch (e) { toast('⚠️ ' + e.message); } };

// ---------- auth ----------
function logout() { TOKEN = ''; localStorage.removeItem('mah_admin_token'); $('#shell').classList.add('hidden'); $('#login').classList.remove('hidden'); }
$('#loginForm').onsubmit = async (e) => {
  e.preventDefault();
  const f = new FormData(e.target);
  try {
    const r = await fetch(API + '/auth/admin-login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(Object.fromEntries(f)) });
    const d = await r.json();
    if (!r.ok) throw new Error(d.message);
    TOKEN = d.token; localStorage.setItem('mah_admin_token', TOKEN); boot();
  } catch (err) { $('#loginErr').textContent = err.message; }
};
$('#logout').onclick = logout;
$('#menuBtn').onclick = () => $('#side').classList.toggle('open');

// ---------- modal ----------
function openModal(html) { $('#modalBody').innerHTML = html; $('#modal').classList.remove('hidden'); }
function closeModal() { $('#modal').classList.add('hidden'); }
$('#modal').onclick = (e) => { if (e.target.id === 'modal') closeModal(); };

async function uploadImage(input) {
  const fd = new FormData(); fd.append('image', input.files[0]);
  const r = await api('/admin/upload', { method: 'POST', body: fd });
  return r.url;
}

// ---------- router ----------
const pages = {};
function go(page) {
  document.querySelectorAll('#nav a').forEach((a) => a.classList.toggle('active', a.dataset.page === page));
  $('#pageTitle').textContent = $(`#nav a[data-page="${page}"]`).textContent.replace(/^\S+\s/, '');
  $('#side').classList.remove('open');
  $('#page').innerHTML = '<p class="muted">Loading…</p>';
  location.hash = page;
  safe(pages[page])();
}
document.querySelectorAll('#nav a').forEach((a) => (a.onclick = () => go(a.dataset.page)));

async function loadCats() { CATS = (await api('/categories?all=true')).data; }
const catOptions = (sel, parentOnly, parentId) => CATS
  .filter((c) => (parentOnly ? !c.parent : parentId ? c.parent && (c.parent._id || c.parent) === parentId : true))
  .map((c) => `<option value="${c._id}" ${sel === c._id ? 'selected' : ''}>${esc(c.emoji || '')} ${esc(c.name)}</option>`).join('');

// ---------- dashboard ----------
pages.dashboard = async () => {
  const d = (await api('/admin/stats')).data;
  $('#page').innerHTML = `
  <div class="grid stats">
    ${[['Today Orders', d.todayOrders], ['Today Revenue', money(d.todayRevenue)], ['Total Orders', d.orders], ['Total Revenue', money(d.revenue)], ['Customers', d.users], ['Products', d.products]]
      .map(([k, v]) => `<div class="card stat"><span>${k}</span><b>${v}</b></div>`).join('')}
  </div>
  <div class="grid" style="grid-template-columns:repeat(auto-fit,minmax(320px,1fr));margin-top:14px">
    <div class="card"><h3>Orders by status</h3>${STATUSES.map((s) => `<p><span class="pill ${s}">${s.replace(/_/g, ' ')}</span> <b style="float:right">${d.byStatus[s] || 0}</b></p>`).join('')}</div>
    <div class="card"><h3>⚠️ Low stock</h3>${d.lowStock.length ? d.lowStock.map((p) => `<p>${esc(p.emoji || '')} ${esc(p.name)} <small class="muted">${p.variants.filter((v) => v.stock <= 5).map((v) => `${esc(v.label)}: ${v.stock}`).join(', ')}</small></p>`).join('') : '<p class="muted">All good 👍</p>'}</div>
  </div>
  <div class="card" style="margin-top:14px"><h3>Recent orders</h3><div class="tbl">${orderTable(d.recent)}</div></div>`;
};

// ---------- orders ----------
const orderTable = (rows) => `<table><tr><th>Order</th><th>Customer</th><th>Items</th><th>Total</th><th>Payment</th><th>Status</th><th></th></tr>
${rows.map((o) => `<tr><td><b>${o.orderNo}</b><br><small class="muted">${new Date(o.createdAt).toLocaleString('en-IN')}</small></td>
<td>${esc(o.user?.name || o.address?.name || '')}<br><small class="muted">${esc(o.user?.phone || '')}</small></td>
<td>${o.items.length}</td><td><b>${money(o.grandTotal)}</b></td><td>${o.paymentMethod}<br><small class="muted">${o.paymentStatus}</small></td>
<td><span class="pill ${o.status}">${o.status.replace(/_/g, ' ')}</span></td><td><button class="btn sm" onclick="viewOrder('${o._id}')">View</button></td></tr>`).join('') || '<tr><td colspan=7 class="muted">No orders yet</td></tr>'}</table>`;

pages.orders = async () => {
  const st = window._ost || '', q = window._oq || '';
  const d = await api(`/orders?all=true&limit=100&status=${st}&search=${encodeURIComponent(q)}`);
  $('#page').innerHTML = `<div class="toolbar">
    <select id="ost"><option value="">All statuses</option>${STATUSES.map((s) => `<option ${s === st ? 'selected' : ''} value="${s}">${s.replace(/_/g, ' ')}</option>`).join('')}</select>
    <input id="oq" placeholder="Search order no…" value="${esc(q)}"/><button class="btn" onclick="pages.orders()">↻ Refresh</button></div>
    <div class="card tbl">${orderTable(d.data)}</div>`;
  $('#ost').onchange = (e) => { window._ost = e.target.value; go('orders'); };
  $('#oq').onkeydown = (e) => { if (e.key === 'Enter') { window._oq = e.target.value; go('orders'); } };
};

window.viewOrder = safe(async (id) => {
  const o = (await api('/orders/' + id)).data;
  const a = o.address || {};
  openModal(`<h2>Order ${o.orderNo} <span class="pill ${o.status}">${o.status.replace(/_/g, ' ')}</span></h2>
  <div class="row2"><div><label>Customer</label><p>${esc(a.name)} • ${esc(a.phone)}<br>${esc(a.line1)} ${esc(a.line2 || '')}<br>${esc(a.landmark || '')} ${esc(a.city)} - ${esc(a.pincode)}</p></div>
  <div><label>Delivery slot</label><p>${esc(o.deliverySlot?.date || '-')} ${esc(o.deliverySlot?.slot || '')}</p><label>Payment</label><p>${o.paymentMethod} • ${o.paymentStatus}</p>${o.note ? `<label>Note</label><p>${esc(o.note)}</p>` : ''}</div></div>
  <table><tr><th>Item</th><th>Pack</th><th>Qty</th><th>Price</th><th>Total</th></tr>
  ${o.items.map((i) => `<tr><td>${esc(i.emoji || '')} ${esc(i.name)}</td><td>${esc(i.variantLabel)}</td><td>${i.qty}</td><td>${money(i.price)}</td><td>${money(i.total)}</td></tr>`).join('')}</table>
  <p style="text-align:right">Items: ${money(o.itemsTotal)} &nbsp; Coupon: -${money(o.couponDiscount)} &nbsp; Delivery: ${money(o.deliveryFee)} &nbsp; <b>Grand total: ${money(o.grandTotal)}</b></p>
  <div class="row2"><div><label>Update status</label><select id="newStatus">${STATUSES.map((s) => `<option ${s === o.status ? 'selected' : ''} value="${s}">${s.replace(/_/g, ' ')}</option>`).join('')}</select></div>
  <div><label>Payment status</label><select id="newPay">${['pending', 'paid', 'failed', 'refunded'].map((s) => `<option ${s === o.paymentStatus ? 'selected' : ''}>${s}</option>`).join('')}</select></div></div>
  <label>Note (optional)</label><input id="stNote"/>
  <div class="toolbar"><button class="btn primary" id="saveSt">Save</button><button class="btn" onclick="closeModal()">Close</button></div>
  <label>History</label>${o.statusHistory.map((h) => `<p><small>${new Date(h.at).toLocaleString('en-IN')}</small> — <b>${h.status}</b> ${esc(h.note || '')}</p>`).join('')}`);
  $('#saveSt').onclick = safe(async () => {
    await api(`/orders/${id}/status`, { method: 'PUT', body: { status: $('#newStatus').value, paymentStatus: $('#newPay').value, note: $('#stNote').value } });
    toast('✅ Order updated'); closeModal(); go(location.hash.slice(1) || 'orders');
  });
});

// ---------- products ----------
pages.products = async () => {
  await loadCats();
  const cat = window._pcat || '', q = window._pq || '';
  const d = await api(`/products?admin=true&limit=100&category=${cat}&search=${encodeURIComponent(q)}`);
  $('#page').innerHTML = `<div class="toolbar">
   <select id="pcat"><option value="">All categories</option>${catOptions(cat, true)}</select>
   <input id="pq" placeholder="Search product…" value="${esc(q)}"/>
   <button class="btn primary" onclick="editProduct()">+ Add Product</button></div>
   <p class="muted">💡 Price / MRP / Stock ko seedha table me badlo aur ✓ dabao — turant app me update ho jayega.</p>
   <div class="card tbl"><table><tr><th></th><th>Product</th><th>Category</th><th>Pack sizes & prices (Price / MRP / Stock)</th><th>Status</th><th></th></tr>
   ${d.data.map((p) => `<tr><td>${p.images?.[0] ? `<img class="thumb" src="${imgUrl(p.images[0])}">` : `<span class="emoji">${p.emoji || '🥬'}</span>`}</td>
   <td><b>${esc(p.name)}</b><br><small class="muted">${esc(p.hindiName || '')}</small></td>
   <td>${esc(p.category?.name || '')}<br><small class="muted">${esc(p.subCategory?.name || '')}</small></td>
   <td>${p.variants.map((v) => `<div style="display:flex;gap:4px;align-items:center;margin:3px 0"><span style="width:80px">${esc(v.label)}</span>
     <input class="price-in" data-k="price" value="${v.price}"><input class="price-in" data-k="mrp" value="${v.mrp}"><input class="price-in" data-k="stock" value="${v.stock}">
     <button class="btn sm primary" onclick="quickSave(this,'${p._id}','${v._id}')">✓</button></div>`).join('')}</td>
   <td>${p.isActive ? '<span class="pill">Active</span>' : '<span class="pill cancelled">Hidden</span>'}</td>
   <td><button class="btn sm" onclick="editProduct('${p._id}')">Edit</button> <button class="btn sm danger" onclick="delProduct('${p._id}')">Delete</button></td></tr>`).join('')}
   </table></div>`;
  $('#pcat').onchange = (e) => { window._pcat = e.target.value; go('products'); };
  $('#pq').onkeydown = (e) => { if (e.key === 'Enter') { window._pq = e.target.value; go('products'); } };
};

window.quickSave = safe(async (btn, pid, vid) => {
  const body = {};
  btn.parentElement.querySelectorAll('input').forEach((i) => (body[i.dataset.k] = Number(i.value)));
  await api(`/products/${pid}/variants/${vid}`, { method: 'PATCH', body });
  toast('✅ Price updated');
});
window.delProduct = safe(async (id) => { if (!confirm('Delete this product?')) return; await api('/products/' + id, { method: 'DELETE' }); toast('Deleted'); go('products'); });

const variantRow = (v = {}) => `<div class="vrow" style="margin:6px 0">
  <input placeholder="Label e.g. 500 g" data-k="label" value="${esc(v.label || '')}"/>
  <input type="number" step="any" placeholder="Qty" data-k="quantity" value="${v.quantity ?? ''}"/>
  <select data-k="unit">${UNITS.map((u) => `<option ${u === v.unit ? 'selected' : ''}>${u}</option>`).join('')}</select>
  <input type="number" placeholder="Price ₹" data-k="price" value="${v.price ?? ''}"/>
  <input type="number" placeholder="MRP ₹" data-k="mrp" value="${v.mrp ?? ''}"/>
  <input type="number" placeholder="Stock" data-k="stock" value="${v.stock ?? 100}"/>
  <button type="button" class="btn sm danger" onclick="this.parentElement.remove()">✕</button>
  ${v._id ? `<input type="hidden" data-k="_id" value="${v._id}">` : ''}</div>`;

window.editProduct = safe(async (id) => {
  await loadCats();
  const p = id ? (await api('/products/' + id)).data : { variants: [{ label: '500 g', quantity: 500, unit: 'g' }, { label: '1 kg', quantity: 1, unit: 'kg' }], isActive: true };
  const catId = p.category?._id || p.category || '';
  const subId = p.subCategory?._id || p.subCategory || '';
  openModal(`<h2>${id ? 'Edit' : 'Add'} Product</h2><form id="pf">
  <div class="row2"><div><label>Name *</label><input name="name" required value="${esc(p.name || '')}"/></div><div><label>Hindi name</label><input name="hindiName" value="${esc(p.hindiName || '')}"/></div></div>
  <div class="row3"><div><label>Category *</label><select name="category" id="pfCat" required><option value="">Select</option>${catOptions(catId, true)}</select></div>
  <div><label>Sub-category</label><select name="subCategory" id="pfSub"><option value="">—</option>${catId ? catOptions(subId, false, catId) : ''}</select></div>
  <div><label>Emoji (fallback icon)</label><input name="emoji" value="${esc(p.emoji || '')}"/></div></div>
  <label>Image</label><div style="display:flex;gap:10px;align-items:center">${p.images?.[0] ? `<img class="thumb" id="pfImgPrev" src="${imgUrl(p.images[0])}">` : '<img class="thumb" id="pfImgPrev">'}
  <input type="file" accept="image/*" id="pfImg"/><input type="hidden" name="image" value="${esc(p.images?.[0] || '')}"/></div>
  <label>Description</label><textarea name="description" rows="2">${esc(p.description || '')}</textarea>
  <div class="row3"><div><label>Tags (comma separated)</label><input name="tags" value="${esc((p.tags || []).join(','))}"/></div>
  <div><label>Origin</label><input name="origin" value="${esc(p.origin || '')}"/></div><div><label>Shelf life</label><input name="shelfLife" value="${esc(p.shelfLife || '')}"/></div></div>
  <label>Pack sizes / Variants (Label • Qty • Unit • Price • MRP • Stock)</label><div id="vars">${p.variants.map(variantRow).join('')}</div>
  <button type="button" class="btn sm" onclick="document.getElementById('vars').insertAdjacentHTML('beforeend', variantRow())">+ Add pack size</button>
  <div class="toolbar" style="margin-top:12px">${[['isActive', 'Active (visible in app)'], ['isFeatured', 'Featured'], ['isBestSeller', 'Best seller'], ['isOrganic', 'Organic']]
    .map(([k, l]) => `<label class="check"><input type="checkbox" name="${k}" ${p[k] ? 'checked' : ''}/> ${l}</label>`).join('')}</div>
  <div class="toolbar"><button class="btn primary">Save</button><button type="button" class="btn" onclick="closeModal()">Cancel</button></div></form>`);
  $('#pfCat').onchange = (e) => { $('#pfSub').innerHTML = '<option value="">—</option>' + catOptions('', false, e.target.value); };
  $('#pfImg').onchange = safe(async (e) => { const url = await uploadImage(e.target); $('#pf [name=image]').value = url; $('#pfImgPrev').src = imgUrl(url); toast('Image uploaded'); });
  $('#pf').onsubmit = safe(async (e) => {
    e.preventDefault();
    const f = e.target;
    const body = {
      name: f.name.value, hindiName: f.hindiName.value, category: f.category.value, subCategory: f.subCategory.value,
      emoji: f.emoji.value, description: f.description.value, tags: f.tags.value, origin: f.origin.value, shelfLife: f.shelfLife.value,
      images: f.image.value ? [f.image.value] : [],
      isActive: f.isActive.checked, isFeatured: f.isFeatured.checked, isBestSeller: f.isBestSeller.checked, isOrganic: f.isOrganic.checked,
      variants: [...document.querySelectorAll('#vars .vrow')].map((row) => {
        const v = {}; row.querySelectorAll('[data-k]').forEach((i) => (v[i.dataset.k] = i.type === 'number' ? Number(i.value) : i.value)); return v;
      }),
    };
    if (!body.variants.length) throw new Error('Add at least one pack size');
    if (body.variants.some((v) => !v.label || !(v.price >= 0) || !(v.mrp >= 0))) throw new Error('Fill label, price and MRP for every pack size');
    await api(id ? '/products/' + id : '/products', { method: id ? 'PUT' : 'POST', body });
    toast('✅ Product saved'); closeModal(); go('products');
  });
});

// ---------- categories ----------
pages.categories = async () => {
  await loadCats();
  const top = CATS.filter((c) => !c.parent);
  $('#page').innerHTML = `<div class="toolbar"><button class="btn primary" onclick="editCat()">+ Add Category / Sub-category</button></div>
  ${top.map((c) => `<div class="card" style="margin-bottom:12px"><div style="display:flex;justify-content:space-between;align-items:center">
    <h3 style="margin:0">${c.image ? `<img class="thumb" src="${imgUrl(c.image)}">` : esc(c.emoji || '')} ${esc(c.name)} ${c.isActive ? '' : '<span class="pill cancelled">Hidden</span>'}</h3>
    <div><button class="btn sm" onclick="editCat(null,'${c._id}')">+ Sub</button> <button class="btn sm" onclick="editCat('${c._id}')">Edit</button> <button class="btn sm danger" onclick="delCat('${c._id}')">Delete</button></div></div>
    <table>${CATS.filter((s) => s.parent && s.parent._id === c._id).map((s) => `<tr><td>${esc(s.emoji || '')} ${esc(s.name)} ${s.isActive ? '' : '<span class="pill cancelled">Hidden</span>'}</td>
    <td style="text-align:right"><button class="btn sm" onclick="editCat('${s._id}')">Edit</button> <button class="btn sm danger" onclick="delCat('${s._id}')">Delete</button></td></tr>`).join('') || '<tr><td class="muted">No sub-categories</td></tr>'}</table></div>`).join('')}`;
};
window.delCat = safe(async (id) => { if (!confirm('Delete category?')) return; await api('/categories/' + id, { method: 'DELETE' }); toast('Deleted'); go('categories'); });
window.editCat = safe(async (id, parentId) => {
  await loadCats();
  const c = id ? CATS.find((x) => x._id === id) : { parent: parentId ? { _id: parentId } : null, isActive: true, color: '#E8F5E9' };
  const pid = c.parent?._id || '';
  openModal(`<h2>${id ? 'Edit' : 'Add'} Category</h2><form id="cf">
  <div class="row2"><div><label>Name *</label><input name="name" required value="${esc(c.name || '')}"/></div>
  <div><label>Parent (leave empty for main category)</label><select name="parent"><option value="">— Main category —</option>${CATS.filter((x) => !x.parent && x._id !== id).map((x) => `<option value="${x._id}" ${x._id === pid ? 'selected' : ''}>${esc(x.name)}</option>`).join('')}</select></div></div>
  <div class="row3"><div><label>Emoji</label><input name="emoji" value="${esc(c.emoji || '')}"/></div><div><label>Background colour</label><input type="color" name="color" value="${esc(c.color || '#E8F5E9')}"/></div>
  <div><label>Sort order</label><input type="number" name="sortOrder" value="${c.sortOrder || 0}"/></div></div>
  <label>Image</label><input type="file" accept="image/*" id="cfImg"/><input type="hidden" name="image" value="${esc(c.image || '')}"/>
  <label class="check"><input type="checkbox" name="isActive" ${c.isActive ? 'checked' : ''}/> Active</label>
  <div class="toolbar" style="margin-top:12px"><button class="btn primary">Save</button><button type="button" class="btn" onclick="closeModal()">Cancel</button></div></form>`);
  $('#cfImg').onchange = safe(async (e) => { $('#cf [name=image]').value = await uploadImage(e.target); toast('Image uploaded'); });
  $('#cf').onsubmit = safe(async (e) => {
    e.preventDefault(); const f = e.target;
    const body = { name: f.name.value, parent: f.parent.value || null, emoji: f.emoji.value, color: f.color.value, sortOrder: Number(f.sortOrder.value), image: f.image.value, isActive: f.isActive.checked };
    await api(id ? '/categories/' + id : '/categories', { method: id ? 'PUT' : 'POST', body });
    toast('✅ Saved'); closeModal(); go('categories');
  });
});

// ---------- generic simple CRUD (banners, coupons) ----------
function simpleCrud(page, path, fields, rowHtml) {
  pages[page] = async () => {
    if (page === 'banners') await loadCats();
    const d = (await api('/admin/' + path)).data;
    window['_' + page] = d;
    $('#page').innerHTML = `<div class="toolbar"><button class="btn primary" onclick="editSimple('${page}')">+ Add</button></div>
    <div class="card tbl"><table>${d.map((x) => `<tr>${rowHtml(x)}<td style="text-align:right"><button class="btn sm" onclick="editSimple('${page}','${x._id}')">Edit</button>
    <button class="btn sm danger" onclick="delSimple('${page}','${x._id}')">Delete</button></td></tr>`).join('') || '<tr><td class="muted">Nothing here yet</td></tr>'}</table></div>`;
  };
  simpleCrud[page] = { path, fields };
}
window.delSimple = safe(async (page, id) => { if (!confirm('Delete?')) return; await api(`/admin/${simpleCrud[page].path}/${id}`, { method: 'DELETE' }); go(page); });
window.editSimple = safe(async (page, id) => {
  const { path, fields } = simpleCrud[page];
  const x = id ? window['_' + page].find((i) => i._id === id) : { isActive: true };
  openModal(`<h2>${id ? 'Edit' : 'Add'}</h2><form id="sf">${fields.map(([k, label, type, opts]) => {
    const v = x[k] ?? '';
    if (type === 'checkbox') return `<label class="check"><input type="checkbox" name="${k}" ${v ? 'checked' : ''}/> ${label}</label>`;
    if (type === 'select') return `<label>${label}</label><select name="${k}">${opts().map(([ov, ol]) => `<option value="${ov}" ${String(ov) === String(v?._id || v) ? 'selected' : ''}>${esc(ol)}</option>`).join('')}</select>`;
    if (type === 'image') return `<label>${label}</label><input type="file" accept="image/*" data-img="${k}"/><input type="hidden" name="${k}" value="${esc(v)}"/>`;
    const val = type === 'date' && v ? new Date(v).toISOString().slice(0, 10) : v;
    return `<label>${label}</label><input name="${k}" type="${type || 'text'}" value="${esc(val)}"/>`;
  }).join('')}<div class="toolbar" style="margin-top:12px"><button class="btn primary">Save</button><button type="button" class="btn" onclick="closeModal()">Cancel</button></div></form>`);
  document.querySelectorAll('#sf [data-img]').forEach((inp) => (inp.onchange = safe(async () => { $(`#sf [name=${inp.dataset.img}]`).value = await uploadImage(inp); toast('Uploaded'); })));
  $('#sf').onsubmit = safe(async (e) => {
    e.preventDefault();
    const body = {};
    fields.forEach(([k, , type]) => {
      const el = e.target[k];
      body[k] = type === 'checkbox' ? el.checked : type === 'number' ? Number(el.value) : el.value || (type === 'date' || type === 'select' ? null : '');
    });
    await api(id ? `/admin/${path}/${id}` : `/admin/${path}`, { method: id ? 'PUT' : 'POST', body });
    toast('✅ Saved'); closeModal(); go(page);
  });
});

simpleCrud('banners', 'banners', [
  ['title', 'Title'], ['subtitle', 'Subtitle'], ['emoji', 'Emoji'], ['bgColor', 'Background colour', 'color'], ['image', 'Image (optional)', 'image'],
  ['category', 'Opens category', 'select', () => [['', '— none —'], ...CATS.filter((c) => !c.parent).map((c) => [c._id, c.name])]],
  ['sortOrder', 'Sort order', 'number'], ['isActive', 'Active', 'checkbox'],
], (b) => `<td><div style="background:${esc(b.bgColor)};color:#fff;border-radius:12px;padding:10px 14px"><b>${esc(b.emoji || '')} ${esc(b.title)}</b><br><small>${esc(b.subtitle || '')}</small></div></td><td>${b.isActive ? '<span class="pill">Active</span>' : '<span class="pill cancelled">Hidden</span>'}</td>`);

simpleCrud('coupons', 'coupons', [
  ['code', 'Code'], ['description', 'Description'],
  ['type', 'Type', 'select', () => [['flat', 'Flat ₹'], ['percent', 'Percent %']]],
  ['value', 'Value', 'number'], ['minOrder', 'Min order ₹', 'number'], ['maxDiscount', 'Max discount ₹ (0 = no cap)', 'number'],
  ['usageLimit', 'Usage limit (0 = unlimited)', 'number'], ['expiresAt', 'Expires on', 'date'], ['isActive', 'Active', 'checkbox'],
], (c) => `<td><b>${esc(c.code)}</b><br><small class="muted">${esc(c.description || '')}</small></td><td>${c.type === 'flat' ? money(c.value) : c.value + '%'} • min ${money(c.minOrder)}</td><td>Used ${c.usedCount}</td><td>${c.isActive ? '<span class="pill">Active</span>' : '<span class="pill cancelled">Off</span>'}</td>`);

// ---------- users ----------
pages.users = async () => {
  const d = (await api('/admin/users')).data;
  $('#page').innerHTML = `<div class="card tbl"><table><tr><th>Name</th><th>Phone</th><th>Joined</th><th>Addresses</th><th></th></tr>
  ${d.map((u) => `<tr><td>${esc(u.name || '—')}</td><td>${esc(u.phone || '')}</td><td>${new Date(u.createdAt).toLocaleDateString('en-IN')}</td><td>${u.addresses.length}</td>
  <td><button class="btn sm ${u.isBlocked ? '' : 'danger'}" onclick="blockUser('${u._id}',${!u.isBlocked})">${u.isBlocked ? 'Unblock' : 'Block'}</button></td></tr>`).join('')}</table></div>`;
};
window.blockUser = safe(async (id, b) => { await api(`/admin/users/${id}/block`, { method: 'PUT', body: { isBlocked: b } }); go('users'); });

// ---------- settings ----------
pages.settings = async () => {
  const s = (await api('/settings')).data;
  $('#page').innerHTML = `<form class="card" id="stf">
  <div class="row2"><div><label>Store name</label><input name="storeName" value="${esc(s.storeName)}"/></div><div><label>Support phone</label><input name="supportPhone" value="${esc(s.supportPhone)}"/></div></div>
  <div class="row3"><div><label>Delivery fee ₹</label><input type="number" name="deliveryFee" value="${s.deliveryFee}"/></div>
  <div><label>Free delivery above ₹</label><input type="number" name="freeDeliveryAbove" value="${s.freeDeliveryAbove}"/></div>
  <div><label>Minimum order ₹</label><input type="number" name="minOrderAmount" value="${s.minOrderAmount}"/></div></div>
  <div class="row3"><div><label>Handling fee ₹</label><input type="number" name="handlingFee" value="${s.handlingFee}"/></div>
  <div><label>Support email</label><input name="supportEmail" value="${esc(s.supportEmail)}"/></div><div></div></div>
  <label>Delivery slots (one per line)</label><textarea name="deliverySlots" rows="4">${esc(s.deliverySlots.join('\n'))}</textarea>
  <label>Serviceable pincodes (comma separated, empty = all)</label><input name="serviceablePincodes" value="${esc(s.serviceablePincodes.join(','))}"/>
  <div class="toolbar"><label class="check"><input type="checkbox" name="isStoreOpen" ${s.isStoreOpen ? 'checked' : ''}/> Store open (accepting orders)</label>
  <label class="check"><input type="checkbox" name="codEnabled" ${s.codEnabled ? 'checked' : ''}/> Cash on delivery</label></div>
  <button class="btn primary">Save settings</button></form>`;
  $('#stf').onsubmit = safe(async (e) => {
    e.preventDefault(); const f = e.target;
    await api('/admin/settings', { method: 'PUT', body: {
      storeName: f.storeName.value, supportPhone: f.supportPhone.value, supportEmail: f.supportEmail.value,
      deliveryFee: Number(f.deliveryFee.value), freeDeliveryAbove: Number(f.freeDeliveryAbove.value), minOrderAmount: Number(f.minOrderAmount.value), handlingFee: Number(f.handlingFee.value),
      deliverySlots: f.deliverySlots.value.split('\n').map((x) => x.trim()).filter(Boolean),
      serviceablePincodes: f.serviceablePincodes.value.split(',').map((x) => x.trim()).filter(Boolean),
      isStoreOpen: f.isStoreOpen.checked, codEnabled: f.codEnabled.checked,
    } });
    toast('✅ Settings saved');
  });
};

// ---------- boot ----------
function boot() {
  $('#login').classList.add('hidden'); $('#shell').classList.remove('hidden');
  go(location.hash.slice(1) && pages[location.hash.slice(1)] ? location.hash.slice(1) : 'dashboard');
}
if (TOKEN) boot(); else logout();
