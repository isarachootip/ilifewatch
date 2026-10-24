// iLife Watch Staff Dashboard — SVG Chart Renderers (BP, Vitals, Steps, Sleep)
function bpChart(rows) {
  if (!rows.length) return `<p class="muted">${t('noData')}</p>`;
  return lineChart(
    rows.map(r => [new Date(r.measured_at), r.systolic]),
    'mmHg',
    rows.map(r => [new Date(r.measured_at), r.diastolic]),
    [140, 90]
  );
}

function lineChart(a, unit, b = null, refs = [], strokeA = 'var(--crit)') {
  if (!a.length) return `<p class="muted">${t('noData')}</p>`;
  const W = 800, H = 210, P = 36, all = [...a, ...(b || [])];
  const t0 = Math.min(...all.map(p => +p[0])), t1 = Math.max(...all.map(p => +p[0])) || t0 + 1;
  let lo = Math.min(...all.map(p => p[1]), ...refs), hi = Math.max(...all.map(p => p[1]), ...refs);
  const pad = Math.max((hi - lo) * 0.12, 1);
  lo = +(lo - pad).toFixed(1);
  hi = +(hi + pad).toFixed(1);
  const X = ts => P + ((+ts - t0) / ((t1 - t0) || 1)) * (W - P * 1.5);
  const Y = v => H - P - ((v - lo) / ((hi - lo) || 1)) * (H - P * 1.6);
  const path = s => s.map((p, i) => (i ? 'L' : 'M') + X(p[0]).toFixed(1) + ',' + Y(p[1]).toFixed(1)).join('');
  const dots = (s, col) => s.length < 60 ? s.map(p => `<circle cx="${X(p[0])}" cy="${Y(p[1])}" r="2.8" fill="${col}"/>`).join('') : '';
  return `<div class="scroll"><svg viewBox="0 0 ${W} ${H}" width="100%" style="min-width:480px">
  ${refs.map(r => `<line x1="${P}" x2="${W - P / 2}" y1="${Y(r)}" y2="${Y(r)}" stroke="var(--warn)" stroke-dasharray="4 4" opacity=".65"/><text x="${W - P / 2 - 2}" y="${Y(r) - 3}" text-anchor="end">${r}</text>`).join('')}
  <text x="4" y="14">${unit}</text><text x="4" y="${Y(hi) + 4}">${hi}</text><text x="4" y="${Y(lo)}">${lo}</text>
  <text x="${P}" y="${H - 8}">${fmtDate(t0)}</text><text x="${W - P / 2}" y="${H - 8}" text-anchor="end">${fmtDate(t1)}</text>
  <path d="${path(a)}" fill="none" stroke="${strokeA}" stroke-width="2"/>${dots(a, strokeA)}
  ${b ? `<path d="${path(b)}" fill="none" stroke="var(--accent)" stroke-width="2"/>${dots(b, 'var(--accent)')}` : ''}</svg></div>
  ${b ? `<div class="muted"><span class="crit">—</span> ${t('sysLegend')} &nbsp; <span style="color:var(--accent)">—</span> ${t('diaLegend')} &nbsp; ${t('refLegend')} (140/90)</div>` : ''}`;
}

function barChart(points, unit, col = 'var(--accent)') {
  if (!points.length) return `<p class="muted">${t('noData')}</p>`;
  const byDay = new Map();
  points.forEach(([dt, v]) => {
    const k = dt.toISOString().slice(0, 10);
    byDay.set(k, Math.max(byDay.get(k) || 0, v));
  });
  const days = [...byDay.entries()].slice(-14);
  const W = 800, H = 200, P = 34;
  const hi = Math.max(...days.map(d => d[1]), 1000);
  const bw = Math.min(38, Math.floor((W - P * 2) / days.length) - 6);
  return `<div class="scroll"><svg viewBox="0 0 ${W} ${H}" width="100%" style="min-width:480px">
  <text x="4" y="14">${unit}</text><text x="4" y="${P}">${Math.round(hi)}</text><text x="4" y="${H - P}">0</text>
  ${days.map(([d, v], i) => {
    const x = P + 16 + i * ((W - P * 2) / days.length);
    const h = Math.max(3, (v / hi) * (H - P * 2));
    const y = H - P - h;
    return `<rect x="${x}" y="${y}" width="${bw}" height="${h}" rx="4" fill="${col}"/>
      <text x="${x + bw / 2}" y="${y - 4}" text-anchor="middle">${Math.round(v)}</text>
      <text x="${x + bw / 2}" y="${H - 10}" text-anchor="middle">${d.slice(5)}</text>`;
  }).join('')}</svg></div>`;
}

function sleepChart(rows) {
  if (!rows.length) return `<p class="muted">${t('noData')}</p>`;
  return `<div class="scroll"><table>
    <tr><th>${t('colTime')}</th><th>${t('deepSleep')}</th><th>${t('lightSleep')}</th><th>${t('wakeCount')}</th></tr>
    ${rows.slice(-14).reverse().map(r => {
      const total = Math.max(1, (r.deep_minutes || 0) + (r.light_minutes || 0));
      const dp = Math.round(((r.deep_minutes || 0) / total) * 100);
      return `<tr>
        <td>${fmt(r.start)} → ${fmt(r.end)}</td>
        <td><b>${r.deep_minutes || 0}</b> ${t('minUnit')} (${dp}%)</td>
        <td><b>${r.light_minutes || 0}</b> ${t('minUnit')}</td>
        <td>${r.wake_count ?? 0} ${t('times')}</td>
      </tr>`;
    }).join('')}
  </table></div>`;
}
