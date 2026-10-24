// iLife Watch Staff Dashboard — Main Controller
const $ = s => document.querySelector(s);
let S = null;
try { S = JSON.parse(sessionStorage.getItem('wc_session') || 'null'); } catch (e) {}
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const bpCls = (s, d) => (s >= 180 || d >= 110) ? 'crit' : (s >= 140 || d >= 90) ? 'warn' : 'ok';

async function api(path, opt = {}) {
  const r = await fetch(path, { ...opt, headers: { 'Content-Type': 'application/json', ...(S ? { Authorization: 'Bearer ' + S.token } : {}) } });
  const j = await r.json().catch(() => ({}));
  if (r.status === 401) { logout(); throw new Error(t('reauth')); }
  if (!r.ok) throw new Error(j.detail || ('HTTP ' + r.status));
  return j;
}

function logout() { S = null; try { sessionStorage.removeItem('wc_session'); } catch (e) {} render(); }
$('#logout').onclick = logout;
$('#langSelect').onchange = e => {
  curLang = e.target.value;
  try { localStorage.setItem('wc_lang', curLang); } catch (_) {}
  render();
};
$('#go').onclick = async () => {
  $('#lerr').textContent = '';
  try {
    S = await api('/v1/staff/login', { method: 'POST', body: JSON.stringify({ email: $('#email').value, password: $('#pw').value }) });
    try { sessionStorage.setItem('wc_session', JSON.stringify(S)); } catch (e) {}
    render();
  } catch (e) { $('#lerr').textContent = e.message; }
};

function tabsFor() {
  const r = S.staff.role, corp = S.org.type === 'corporate';
  const list = [];
  if (r !== 'hr_viewer' && !(corp && r === 'admin')) list.push(['alerts', t('tabAlerts')], ['patients', t('tabPatients')]);
  if (r === 'clinician' || (r !== 'hr_viewer' && S.org.type === 'clinic')) list.push(['ecg', t('tabEcg')]);
  if (corp || r === 'admin') list.push(['agg', t('tabAgg')]);
  if (r === 'admin') list.push(['add', t('tabAdd')]);
  return list;
}

let cur = null, activePatientId = null;
function render() {
  applyLangUI();
  const on = !!S;
  $('#login').classList.toggle('hidden', on);
  $('#app').classList.toggle('hidden', !on);
  $('#logout').classList.toggle('hidden', !on);
  if (!on) { $('#who').textContent = ''; return; }
  $('#who').textContent = `${S.staff.name} · ${S.org.name}`;
  const list = tabsFor();
  if (!cur || !list.find(x => x[0] === cur)) cur = list[0][0];
  $('#tabs').innerHTML = list.map(([k, l]) => `<button data-k="${k}" class="${k === cur ? 'on' : ''}">${l}</button>`).join('');
  $('#tabs').querySelectorAll('button').forEach(b => b.onclick = () => { activePatientId = null; cur = b.dataset.k; render(); });
  if (cur === 'patients' && activePatientId) {
    viewPatient(activePatientId).catch(e => $('#view').innerHTML = `<div class="card crit">${esc(e.message)}</div>`);
    return;
  }
  ({ alerts: viewAlerts, patients: viewPatients, ecg: viewEcgQueue, agg: viewAgg, add: viewAdd })[cur]()
    .catch(e => $('#view').innerHTML = `<div class="card crit">${esc(e.message)}</div>`);
}

async function viewAlerts() {
  const a = await api('/v1/staff/alerts');
  $('#view').innerHTML = `<div class="card"><h3 style="margin-top:0">${t('unackedAlerts')} (${a.length})</h3>${a.length ? '' : `<p class="muted">${t('empty')}</p>`}
  <div class="scroll"><table>${a.length ? `<tr><th>${t('colTime')}</th><th>${t('colPatient')}</th><th>${t('colDetail')}</th><th></th></tr>` : ''}
  ${a.map(x => `<tr><td>${fmt(x.created_at)}</td><td><a href="#" data-p="${x.patient_id}">${esc(x.patient_name)}</a></td>
  <td class="${x.level === 'critical' ? 'crit' : 'warn'}">${esc(x.message)}</td>
  <td><button data-ack="${x.id}">${t('ackBtn')}</button></td></tr>`).join('')}</table></div></div>`;
  $('#view').querySelectorAll('[data-ack]').forEach(b => b.onclick = async () => {
    const note = prompt(t('ackPrompt')) ?? '';
    await api(`/v1/staff/alerts/${b.dataset.ack}/ack`, { method: 'POST', body: JSON.stringify({ note }) });
    render();
  });
  $('#view').querySelectorAll('[data-p]').forEach(l => l.onclick = e => { e.preventDefault(); cur = 'patients'; viewPatient(+l.dataset.p); });
}

async function viewPatients() {
  const ps = await api('/v1/staff/patients');
  $('#view').innerHTML = `<div class="card"><div class="scroll"><table><tr><th>${t('colName')}</th><th>${t('colLatestBp')}</th><th>${t('colLastSync')}</th><th>${t('colAlerts')}</th></tr>
  ${ps.map(p => `<tr class="click" data-p="${p.id}"><td>${esc(p.display_name)}<div class="muted">${p.sex === 'M' ? t('male') : t('female')} · ${t('born')} ${p.birth_year}</div></td>
  <td>${p.latest_bp ? `<span class="${bpCls(p.latest_bp.systolic, p.latest_bp.diastolic)}">${p.latest_bp.systolic}/${p.latest_bp.diastolic}</span><div class="muted">${fmt(p.latest_bp.measured_at)}</div>` : '<span class="muted">-</span>'}</td>
  <td>${fmt(p.last_sync)}</td><td>${p.open_alerts ? `<span class="badge">${p.open_alerts}</span>` : ''}</td></tr>`).join('')}</table></div></div>`;
  $('#view').querySelectorAll('[data-p]').forEach(r => r.onclick = () => viewPatient(+r.dataset.p));
}

async function viewPatient(id) {
  activePatientId = id;
  const [sum, bp, hr, spo2, temp, steps, sleep, ecg] = await Promise.all([
    api(`/v1/staff/patients/${id}/summary`),
    api(`/v1/staff/patients/${id}/bp?days=30`),
    api(`/v1/staff/patients/${id}/vitals?metric=heart_rate&days=7`),
    api(`/v1/staff/patients/${id}/vitals?metric=spo2&days=7`),
    api(`/v1/staff/patients/${id}/vitals?metric=temperature&days=7`),
    api(`/v1/staff/patients/${id}/vitals?metric=steps&days=14`),
    api(`/v1/staff/patients/${id}/sleep?days=14`),
    api(`/v1/staff/patients/${id}/ecg`)
  ]);
  const lb = sum.latest_bp, sl = sum.latest_sleep;
  const slHrs = sl ? (((sl.deep_minutes || 0) + (sl.light_minutes || 0)) / 60).toFixed(1) : null;
  $('#view').innerHTML = `<p><button id="back">${t('back')}</button></p>
  <div class="card"><h2 style="margin:0 0 4px">${esc(sum.patient.display_name)}</h2><div class="muted">${t('emergencyContact')}: ${esc(sum.patient.emergency_contact || '-')}</div>
  <div class="grid" style="margin-top:12px">
   <div class="stat"><div class="muted">${t('statLatestBp')}</div><div class="v ${lb ? bpCls(lb.systolic, lb.diastolic) : ''}">${lb ? lb.systolic + '/' + lb.diastolic : '-'}</div><div class="muted">${lb ? fmt(lb.measured_at) + ' · ' + (lb.method === 'cuff' ? t('cuff') : t('ppg')) : ''}</div></div>
   <div class="stat"><div class="muted">${t('statBp7d')}</div><div class="v">${sum.bp_7d_avg ? sum.bp_7d_avg.systolic + '/' + sum.bp_7d_avg.diastolic : '-'}</div><div class="muted">${sum.bp_7d_avg ? sum.bp_7d_avg.n + ' ' + t('times') : ''}</div></div>
   <div class="stat"><div class="muted">${t('statHr')}</div><div class="v">${sum.latest_heart_rate ? Math.round(sum.latest_heart_rate.value) + ' bpm' : '-'}</div></div>
   <div class="stat"><div class="muted">${t('statSpo2')}</div><div class="v ${sum.latest_spo2 && sum.latest_spo2.value < 92 ? 'crit' : 'ok'}">${sum.latest_spo2 ? Math.round(sum.latest_spo2.value) + '%' : '-'}</div></div>
   <div class="stat"><div class="muted">${t('statTemp')}</div><div class="v ${sum.latest_temperature && sum.latest_temperature.value >= 37.5 ? 'warn' : ''}">${sum.latest_temperature ? sum.latest_temperature.value.toFixed(1) + ' °C' : '-'}</div></div>
   <div class="stat"><div class="muted">${t('statStepsSleep')}</div><div class="v" style="font-size:20px">${sum.latest_steps ? Math.round(sum.latest_steps.value).toLocaleString() + ' ' + t('stepsUnit') : '-'}</div><div class="muted">${slHrs ? slHrs + ' ' + t('sleepHrs') : ''}</div></div>
  </div></div>
  <div class="card"><h3 style="margin-top:0">${t('chartBp30d')}</h3>${bpChart(bp)}</div>
  <div class="card"><h3 style="margin-top:0">${t('chartEcg')}</h3>${ecg.length ? '' : `<p class="muted">${t('noData')}</p>`}<table>${ecg.map(e => `<tr class="click" data-e="${e.id}"><td>${fmt(e.measured_at)}</td><td>${t('hrLabel')} ${e.avg_heart_rate ?? '-'} · HRV ${e.avg_hrv ?? '-'}</td><td>${e.review_status === 'reviewed' ? `<span class="ok">${t('reviewed')}</span>` : `<span class="warn">${t('pendingReview')}</span>`}</td></tr>`).join('')}</table><div id="ecgv"></div></div>
  <div class="card"><h3 style="margin-top:0">${t('chartHr7d')}</h3>${lineChart(hr.map(v => [new Date(v.at), v.value]), t('bpmUnit'))}</div>
  <div class="card"><h3 style="margin-top:0">${t('chartSpo27d')}</h3>${lineChart(spo2.map(v => [new Date(v.at), v.value]), '%', null, [92], 'var(--accent)')}</div>
  <div class="card"><h3 style="margin-top:0">${t('chartTemp7d')}</h3>${lineChart(temp.map(v => [new Date(v.at), v.value]), '°C', null, [37.5], 'var(--warn)')}</div>
  <div class="card"><h3 style="margin-top:0">${t('chartSteps14d')}</h3>${barChart(steps.map(v => [new Date(v.at), v.value]), t('stepsUnit'))}</div>
  <div class="card"><h3 style="margin-top:0">${t('chartSleep14d')}</h3>${sleepChart(sleep)}</div>`;
  $('#back').onclick = () => { activePatientId = null; render(); };
  $('#view').querySelectorAll('[data-e]').forEach(r => r.onclick = () => showEcg(+r.dataset.e));
}

async function showEcg(id, host = '#ecgv') {
  const e = await api(`/v1/staff/ecg/${id}`);
  const box = $(host);
  box.innerHTML = `<p class="muted">${fmt(e.measured_at)} · ${e.sample_rate_hz || '?'} Hz · ${e.duration_sec || '?'} ${t('secUnit')} · ${t('adcNote')}</p><div class="scroll"><canvas id="ecgc" height="200"></canvas></div>
  ${S.staff.role === 'clinician' ? `<p><textarea id="rnote" rows="2" placeholder="${t('reviewPlaceholder')}">${esc(e.review_note || '')}</textarea></p><p><button class="primary" id="rsave">${t('saveReview')}</button></p>` : ''}`;
  const c = $('#ecgc'), w = e.waveform; c.width = Math.max(800, Math.min(w.length * 1.5, 12000));
  const g = c.getContext('2d'), css = getComputedStyle(document.documentElement);
  g.strokeStyle = css.getPropertyValue('--line'); for (let x = 0; x < c.width; x += 20) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, 200); g.stroke(); }
  if (w.length > 1) {
    const lo = Math.min(...w), hi = Math.max(...w) || lo + 1;
    g.strokeStyle = css.getPropertyValue('--crit'); g.beginPath();
    w.forEach((v, i) => { const x = i * c.width / (w.length - 1), y = 190 - (v - lo) / (hi - lo || 1) * 180; i ? g.lineTo(x, y) : g.moveTo(x, y); });
    g.stroke();
  }
  const b = $('#rsave');
  if (b) b.onclick = async () => { await api(`/v1/staff/ecg/${id}/review`, { method: 'POST', body: JSON.stringify({ note: $('#rnote').value }) }); b.textContent = t('saved'); };
}

async function viewEcgQueue() {
  const q = await api('/v1/staff/ecg-queue');
  $('#view').innerHTML = `<div class="card"><h3 style="margin-top:0">${t('ecgQueueTitle')} (${q.length})</h3><table>${q.map(e => `<tr class="click" data-e="${e.id}"><td>${fmt(e.measured_at)}</td><td>${esc(e.patient_name)}</td><td>${t('hrLabel')} ${e.avg_heart_rate ?? '-'}</td></tr>`).join('')}</table><div id="ecgv"></div></div>`;
  $('#view').querySelectorAll('[data-e]').forEach(r => r.onclick = () => showEcg(+r.dataset.e));
}

async function viewAgg() {
  const a = await api('/v1/staff/org/aggregate');
  if (a.suppressed) { $('#view').innerHTML = `<div class="card"><p>${esc(a.message)}</p><p class="muted">${t('participants')}: ${a.participants}</p></div>`; return; }
  const c = a.bp_latest_30d, L = { normal: t('bpNorm'), elevated: t('bpElev'), high: t('bpHigh'), no_data: t('bpNoData') };
  $('#view').innerHTML = `<div class="card"><p class="muted">${t('aggNote')}</p><div class="grid">
   <div class="stat"><div class="muted">${t('participants')}</div><div class="v">${a.participants}</div></div>
   <div class="stat"><div class="muted">${t('active7d')}</div><div class="v">${a.active_last_7d}</div></div>
   <div class="stat"><div class="muted">${t('avgSteps7d')}</div><div class="v">${a.avg_daily_steps_7d?.toLocaleString() ?? '-'}</div></div></div>
   <h3>${t('bpDist30d')}</h3><table>${Object.entries(L).map(([k, l]) => `<tr><td>${l}</td><td>${c[k] ?? 0}</td></tr>`).join('')}</table></div>`;
}

function viewAdd() {
  $('#view').innerHTML = `<div class="card" style="max-width:460px"><h3 style="margin-top:0">${t('addTitle')}</h3>
  <p><input id="n" placeholder="${t('displayName')}"></p><p class="row"><select id="sx" style="width:auto"><option value="F">${t('female')}</option><option value="M">${t('male')}</option></select>
  <input id="by" type="number" placeholder="${t('birthYear')}" style="flex:1"></p><p class="row"><input id="h" type="number" placeholder="${t('heightCm')}" style="flex:1"><input id="w" type="number" placeholder="${t('weightKg')}" style="flex:1"></p>
  <p><input id="ec" placeholder="${t('emergPlaceholder')}"></p><p><button class="primary" id="save">${t('createBtn')}</button></p><div id="out"></div></div>`;
  $('#save').onclick = async () => {
    try {
      const r = await api('/v1/staff/patients', { method: 'POST', body: JSON.stringify({ display_name: $('#n').value, sex: $('#sx').value, birth_year: +$('#by').value, height_cm: +$('#h').value, weight_kg: +$('#w').value, emergency_contact: $('#ec').value || null }) });
      $('#out').innerHTML = `<div class="card" style="background:var(--soft)"><b>${t('enrollCode')}:</b> ${esc(r.enrollment_code)}<br><b>PIN:</b> ${esc(r.pin)}<p class="muted">${t('pinOnce')}</p></div>`;
    } catch (e) { $('#out').innerHTML = `<p class="crit">${esc(e.message)}</p>`; }
  };
  return Promise.resolve();
}

render();
