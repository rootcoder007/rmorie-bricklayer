// The drift report's script: drawn by rmoriebricklayer::drfthtml() into the page, reading the
// JSON in #drift-data. No library and no network: the hero is a 2D canvas, every other chart SVG
// built here, every value is set as text (never as markup), and the downloads are data: URLs made in
// the browser. Colours come from the page's CSS tokens, so the theme switch redraws in its palette.
(function () {
  'use strict';
  var D = JSON.parse(document.getElementById('drift-data').textContent);
  var arr = function (v) { return v == null ? [] : (Array.isArray(v) ? v : [v]); };
  var $ = function (id) { return document.getElementById(id); };
  var SVGNS = 'http://www.w3.org/2000/svg';
  var COLS = arr(D.columns);
  var B0 = { warn: D.bands.warn, fail: D.bands.fail, alpha: D.alpha };
  var S = { warn: B0.warn, fail: B0.fail, alpha: B0.alpha, sel: -1, sort: 'verdict', desc: false, q: '', filt: {},
    runs: [] };
  var RANK = { fail: 0, warn: 1, ok: 2, untested: 3 };
  var MARK = { ok: '\u2714 ok', warn: '\u26a0 warn', fail: '\u2716 fail', untested: '\u2013 untested' };
  var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var tok = function (name) { return getComputedStyle(document.documentElement).getPropertyValue(name).trim(); };
  var col = function (name) { return tok('--' + name) || '#888888'; };

  // ---- helpers -------------------------------------------------------------------------------
  function el(tag, attrs, text) {
    var e = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (k) { e.setAttribute(k, attrs[k]); });
    if (text != null) e.textContent = text;
    return e;
  }
  function sv(tag, attrs, text) {
    var e = document.createElementNS(SVGNS, tag);
    Object.keys(attrs || {}).forEach(function (k) { e.setAttribute(k, attrs[k]); });
    if (text != null) e.textContent = text;
    return e;
  }
  function num(v) { return v == null || v === '' || isNaN(v) ? null : Number(v); }
  function fmt(v) {
    v = num(v);
    if (v == null) return '\u2014';
    if (v !== 0 && (Math.abs(v) < 1e-3 || Math.abs(v) >= 1e6)) return v.toExponential(2);
    return String(Number(v.toPrecision(3)));
  }
  // a date column's values are days since 1970-01-01, a date-time's seconds: shown in ISO 8601
  function val(c, v, stat) {
    v = num(v);
    if (v == null || !c.kind || c.kind === 'number') return fmt(v);
    if (stat === 'sd') return fmt(v) + (c.kind === 'date' ? ' days' : ' s');
    var d = new Date(c.kind === 'date' ? v * 86400000 : v * 1000);
    return c.kind === 'date' ? d.toISOString().slice(0, 10) : d.toISOString().slice(0, 19) + 'Z';
  }
  // a p-value below the smallest double the tests resolve reads as a bound, not as zero
  function fmtp(v) { v = num(v); return v === 0 ? '< 1e-16' : fmt(v); }
  function peq(v) { return num(v) === 0 ? '< 1e-16' : '= ' + fmt(v); }
  function pct(v) { v = num(v); return v == null ? '\u2014' : (100 * v).toFixed(1) + '%'; }
  function verdict(c) {
    var p = num(c.p_value), psi = num(c.psi);
    var large = c.nref != null && c.ncur != null && c.nref >= D.psiminn && c.ncur >= D.psiminn;
    var v = p == null ? 'untested' : 'ok';
    if (psi != null && psi > S.warn) v = 'warn';
    if ((p != null && p < S.alpha) || (psi != null && large && psi > S.fail)) v = 'fail';
    return v;
  }
  function band(psi) {
    psi = num(psi);
    return psi == null ? 'untested' : (psi > S.fail ? 'fail' : (psi > S.warn ? 'warn' : 'ok'));
  }
  function missChange(c) {
    return c.misscur == null || c.missref == null ? null : c.misscur - c.missref;
  }
  function note(c, v) {
    var p = num(c.p_value);
    if (v === 'fail') {
      return c.column + ' moved: ' + (p != null && p < S.alpha ?
        'the ' + c.test + ' test gives p ' + peq(p) + ', below alpha ' + fmt(S.alpha) :
        'its PSI of ' + fmt(c.psi) + ' is above the fail band ' + fmt(S.fail)) + '; ' + D.meaning + '.';
    }
    if (v === 'warn') {
      return c.column + ' is worth a look: its PSI of ' + fmt(c.psi) + ' is above the warn band ' +
        fmt(S.warn) + ', though the test gives p ' + peq(p) + '.';
    }
    if (v === 'ok') {
      return c.column + ' looks the same in both: PSI ' + fmt(c.psi) + ', below the warn band ' +
        fmt(S.warn) + ', and p ' + peq(p) + '.';
    }
    return c.column + ' was not tested: ' + (c.note ? c.note : 'no test applies') + '.';
  }
  function chip(v) { return el('span', { 'class': 'chip ' + v }, MARK[v]); }
  function order() {
    return Object.keys(COLS).map(Number).sort(function (a, b) {
      return RANK[verdict(COLS[a])] - RANK[verdict(COLS[b])] || (num(COLS[b].psi) || 0) - (num(COLS[a].psi) || 0);
    });
  }
  function short(s, n) { s = String(s); return s.length > n ? s.slice(0, n - 1) + '\u2026' : s; }

  // ---- header and provenance ------------------------------------------------------------------
  function header() {
    var n = { ok: 0, warn: 0, fail: 0, untested: 0 };
    COLS.forEach(function (c) { n[verdict(c)]++; });
    var struct = arr(D.added).length + arr(D.removed).length;
    $('verdict').textContent = n.fail || struct ? '\u2716 Drift detected' :
      (n.warn ? '\u26a0 Worth a look' : '\u2714 No drift detected');
    $('counts').textContent = n.fail + ' fail, ' + n.warn + ' warn, ' + n.ok + ' ok, ' + n.untested +
      ' untested; rows ' + D.nref + ' \u2192 ' + D.ncur +
      (arr(D.added).length ? '; added: ' + arr(D.added).join(', ') : '') +
      (arr(D.removed).length ? '; removed: ' + arr(D.removed).join(', ') : '');
  }
  function provenance() {
    var dl = $('prov'), p = D.provenance || {};
    var rows = [['capsule', p.name], ['source', p.url],
      ['pinned sha256', p.sha256 ? String(p.sha256).slice(0, 16) + '\u2026' : null], ['data date', p.date],
      ['rows', D.nref + ' reference, ' + D.ncur + ' current'], ['written', D.written],
      ['by', 'rmoriebricklayer ' + D.version]];
    rows.forEach(function (r) {
      if (r[1] == null) return;
      dl.appendChild(el('dt', {}, r[0]));
      dl.appendChild(el('dd', {}, r[1]));
    });
  }

  // ---- the hero: the chosen column's two distributions as animated ribbons ----------------------
  var hero = { from: null, to: null, t: 1, raf: 0 };
  function heroShape(c) {
    if (c && c.dens) return { kind: 'dens', c: c, x: arr(c.dens.x), a: arr(c.dens.ref), b: arr(c.dens.cur) };
    if (c && c.bins) return { kind: 'bins', c: c, x: arr(c.bins.bin), a: arr(c.bins.ref), b: arr(c.bins.cur) };
    return null;
  }
  function heroPaint() {
    var cv = $('hero'), ctx = cv.getContext && cv.getContext('2d');
    if (!ctx) return;
    var dpr = window.devicePixelRatio || 1, w = cv.clientWidth, h = cv.clientHeight;
    cv.width = w * dpr;
    cv.height = h * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    var to = hero.to;
    if (!to) return;
    var e = 1 - Math.pow(1 - hero.t, 3);
    var same = hero.from && hero.from.kind === to.kind && hero.from.a.length === to.a.length;
    var mix = function (p, q) { return q.map(function (v, i) { return same ? (num(p[i]) || 0) * (1 - e) + (num(v) || 0) * e : (num(v) || 0) * e; }); };
    var a = mix(same ? hero.from.a : [], to.a), b = mix(same ? hero.from.b : [], to.b);
    var top = Math.max.apply(null, to.a.concat(to.b).map(function (v) { return num(v) || 0; }).concat([1e-12]));
    var L = 16, R = w - 16, T = w < 600 ? 104 : 70, Bt = h - 26;
    var y = function (v) { return Bt - (v / top) * (Bt - T); };
    ctx.strokeStyle = col('rule');
    ctx.lineWidth = 1;
    for (var g = 0; g <= 3; g++) { ctx.beginPath(); ctx.moveTo(L, Bt - g * (Bt - T) / 3); ctx.lineTo(R, Bt - g * (Bt - T) / 3); ctx.stroke(); }
    var n = a.length;
    if (to.kind === 'dens') {
      var x = function (i) { return L + (R - L) * i / (n - 1); };
      var area = function (v, fill, alpha, stroke) {
        ctx.beginPath();
        ctx.moveTo(x(0), Bt);
        v.forEach(function (q, i) { ctx.lineTo(x(i), y(q)); });
        ctx.lineTo(x(n - 1), Bt);
        ctx.closePath();
        ctx.globalAlpha = alpha;
        ctx.fillStyle = fill;
        ctx.fill();
        ctx.globalAlpha = 1;
        if (stroke) {
          ctx.beginPath();
          v.forEach(function (q, i) { if (i) ctx.lineTo(x(i), y(q)); else ctx.moveTo(x(i), y(q)); });
          ctx.strokeStyle = stroke;
          ctx.lineWidth = 2.2;
          ctx.stroke();
        }
      };
      area(a, col('ref'), 0.14, col('ref'));
      area(b, col('curfill'), 0.55, col('cur'));
      // where the two part: the band between the curves, the PSI's mass
      ctx.beginPath();
      a.forEach(function (q, i) { if (i) ctx.lineTo(x(i), y(q)); else ctx.moveTo(x(i), y(q)); });
      for (var k = n - 1; k >= 0; k--) ctx.lineTo(x(k), y(b[k]));
      ctx.closePath();
      ctx.globalAlpha = 0.3;
      ctx.fillStyle = col('div');
      ctx.fill();
      ctx.globalAlpha = 1;
      ctx.beginPath();
      a.forEach(function (q, i) { if (i) ctx.lineTo(x(i), y(q)); else ctx.moveTo(x(i), y(q)); });
      ctx.strokeStyle = col('ref');
      ctx.lineWidth = 2.2;
      ctx.stroke();
      ctx.fillStyle = col('dim');
      ctx.font = '11px system-ui, sans-serif';
      ctx.textAlign = 'left';
      ctx.fillText(val(to.c, to.x[0]), L, h - 8);
      ctx.textAlign = 'right';
      ctx.fillText(val(to.c, to.x[n - 1]), R, h - 8);
    } else {
      var bw = (R - L) / Math.max(n, 1);
      a.forEach(function (q, i) {
        var x0 = L + i * bw + bw * 0.12, ww = bw * 0.76;
        ctx.globalAlpha = 0.16;
        ctx.fillStyle = col('ref');
        ctx.fillRect(x0, y(q), ww, Bt - y(q));
        ctx.globalAlpha = 0.75;
        ctx.fillStyle = col('curfill');
        ctx.fillRect(x0 + ww * 0.18, y(b[i]), ww * 0.64, Bt - y(b[i]));
        ctx.globalAlpha = 0.5;
        ctx.fillStyle = col('div');
        ctx.fillRect(x0 + ww * 0.18, Math.min(y(q), y(b[i])), ww * 0.64, Math.abs(y(q) - y(b[i])));
        ctx.globalAlpha = 1;
        ctx.fillStyle = col('dim');
        ctx.font = '11px system-ui, sans-serif';
        ctx.textAlign = 'center';
        if (bw > 30) ctx.fillText(short(to.x[i], Math.floor(bw / 7)), x0 + ww / 2, h - 8);
      });
    }
  }
  function heroShow(c) {
    var next = heroShape(c);
    hero.from = hero.to;
    hero.to = next;
    $('hero-col').textContent = c ? c.column : 'no column to draw';
    heroStat();
    $('hero').setAttribute('aria-label', c ? 'Reference and current distributions of ' + c.column : 'No column');
    if (reduced || !next) { hero.t = 1; heroPaint(); return; }
    hero.t = 0;
    var t0 = null;
    if (hero.raf) cancelAnimationFrame(hero.raf);
    var step = function (now) {
      if (t0 === null) t0 = now;
      hero.t = Math.min(1, (now - t0) / 800);
      heroPaint();
      hero.raf = hero.t < 1 ? requestAnimationFrame(step) : 0;
    };
    hero.raf = requestAnimationFrame(step);
    // a background tab runs no frames: the curves still end drawn in full
    setTimeout(function () { if (hero.to === next && hero.t < 1) { hero.t = 1; heroPaint(); } }, 1200);
  }
  function heroStat() {
    var c = hero.to && hero.to.c;
    if (!c) { $('hero-stat').textContent = ''; return; }
    $('hero-stat').textContent = MARK[verdict(c)] + ' \u00b7 PSI ' + fmt(c.psi) + ' \u00b7 ' + c.test +
      ' statistic ' + fmt(c.statistic) + ', p ' + peq(c.p_value);
  }

  // ---- the capsule chain: provenance -> pinned bytes -> manifest -> attestation ----------------
  function chain() {
    var ch = D.chain, box = $('chain');
    if (!ch) return;
    var links = arr(ch.link), lab = arr(ch.label), st = arr(ch.status), det = arr(ch.detail);
    // across on a wide screen, down on a narrow one
    var cw = Math.max(300, box.clientWidth || 760), across = cw >= 640;
    var bw = across ? Math.min(170, (cw - 60) / 4) : Math.min(260, cw - 40), gap = across ? (cw - 4 * bw) / 3 : 0;
    var W = cw, H = across ? 150 : 4 * 150;
    var s = sv('svg', { viewBox: '0 0 ' + W + ' ' + H, role: 'img', id: 'chain-svg',
      'aria-label': 'Capsule chain: ' + lab.map(function (l, i) { return l + ' ' + st[i]; }).join(', ') });
    s.appendChild(sv('title', {}, 'Capsule chain'));
    var colour = { ok: col('ok'), warn: col('warn'), fail: col('fail'), none: col('untested') };
    links.forEach(function (k, i) {
      var x = across ? i * (bw + gap) : (cw - bw) / 2, g = sv('g', { tabindex: '0', 'class': 'brick', 'data-link': k,
        transform: 'translate(0 ' + (across ? 0 : i * 150) + ')' });
      g.appendChild(sv('title', {}, lab[i] + ': ' + st[i] + ' (' + det[i] + ')'));
      if (i) {
        g.appendChild(across ? sv('line', { x1: x - gap + 4, x2: x - 4, y1: 52, y2: 52, stroke: colour[st[i]] || colour.none,
          'stroke-width': 3, 'stroke-dasharray': st[i] === 'ok' ? '' : '6 5' }) :
          sv('line', { x1: cw / 2, x2: cw / 2, y1: -24, y2: 18, stroke: colour[st[i]] || colour.none, 'stroke-width': 3,
            'stroke-dasharray': st[i] === 'ok' ? '' : '6 5' }));
      }
      var r = sv('rect', { x: x, y: 20, width: bw, height: 64, rx: 6, fill: colour[st[i]] || colour.none, opacity: 0.92 });
      g.appendChild(r);
      // hash marks on the brick, from its label: the same bars every time for the same link
      var seed = 0;
      for (var q = 0; q < lab[i].length; q++) seed = (seed * 31 + lab[i].charCodeAt(q)) >>> 0;
      for (var row = 0; row < 3; row++) {
        var xx = x + 12;
        while (xx < x + bw - 18) {
          seed = (seed * 1664525 + 1013904223) >>> 0;
          var len = 6 + (seed / 4294967296) * 22;
          if ((seed >>> 8) % 4) g.appendChild(sv('line', { x1: xx, x2: Math.min(xx + len, x + bw - 12), y1: 44 + row * 9, y2: 44 + row * 9, stroke: '#ffffff', 'stroke-opacity': 0.55, 'stroke-width': 2 }));
          xx += len + 6;
        }
      }
      g.appendChild(sv('text', { x: x + 12, y: 37, fill: '#ffffff', style: 'fill:#ffffff;font-size:12px;font-weight:600' }, lab[i]));
      g.appendChild(sv('text', { x: x + bw / 2, y: 104, 'text-anchor': 'middle', style: 'font-size:11px;text-transform:uppercase' },
        ({ ok: '\u2714 verified', warn: '\u26a0 moved', fail: '\u2716 failed', none: '\u2013 not checked' })[st[i]] || st[i]));
      g.appendChild(sv('text', { x: x + bw / 2, y: 120, 'text-anchor': 'middle' }, short(det[i], Math.floor(bw / 5.5))));
      g.setAttribute('data-y', across ? '0' : String(i * 150));
      s.appendChild(g);
    });
    box.textContent = '';
    box.appendChild(s);
    // laid brick by brick, each dropping into place, as the provenance page lays its wall
    var bricks = Array.prototype.slice.call(s.querySelectorAll('.brick'));
    var lay = function (t) {
      bricks.forEach(function (g, k) {
        var p = Math.max(0, Math.min(1, (t - k * 160) / 420)), e = 1 - Math.pow(1 - p, 3);
        g.setAttribute('opacity', String(e));
        g.setAttribute('transform', 'translate(0 ' + (Number(g.getAttribute('data-y')) - 18 * (1 - e)) + ')');
      });
    };
    if (reduced) { lay(1e9); return; }
    lay(0);
    var t0 = null;
    var step = function (now) {
      if (t0 === null) t0 = now;
      lay(now - t0);
      if (now - t0 < 1200) requestAnimationFrame(step); else lay(1e9);
    };
    requestAnimationFrame(step);
    setTimeout(function () { lay(1e9); }, 1600);
  }

  // ---- the column table -----------------------------------------------------------------------
  var HEAD = [['verdict', 'verdict'], ['column', 'column'], ['type', 'type'], ['test', 'test'],
    ['statistic', 'statistic'], ['p_value', 'p-value'], ['psi', 'PSI'], ['miss', 'missing \u0394'],
    ['nref', 'n reference'], ['ncur', 'n current']];
  function key(c, k) {
    if (k === 'verdict') return RANK[verdict(c)] * 1e6 - (num(c.psi) || 0);
    if (k === 'miss') return missChange(c);
    return c[k];
  }
  function visible() {
    var q = S.q.toLowerCase();
    var kinds = ['ok', 'warn', 'fail'].filter(function (k) { return S.filt[k]; });
    var types = ['numeric', 'categorical'].filter(function (k) { return S.filt[k]; });
    var idx = Object.keys(COLS).map(Number).filter(function (i) {
      var c = COLS[i], v = verdict(c);
      return String(c.column).toLowerCase().indexOf(q) >= 0 &&
        (!kinds.length || kinds.indexOf(v) >= 0) &&
        (!types.length || types.indexOf(c.type === 'date' ? 'numeric' : c.type) >= 0);
    });
    idx.sort(function (a, b) {
      var x = key(COLS[a], S.sort), y = key(COLS[b], S.sort);
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      var r = typeof x === 'string' ? x.localeCompare(y) : x - y;
      return S.desc ? -r : r;
    });
    return idx;
  }
  function tableHead() {
    var tr = document.querySelector('#coltable thead tr');
    HEAD.forEach(function (h) {
      var th = el('th', { scope: 'col', 'aria-sort': 'none' });
      var b = el('button', { type: 'button', 'data-key': h[0] }, h[1]);
      b.addEventListener('click', function () {
        S.desc = S.sort === h[0] ? !S.desc : false;
        S.sort = h[0];
        table();
      });
      th.appendChild(b);
      tr.appendChild(th);
    });
  }
  function table() {
    var tb = document.querySelector('#coltable tbody');
    tb.textContent = '';
    document.querySelectorAll('#coltable thead th').forEach(function (th, i) {
      th.setAttribute('aria-sort', HEAD[i][0] === S.sort ? (S.desc ? 'descending' : 'ascending') : 'none');
    });
    visible().forEach(function (i) {
      var c = COLS[i], v = verdict(c);
      var tr = el('tr', { tabindex: '0', 'data-i': String(i), 'aria-selected': String(i === S.sel) });
      var td = el('td');
      td.appendChild(chip(v));
      tr.appendChild(td);
      tr.appendChild(el('th', { scope: 'row' }, c.column));
      tr.appendChild(el('td', {}, c.type));
      tr.appendChild(el('td', {}, c.test));
      [[c.statistic, fmt], [c.p_value, fmtp], [c.psi, fmt]].forEach(function (x) { tr.appendChild(el('td', { 'class': 'num' }, x[1](x[0]))); });
      var m = missChange(c);
      tr.appendChild(el('td', { 'class': 'num' }, m == null ? '\u2014' : (m >= 0 ? '+' : '') + (100 * m).toFixed(1) + ' pts'));
      tr.appendChild(el('td', { 'class': 'num' }, c.nref == null ? '\u2014' : String(c.nref)));
      tr.appendChild(el('td', { 'class': 'num' }, c.ncur == null ? '\u2014' : String(c.ncur)));
      tr.addEventListener('click', function () { select(i); });
      tb.appendChild(tr);
    });
  }
  function filters() {
    var box = $('filters');
    ['ok', 'warn', 'fail', 'numeric', 'categorical'].forEach(function (k) {
      var b = el('button', { type: 'button', 'aria-pressed': 'false', id: 'filter-' + k }, k);
      b.addEventListener('click', function () {
        S.filt[k] = !S.filt[k];
        b.setAttribute('aria-pressed', String(S.filt[k]));
        table();
      });
      box.appendChild(b);
    });
  }

  // ---- SVG chart frame ---------------------------------------------------------------------------
  // every chart is drawn at its card's own width, so its text is true size at any screen width
  var W = 560, H = 300, M = { l: 66, r: 14, t: 16, b: 50 };
  function sized(id, h) { W = Math.max(280, Math.floor(($(id) && $(id).clientWidth) || 560)); H = h; }
  function frame(label, w, h) {
    var s = sv('svg', { viewBox: '0 0 ' + (w || W) + ' ' + (h || H), role: 'img', 'aria-label': label, xmlns: SVGNS });
    s.appendChild(sv('title', {}, label));
    return s;
  }
  function scale(lo, hi, a, b) { return function (v) { return a + (b - a) * (v - lo) / (hi - lo || 1); }; }
  function yaxis(s, lo, hi, f) {
    var y = scale(lo, hi, H - M.b, M.t);
    [lo, (lo + hi) / 2, hi].forEach(function (v) {
      s.appendChild(sv('line', { x1: M.l, x2: W - M.r, y1: y(v), y2: y(v), stroke: col('rule') }));
      s.appendChild(sv('text', { x: M.l - 4, y: y(v) + 3, 'text-anchor': 'end' }, f(v)));
    });
    return y;
  }
  function legend(s, items) {
    var step = Math.min(104, (W - M.l) / Math.max(items.length, 1));
    items.forEach(function (it, i) {
      s.appendChild(sv('rect', { x: M.l + i * step, y: H - 13, width: 10, height: 8, fill: it[1], opacity: it[2] || 1 }));
      s.appendChild(sv('text', { x: M.l + i * step + 14, y: H - 5 }, it[0]));
    });
  }
  function xtitle(s, t) { s.appendChild(sv('text', { x: (M.l + W - M.r) / 2, y: H - M.b + 28, 'text-anchor': 'middle', style: 'text-transform:uppercase;font-size:9px' }, t)); }
  function ytitle(s, t) { s.appendChild(sv('text', { x: 12, y: (M.t + H - M.b) / 2, 'text-anchor': 'middle', transform: 'rotate(-90 12 ' + ((M.t + H - M.b) / 2) + ')', style: 'text-transform:uppercase;font-size:9px' }, t)); }
  function path(pts) { return pts.map(function (p, i) { return (i ? 'L' : 'M') + p[0].toFixed(1) + ',' + p[1].toFixed(1); }).join(' '); }
  function bars(label, names, series, signed) {
    var s = frame(label);
    var all = [0];
    series.forEach(function (sr) { all = all.concat(sr.v.map(function (v) { return num(v) || 0; })); });
    var lo = signed ? Math.min.apply(null, all) : 0, hi = Math.max.apply(null, all);
    if (hi === lo) hi = lo + 1;
    var y = yaxis(s, lo, hi, fmt);
    var n = names.length, bw = (W - M.l - M.r) / Math.max(n, 1), k = series.length;
    names.forEach(function (nm, i) {
      series.forEach(function (sr, j) {
        var v = num(sr.v[i]) || 0, x = M.l + i * bw + bw * 0.1 + j * bw * 0.8 / k;
        var r = sv('rect', { x: x, width: Math.max(bw * 0.8 / k, 0.5), y: Math.min(y(v), y(0)),
          height: Math.abs(y(v) - y(0)), fill: typeof sr.col === 'function' ? sr.col(v, i) : sr.col });
        r.appendChild(sv('title', {}, nm + ': ' + sr.name + ' ' + fmt(v)));
        s.appendChild(r);
      });
      var room = Math.floor(bw / 5.5);
      if (room >= 2) s.appendChild(sv('text', { x: M.l + (i + 0.5) * bw, y: H - M.b + 12, 'text-anchor': 'middle' }, short(nm, room)));
    });
    legend(s, series.filter(function (sr) { return typeof sr.col !== 'function'; }).map(function (sr) { return [sr.name, sr.col]; }));
    return s;
  }
  function chart(id, svg) {
    var box = $(id);
    box.textContent = '';
    if (!svg) return;
    box.appendChild(svg);
    var a = el('a', { href: '#', download: id + '.svg', 'class': 'svgdl' }, 'SVG');
    a.addEventListener('click', function () {
      a.href = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(new XMLSerializer().serializeToString(svg));
    });
    box.appendChild(a);
  }

  // ---- per-column charts --------------------------------------------------------------------------
  // densities overlaid, the area between them shaded: where the current sample gained mass and lost it
  function densityChart(c) {
    var d = c.dens, x = arr(d.x), a = arr(d.ref), b = arr(d.cur);
    var s = frame('Densities of ' + c.column + ', reference against current, the area between shaded');
    var top = Math.max.apply(null, a.concat(b).concat([1e-12]));
    var y = yaxis(s, 0, top, function () { return ''; });
    var X = scale(x[0], x[x.length - 1], M.l, W - M.r);
    var ra = a.map(function (v, i) { return [X(x[i]), y(v)]; }), rb = b.map(function (v, i) { return [X(x[i]), y(v)]; });
    s.appendChild(sv('path', { d: path(ra) + ' L' + X(x[x.length - 1]) + ',' + y(0) + ' L' + X(x[0]) + ',' + y(0) + ' Z', fill: col('ref'), 'fill-opacity': 0.12 }));
    s.appendChild(sv('path', { d: path(rb) + ' L' + X(x[x.length - 1]) + ',' + y(0) + ' L' + X(x[0]) + ',' + y(0) + ' Z', fill: col('curfill'), 'fill-opacity': 0.5 }));
    s.appendChild(sv('path', { d: path(ra) + ' ' + path(rb.slice().reverse()).replace(/^M/, 'L') + ' Z', fill: col('div'), 'fill-opacity': 0.45 }));
    s.appendChild(sv('path', { d: path(ra), fill: 'none', stroke: col('ref'), 'stroke-width': 2 }));
    s.appendChild(sv('path', { d: path(rb), fill: 'none', stroke: col('cur'), 'stroke-width': 2 }));
    s.appendChild(sv('text', { x: M.l, y: H - M.b + 12 }, val(c, x[0])));
    s.appendChild(sv('text', { x: W - M.r, y: H - M.b + 12, 'text-anchor': 'end' }, val(c, x[x.length - 1])));
    legend(s, [['reference', col('ref'), 0.4], ['current', col('curfill')], ['between', col('div'), 0.6]]);
    xtitle(s, 'value');
    ytitle(s, 'density');
    return s;
  }
  // a flow from the reference's shares (left) to the current's (right), one ribbon per category
  function sankey(c) {
    var b = c.bins, nm = arr(b.bin), a = arr(b.ref), q = arr(b.cur), t = arr(b.contrib);
    var s = frame('Category shares of ' + c.column + ', reference on the left flowing to current on the right');
    var top = M.t, bot = H - 30, x0 = 120, x1 = W - 120, gapY = 3;
    var hh = bot - top - gapY * (nm.length - 1);
    var ya = top, yb = top;
    var hues = [col('ref'), col('cur'), col('ok'), col('warn'), col('div'), col('untested')];
    nm.forEach(function (k, i) {
      var ha = Math.max(0, (num(a[i]) || 0) * hh), hb = Math.max(0, (num(q[i]) || 0) * hh);
      var c1 = hues[i % hues.length], mid = (x0 + x1) / 2;
      var d = 'M' + x0 + ',' + ya + ' C' + mid + ',' + ya + ' ' + mid + ',' + yb + ' ' + x1 + ',' + yb +
        ' L' + x1 + ',' + (yb + hb) + ' C' + mid + ',' + (yb + hb) + ' ' + mid + ',' + (ya + ha) + ' ' + x0 + ',' + (ya + ha) + ' Z';
      var p = sv('path', { d: d, fill: c1, 'fill-opacity': 0.28 + Math.min(0.5, (num(t[i]) || 0) * 2), stroke: c1, 'stroke-opacity': 0.5 });
      p.appendChild(sv('title', {}, k + ': ' + pct(a[i]) + ' \u2192 ' + pct(q[i]) + ', PSI term ' + fmt(t[i])));
      s.appendChild(p);
      s.appendChild(sv('rect', { x: x0 - 8, y: ya, width: 8, height: Math.max(ha, 0.5), fill: c1 }));
      s.appendChild(sv('rect', { x: x1, y: yb, width: 8, height: Math.max(hb, 0.5), fill: c1 }));
      if (ha > 9) s.appendChild(sv('text', { x: x0 - 12, y: ya + ha / 2 + 3, 'text-anchor': 'end' }, short(k, 12) + ' ' + pct(a[i])));
      if (hb > 9) s.appendChild(sv('text', { x: x1 + 12, y: yb + hb / 2 + 3 }, pct(q[i]) + ' ' + short(k, 12)));
      ya += ha + gapY;
      yb += hb + gapY;
    });
    s.appendChild(sv('text', { x: x0 - 8, y: H - 10, 'text-anchor': 'middle' }, 'reference'));
    s.appendChild(sv('text', { x: x1 + 4, y: H - 10, 'text-anchor': 'middle' }, 'current'));
    return s;
  }
  function histogram(c) {
    var h = c.hist, lo = arr(h.lo), hi = arr(h.hi), r = arr(h.ref), q = arr(h.cur);
    var s = frame('Distribution of ' + c.column + ': reference against current');
    var top = Math.max.apply(null, r.concat(q).concat([1e-9]));
    var y = yaxis(s, 0, top, pct);
    var x0 = lo[0], x1 = hi[hi.length - 1], X = scale(x0, x1, M.l, W - M.r);
    [[r, col('ref'), 0.25], [q, col('cur'), 0]].forEach(function (sr) {
      var d = 'M' + X(x0) + ',' + y(0);
      sr[0].forEach(function (v, i) { d += ' L' + X(lo[i]) + ',' + y(v) + ' L' + X(hi[i]) + ',' + y(v); });
      d += ' L' + X(x1) + ',' + y(0);
      s.appendChild(sv('path', { d: d, fill: sr[2] ? sr[1] : 'none', 'fill-opacity': sr[2], stroke: sr[1], 'stroke-width': 2 }));
    });
    s.appendChild(sv('text', { x: M.l, y: H - M.b + 12 }, val(c, x0)));
    s.appendChild(sv('text', { x: W - M.r, y: H - M.b + 12, 'text-anchor': 'end' }, val(c, x1)));
    legend(s, [['reference', col('ref')], ['current', col('cur')]]);
    return s;
  }
  // the two ECDFs (cumulative shares for categories), the area between shaded, the largest gap marked
  function ecdfChart(c) {
    var x, a, b, labels = null;
    if (c.ecdf) { x = arr(c.ecdf.x); a = arr(c.ecdf.ref); b = arr(c.ecdf.cur); } else {
      labels = arr(c.bins.bin);
      x = labels.map(function (_l, i) { return i; });
      var ca = 0, cb = 0;
      a = arr(c.bins.ref).map(function (v) { ca += num(v) || 0; return ca; });
      b = arr(c.bins.cur).map(function (v) { cb += num(v) || 0; return cb; });
    }
    var s = frame('Cumulative shares of ' + c.column + ', reference against current');
    var y = yaxis(s, 0, 1, pct);
    var X = scale(x[0], x[x.length - 1] === x[0] ? x[0] + 1 : x[x.length - 1], M.l, W - M.r);
    var step = function (v) { var p = []; v.forEach(function (q, i) { if (i) p.push([X(x[i]), y(v[i - 1])]); p.push([X(x[i]), y(q)]); }); return p; };
    var sa = step(a), sb = step(b);
    s.appendChild(sv('path', { d: path(sa) + ' ' + path(sb.slice().reverse()).replace(/^M/, 'L') + ' Z', fill: col('div'), 'fill-opacity': 0.35 }));
    s.appendChild(sv('path', { d: path(sa), fill: 'none', stroke: col('ref'), 'stroke-width': 2 }));
    s.appendChild(sv('path', { d: path(sb), fill: 'none', stroke: col('cur'), 'stroke-width': 2 }));
    var k = 0;
    a.forEach(function (v, i) { if (Math.abs(v - b[i]) > Math.abs(a[k] - b[k])) k = i; });
    s.appendChild(sv('line', { x1: X(x[k]), x2: X(x[k]), y1: y(a[k]), y2: y(b[k]), stroke: col('ink'), 'stroke-width': 2, 'stroke-dasharray': '3 3' }));
    s.appendChild(sv('text', { x: X(x[k]) + 4, y: (y(a[k]) + y(b[k])) / 2 }, 'gap ' + fmt(Math.abs(a[k] - b[k]))));
    if (labels) {
      labels.forEach(function (l, i) { if (labels.length <= 10) s.appendChild(sv('text', { x: X(i), y: H - M.b + 12, 'text-anchor': 'middle' }, short(l, 8))); });
    } else {
      s.appendChild(sv('text', { x: M.l, y: H - M.b + 12 }, val(c, x[0])));
      s.appendChild(sv('text', { x: W - M.r, y: H - M.b + 12, 'text-anchor': 'end' }, val(c, x[x.length - 1])));
    }
    legend(s, [['reference', col('ref')], ['current', col('cur')], ['between', col('div'), 0.6]]);
    xtitle(s, labels ? 'category' : 'value');
    ytitle(s, 'share at or below');
    return s;
  }
  // reference quantile across, current quantile up: on the dashed line nothing moved
  function qqChart(c) {
    var q = c.qq, a = arr(q.ref), b = arr(q.cur), p = arr(q.p);
    var all = a.concat(b).map(num), lo = Math.min.apply(null, all), hi = Math.max.apply(null, all);
    if (hi === lo) hi = lo + 1;
    var s = frame('Quantile shift of ' + c.column + ': reference quantiles across, current up');
    var y = yaxis(s, lo, hi, function (v) { return val(c, v); });
    var X = scale(lo, hi, M.l, W - M.r);
    s.appendChild(sv('line', { x1: X(lo), y1: y(lo), x2: X(hi), y2: y(hi), stroke: col('dim'), 'stroke-dasharray': '5 4' }));
    s.appendChild(sv('path', { d: path(a.map(function (v, i) { return [X(v), y(b[i])]; })), fill: 'none', stroke: col('cur'), 'stroke-width': 2 }));
    a.forEach(function (v, i) {
      var pt = sv('circle', { cx: X(v), cy: y(b[i]), r: 3.2, fill: Math.abs(b[i] - v) > (hi - lo) * 0.05 ? col('div') : col('cur') });
      pt.appendChild(sv('title', {}, 'quantile ' + fmt(p[i]) + ': ' + val(c, v) + ' \u2192 ' + val(c, b[i])));
      s.appendChild(pt);
    });
    s.appendChild(sv('text', { x: M.l, y: H - M.b + 12 }, val(c, lo)));
    s.appendChild(sv('text', { x: W - M.r, y: H - M.b + 12, 'text-anchor': 'end' }, val(c, hi)));
    xtitle(s, 'reference quantile');
    ytitle(s, 'current quantile');
    return s;
  }
  function benfordChart(c) {
    var bf = c.benford, n = bf.n, nr = arr(bf.ref).reduce(function (a, x) { return a + x; }, 0) || 1;
    var bd = bf.band || {}, lo = arr(bd.lower), up = arr(bd.upper);
    var e = [1, 2, 3, 4, 5, 6, 7, 8, 9].map(function (d) { return Math.log10(1 + 1 / d); });
    var curv = arr(bf.cur).map(function (k) { return k / n; }), refv = arr(bf.ref).map(function (k) { return k / nr; });
    var s = bars('First digits of ' + c.column + ' against Benford (p ' + peq(bf.p_value) + ')',
      ['1', '2', '3', '4', '5', '6', '7', '8', '9'], [{ name: 'current', v: curv, col: col('curfill') }]);
    var top = Math.max.apply(null, e.concat(curv, up.length ? up : []));
    var y = scale(0, top, H - M.b, M.t), bw = (W - M.l - M.r) / 9, xm = function (i) { return M.l + (i + 0.5) * bw; };
    if (lo.length === 9) {
      var band = lo.map(function (v, i) { return [xm(i), y(v)]; }).concat(up.map(function (v, i) { return [xm(i), y(v)]; }).reverse());
      s.appendChild(sv('path', { d: path(band) + ' Z', fill: col('ink'), 'fill-opacity': 0.12 }));
    }
    s.appendChild(sv('path', { d: path(e.map(function (v, i) { return [xm(i), y(v)]; })), fill: 'none', stroke: col('ink'), 'stroke-width': 2, 'stroke-dasharray': '4 3' }));
    refv.forEach(function (v, i) { s.appendChild(sv('circle', { cx: xm(i), cy: y(v), r: 3.5, fill: col('ref'), stroke: '#ffffff' })); });
    s.appendChild(sv('text', { x: W - M.r, y: M.t + 10, 'text-anchor': 'end' },
      (num(bf.p_value) < S.alpha ? 'departs from' : 'consistent with') + ' Benford \u00b7 band 95%'));
    legend(s, [['current', col('curfill')], ['reference', col('ref')], ['Benford', col('ink'), 0.5]]);
    return s;
  }
  function summaryTable(c) {
    var th = document.querySelector('#sumtable thead'), tb = document.querySelector('#sumtable tbody');
    th.textContent = '';
    tb.textContent = '';
    var rows = [['n', c.nref, c.ncur], ['missing', pct(c.missref), pct(c.misscur)]];
    if (c.stats) {
      arr(c.stats.stat).forEach(function (k, i) { rows.push([k, val(c, arr(c.stats.ref)[i], k), val(c, arr(c.stats.cur)[i], k)]); });
    } else if (c.top) {
      arr(c.top.category).forEach(function (k, i) { rows.push([k, pct(arr(c.top.ref)[i]), pct(arr(c.top.cur)[i])]); });
    }
    var hr = el('tr');
    ['', 'reference', 'current'].forEach(function (h) { hr.appendChild(el('th', { scope: 'col' }, h)); });
    th.appendChild(hr);
    rows.forEach(function (r) {
      var tr = el('tr');
      tr.appendChild(el('th', { scope: 'row' }, r[0]));
      tr.appendChild(el('td', { 'class': 'num' }, r[1] == null ? '\u2014' : String(r[1])));
      tr.appendChild(el('td', { 'class': 'num' }, r[2] == null ? '\u2014' : String(r[2])));
      tb.appendChild(tr);
    });
  }
  function median(c, side) {
    if (!c.stats) return null;
    var k = arr(c.stats.stat).indexOf('median');
    return k < 0 ? null : num(arr(c.stats[side])[k]);
  }
  // one figure: its title, the chart at its card's width, and a line on how to read it
  function figure(id, title, height, draw, reading) {
    var box = $('fig-' + id);
    box.hidden = !draw;
    if (!draw) return;
    $('t-' + id).textContent = title;
    sized('chart-' + id, height);
    chart('chart-' + id, draw());
    $('r-' + id).textContent = reading;
  }
  function detail() {
    if (S.sel < 0) return;
    var c = COLS[S.sel], v = verdict(c);
    $('detail-title').textContent = 'Column detail: ' + c.column + ' (' + MARK[v] + ')';
    $('note').textContent = note(c, v);
    summaryTable(c);
    var b = c.bins, nm = b ? arr(b.bin) : [], ref = b ? arr(b.ref) : [], cur = b ? arr(b.cur) : [], ct = b ? arr(b.contrib) : [];
    var big = 0, mv = 0;
    ct.forEach(function (t, k) { if ((num(t) || 0) > (num(ct[big]) || 0)) big = k; });
    cur.forEach(function (q, k) { if (Math.abs((num(q) || 0) - (num(ref[k]) || 0)) > Math.abs((num(cur[mv]) || 0) - (num(ref[mv]) || 0))) mv = k; });
    var m0 = median(c, 'ref'), m1 = median(c, 'cur');
    figure('cmp', 'Density overlay', 300, (c.dens || c.hist) ? function () { return c.dens ? densityChart(c) : histogram(c); } : null,
      m0 == null ? 'Shaded: where the two distributions differ.' :
        'The median moved from ' + val(c, m0) + ' to ' + val(c, m1) + '; the shaded band is where the densities differ.');
    figure('flow', 'Category flow', 300, (!c.dens && !c.hist && b) ? function () { return sankey(c); } : null,
      nm.length ? 'Largest move: ' + nm[mv] + ', ' + pct(ref[mv]) + ' to ' + pct(cur[mv]) + '. Ribbons run from the reference share to the current one.' : '');
    figure('ecdf', 'ECDF overlay', 300, b ? function () { return ecdfChart(c); } : null,
      'The dotted line marks the largest vertical gap' + (c.test === 'KS' ? ', the KS statistic D = ' + fmt(c.statistic) : '') + '.');
    var q = c.qq, k50 = q ? arr(q.p).map(num).indexOf(0.5) : -1;
    figure('qq', 'Quantile shift', 300, q ? function () { return qqChart(c); } : null,
      q && k50 >= 0 ? 'On the dashed line nothing moved; the median quantile went from ' + val(c, arr(q.ref)[k50]) + ' to ' + val(c, arr(q.cur)[k50]) + '.' :
        'On the dashed line nothing moved; points above it are larger now.');
    figure('psi', 'PSI by bin', 230, b ? function () {
      var signed = ct.map(function (t, k) { return (num(cur[k]) >= num(ref[k]) ? 1 : -1) * (num(t) || 0); });
      return bars('PSI of ' + c.column + ' by bin, up where the current sample has more', nm,
        [{ name: 'PSI term', v: signed, col: function (t) { return t >= 0 ? col('cur') : col('ref'); } }], true);
    } : null, nm.length ? 'Bin ' + nm[big] + ' adds most: ' + fmt(ct[big]) + ' of the PSI of ' + fmt(c.psi) + '; up where the current sample has more.' : '');
    figure('benford', 'Benford first digits', 230, c.benford ? function () { return benfordChart(c); } : null,
      c.benford ? 'Bars: current; points: reference; dashed curve and band: Benford expected with 95% band (p ' + peq(c.benford.p_value) + ').' : '');
  }
  function select(i, focus) {
    S.sel = i;
    table();
    detail();
    heroShow(COLS[i]);
    if (focus !== false) {
      var tr = document.querySelector('#coltable tbody tr[data-i="' + i + '"]');
      if (tr) tr.focus();
    }
  }

  // ---- the fingerprint and the small multiples ----------------------------------------------
  function fingerprint() {
    var n = COLS.length, R = 150, cx = 220, cy = 190;
    var psis = COLS.map(function (c) { return num(c.psi) || 0; });
    var cap = Math.max(2 * S.fail, Math.max.apply(null, psis.concat([1e-9])));
    var s = frame('Drift fingerprint: each column a spoke at its PSI; rings at the warn and fail bands', 440, 380);
    var circle = function (r, st) { s.appendChild(sv('circle', { cx: cx, cy: cy, r: r, fill: 'none', stroke: st.c, 'stroke-dasharray': st.d || '', 'stroke-width': st.w || 1 })); };
    s.appendChild(sv('circle', { cx: cx, cy: cy, r: R, fill: col('goodbg'), 'fill-opacity': 0.6 }));
    circle(R * Math.sqrt(S.warn / cap), { c: col('warn'), d: '5 4', w: 1.5 });
    circle(R * Math.sqrt(S.fail / cap), { c: col('fail'), d: '5 4', w: 1.5 });
    var ang = function (i) { return -Math.PI / 2 + 2 * Math.PI * i / Math.max(n, 1); };
    var pts = psis.map(function (q, i) { var r = R * Math.sqrt(Math.min(q, cap) / cap); return [cx + r * Math.cos(ang(i)), cy + r * Math.sin(ang(i))]; });
    for (var sp = 0; sp < n; sp++) {
      s.appendChild(sv('line', { x1: cx, y1: cy, x2: cx + R * Math.cos(ang(sp)), y2: cy + R * Math.sin(ang(sp)), stroke: col('rule') }));
    }
    if (n > 2) s.appendChild(sv('path', { d: path(pts) + ' Z', fill: col('curfill'), 'fill-opacity': 0.35, stroke: col('cur'), 'stroke-width': 1.5 }));
    COLS.forEach(function (c, i) {
      var v = verdict(c), g = sv('g', { tabindex: '0', role: 'button', 'aria-label': c.column + ', ' + v + ', PSI ' + fmt(c.psi) });
      g.appendChild(sv('circle', { cx: pts[i][0], cy: pts[i][1], r: i === S.sel ? 7 : 5.5, fill: col(v === 'untested' ? 'untested' : v), stroke: '#ffffff', 'stroke-width': 1.5 }));
      g.appendChild(sv('title', {}, c.column + ': PSI ' + fmt(c.psi) + ' (' + v + ')'));
      var lx = cx + (R + 12) * Math.cos(ang(i)), ly = cy + (R + 12) * Math.sin(ang(i));
      g.appendChild(sv('text', { x: lx, y: ly + 3, 'text-anchor': Math.cos(ang(i)) > 0.2 ? 'start' : (Math.cos(ang(i)) < -0.2 ? 'end' : 'middle') }, short(c.column, 14)));
      var go = function () { showTab('columns'); select(i); };
      g.addEventListener('click', go);
      g.addEventListener('keydown', function (ev) { if (ev.key === 'Enter' || ev.key === ' ') { ev.preventDefault(); go(); } });
      s.appendChild(g);
    });
    s.appendChild(sv('text', { x: 8, y: 370 }, 'rings: warn ' + fmt(S.warn) + ', fail ' + fmt(S.fail) + '; edge PSI ' + fmt(cap) + ' (square-root scale)'));
    var box = $('fingerprint');
    box.textContent = '';
    box.appendChild(s);
  }
  function multiples() {
    var box = $('multiples');
    box.textContent = '';
    order().forEach(function (i) {
      var c = COLS[i], v = verdict(c);
      var b = el('button', { type: 'button', 'class': 'tile ' + v, 'aria-label': c.column + ', ' + v + ', PSI ' + fmt(c.psi) });
      b.appendChild(el('b', {}, c.column));
      b.appendChild(el('span', {}, MARK[v] + ' \u00b7 PSI ' + fmt(c.psi)));
      var shape = heroShape(c);
      if (shape) {
        var w = 160, h = 46, s = sv('svg', { viewBox: '0 0 ' + w + ' ' + h, 'aria-hidden': 'true' });
        var top = Math.max.apply(null, shape.a.concat(shape.b).map(function (q) { return num(q) || 0; }).concat([1e-12]));
        var n = shape.a.length, X = function (k) { return n > 1 ? 2 + (w - 4) * k / (n - 1) : w / 2; }, Y = function (q) { return h - 2 - (num(q) || 0) / top * (h - 6); };
        if (shape.kind === 'dens') {
          s.appendChild(sv('path', { d: path(shape.b.map(function (q, k) { return [X(k), Y(q)]; })) + ' L' + X(n - 1) + ',' + (h - 2) + ' L2,' + (h - 2) + ' Z', fill: col('curfill'), 'fill-opacity': 0.6 }));
          s.appendChild(sv('path', { d: path(shape.a.map(function (q, k) { return [X(k), Y(q)]; })), fill: 'none', stroke: col('ref'), 'stroke-width': 1.5 }));
        } else {
          var bw = (w - 4) / n;
          shape.a.forEach(function (q, k) {
            s.appendChild(sv('rect', { x: 2 + k * bw + bw * 0.1, y: Y(q), width: bw * 0.38, height: h - 2 - Y(q), fill: col('ref'), 'fill-opacity': 0.35 }));
            s.appendChild(sv('rect', { x: 2 + k * bw + bw * 0.5, y: Y(shape.b[k]), width: bw * 0.38, height: h - 2 - Y(shape.b[k]), fill: col('curfill') }));
          });
        }
        b.appendChild(s);
      }
      b.addEventListener('click', function () { showTab('columns'); select(i); });
      box.appendChild(b);
    });
  }

  // ---- bands ---------------------------------------------------------------------------------
  function bands() {
    ['warn', 'fail', 'alpha'].forEach(function (k) {
      var inp = $(k);
      if (k !== 'alpha') inp.max = String(Math.max(1, 2 * B0.fail));
      inp.value = String(S[k]);
      $(k + '-v').textContent = fmt(S[k]);
      inp.oninput = function () {
        S[k] = Number(inp.value);
        if (k === 'warn' && S.warn > S.fail) S.fail = S.warn;
        if (k === 'fail' && S.fail < S.warn) S.warn = S.fail;
        refresh();
      };
    });
  }
  function refresh() {
    ['warn', 'fail', 'alpha'].forEach(function (k) { $(k).value = String(S[k]); $(k + '-v').textContent = fmt(S[k]); });
    header();
    table();
    detail();
    heroStat();
    fingerprint();
    multiples();
    if (S.runs.length) heatmap(S.runs);
    exports();
  }

  // ---- manifest: the table and the before/after tree ------------------------------------------------
  function manifest() {
    var m = D.manifest;
    if (!m) return;
    var keys = Object.keys(m), n = keys.length ? arr(m[keys[0]]).length : 0;
    if (!n) return;
    $('tab-manifest').hidden = false;
    var hr = el('tr');
    keys.forEach(function (k) { hr.appendChild(el('th', { scope: 'col' }, k)); });
    document.querySelector('#manifest thead').appendChild(hr);
    for (var i = 0; i < n; i++) {
      var tr = el('tr');
      keys.forEach(function (k) {
        var x = arr(m[k])[i], v = x == null ? '\u2014' : String(x);
        tr.appendChild(el('td', /sha256/.test(k) ? { title: v } : {}, /sha256/.test(k) ? v.slice(0, 12) : v));
      });
      document.querySelector('#manifest tbody').appendChild(tr);
    }
    manifestTree(m, n);
  }
  function manifestTree(m, n) {
    var res = arr(m.resource), ch = arr(m.change), os = arr(m.old_sha256), ns = arr(m.new_sha256);
    var w = Math.max(340, $('manifest-tree').clientWidth || 760), L = w * 0.22, Rr = w * 0.78, lw = Math.min(190, w * 0.4);
    var rowH = 30, h = 60 + n * rowH, s = frame('Manifest before and after: ' + n + ' resources', w, h);
    var colour = { unchanged: col('untested'), changed: col('fail'), added: col('ok'), removed: col('warn') };
    var root = function (x, label) {
      s.appendChild(sv('rect', { x: x - 60, y: 8, width: 120, height: 24, rx: 4, fill: col('ink') }));
      s.appendChild(sv('text', { x: x, y: 24, 'text-anchor': 'middle', style: 'fill:' + col('ground') + ';font-size:11px;text-transform:uppercase' }, label));
    };
    root(L, 'before');
    root(Rr, 'after');
    for (var i = 0; i < n; i++) {
      var y = 52 + i * rowH, c = colour[ch[i]] || col('untested');
      var leaf = function (x, sha, side) {
        if (!sha) return;
        var rx = side ? Rr : L;
        s.appendChild(sv('path', { d: 'M' + rx + ',32 C' + rx + ',' + (y - 8) + ' ' + x + ',' + (y - 14) + ' ' + x + ',' + (y - 9), fill: 'none', stroke: col('rule') }));
        s.appendChild(sv('rect', { x: x - lw / 2, y: y - 9, width: lw, height: 20, rx: 3, fill: c, 'fill-opacity': ch[i] === 'unchanged' ? 0.25 : 0.85 }));
        s.appendChild(sv('text', { x: x, y: y + 5, 'text-anchor': 'middle', style: 'font-size:10px;fill:' + (ch[i] === 'unchanged' ? col('ink') : '#ffffff') }, short(res[i], Math.max(4, Math.floor(lw / 6) - 9)) + ' ' + String(sha).slice(0, 8)));
      };
      leaf(L, os[i], false);
      leaf(Rr, ns[i], true);
      s.appendChild(sv('text', { x: w / 2, y: y + 5, 'text-anchor': 'middle', style: 'text-transform:uppercase' }, ch[i]));
    }
    var box = $('manifest-tree');
    box.textContent = '';
    box.appendChild(s);
  }

  // ---- history: the heatmap of column by run, and the PSI of each column over runs -----------------
  function historyRuns(texts) {
    var runs = [];
    texts.forEach(function (t) {
      var j;
      try { j = JSON.parse(t.text); } catch (e) { return; }
      var cs = j.columns ? arr(j.columns) : [].concat.apply([], arr(j.capsules).map(function (cp) {
        return cp && cp.drift ? arr(cp.drift.columns) : [];
      }));
      if (cs.length) runs.push({ name: t.name, cols: cs });
    });
    runs.sort(function (a, b) { return a.name.localeCompare(b.name); });
    return runs;
  }
  function names(runs) {
    var out = [];
    runs.forEach(function (r) { r.cols.forEach(function (c) { if (out.indexOf(c.column) < 0) out.push(c.column); }); });
    return out;
  }
  function psiOf(r, nm) {
    var c = r.cols.filter(function (x) { return x.column === nm; })[0];
    return c ? num(c.psi) : null;
  }
  function heatmap(runs) {
    var nm = names(runs), cw = Math.max(34, Math.min(70, 560 / Math.max(runs.length, 1))), rh = 24, lw = 130;
    var w = lw + runs.length * cw + 10, h = 40 + nm.length * rh;
    var s = frame('PSI of each column over ' + runs.length + ' runs, coloured by band', w, h);
    runs.forEach(function (r, j) { s.appendChild(sv('text', { 'aria-label': r.name, x: lw + (j + 0.5) * cw, y: 14, 'text-anchor': 'middle' }, String(j + 1))); });
    nm.forEach(function (n, i) {
      var y = 22 + i * rh, crossed = false;
      s.appendChild(sv('text', { x: lw - 6, y: y + rh / 2 + 3, 'text-anchor': 'end' }, short(n, 18)));
      runs.forEach(function (r, j) {
        var p = psiOf(r, n), b = band(p), x = lw + j * cw;
        var cell = sv('rect', { x: x + 1, y: y + 1, width: cw - 2, height: rh - 2, fill: col(b), 'fill-opacity': b === 'untested' ? 0.2 : 0.8 });
        cell.appendChild(sv('title', {}, n + ', run ' + (j + 1) + ' (' + r.name + '): PSI ' + fmt(p) + ', ' + b));
        s.appendChild(cell);
        s.appendChild(sv('text', { x: x + cw / 2, y: y + rh / 2 + 3, 'text-anchor': 'middle', style: 'fill:#ffffff;font-size:9px' }, p == null ? '' : fmt(p)));
        if (b === 'fail' && !crossed) {
          crossed = true;
          s.appendChild(sv('rect', { x: x + 1, y: y + 1, width: cw - 2, height: rh - 2, fill: 'none', stroke: col('ink'), 'stroke-width': 2 }));
        }
      });
    });
    var box = $('heatmap');
    box.textContent = '';
    box.appendChild(s);
  }
  function historyPlots(runs) {
    var box = $('history-plots');
    box.textContent = '';
    names(runs).forEach(function (nm) {
      var v = runs.map(function (r) { return psiOf(r, nm); });
      var s = frame('PSI of ' + nm + ' over ' + runs.length + ' runs');
      var top = Math.max.apply(null, v.filter(function (x) { return x != null; }).concat([S.fail * 1.1]));
      var y = yaxis(s, 0, top, fmt);
      var x = function (i) { return M.l + (W - M.l - M.r) * (runs.length > 1 ? i / (runs.length - 1) : 0.5); };
      [['warn', S.warn], ['fail', S.fail]].forEach(function (b) {
        s.appendChild(sv('line', { x1: M.l, x2: W - M.r, y1: y(b[1]), y2: y(b[1]), stroke: col(b[0]), 'stroke-dasharray': '4 3' }));
      });
      var pts = v.map(function (p, i) { return p == null ? null : [x(i), y(p)]; }).filter(Boolean);
      if (pts.length) s.appendChild(sv('path', { d: path(pts), fill: 'none', stroke: col('cur'), 'stroke-width': 2 }));
      v.forEach(function (p, i) {
        if (p == null) return;
        var c = sv('circle', { cx: x(i), cy: y(p), r: p > S.fail ? 5 : 3, fill: p > S.fail ? col('fail') : col('cur') });
        c.appendChild(sv('title', {}, runs[i].name + ': PSI ' + fmt(p)));
        s.appendChild(c);
      });
      var f = el('figure');
      f.appendChild(el('figcaption', {}, nm));
      f.appendChild(s);
      box.appendChild(f);
    });
  }
  function historyInput() {
    $('hist-file').addEventListener('change', function (ev) {
      var files = Array.prototype.slice.call(ev.target.files), texts = [];
      files.forEach(function (f) {
        var rd = new FileReader();
        rd.onload = function () {
          texts.push({ name: f.name, text: String(rd.result) });
          if (texts.length === files.length) {
            S.runs = historyRuns(texts);
            heatmap(S.runs);
            historyPlots(S.runs);
          }
        };
        rd.readAsText(f);
      });
    });
  }

  // ---- exports, tabs, keys, theme ---------------------------------------------------------------
  function markdown() {
    var n = { ok: 0, warn: 0, fail: 0, untested: 0 };
    var idx = order();
    idx.forEach(function (i) { n[verdict(COLS[i])]++; });
    var esc = function (s) { return String(s).replace(/\|/g, '\\|'); };
    return ['## Drift: ' + n.fail + ' fail, ' + n.warn + ' warn, ' + n.ok + ' ok, ' + n.untested + ' untested', '',
      'Rows ' + D.nref + ' -> ' + D.ncur + '; PSI bands warn ' + fmt(S.warn) + ', fail ' + fmt(S.fail) + '; alpha ' + fmt(S.alpha) + '.', '',
      '| verdict | column | type | test | PSI | p-value |', '|---|---|---|---|---|---|'].concat(idx.map(function (i) {
      var c = COLS[i];
      return '| ' + MARK[verdict(c)] + ' | ' + esc(c.column) + ' | ' + c.type + ' | ' + c.test + ' | ' + fmt(c.psi) + ' | ' + fmt(c.p_value) + ' |';
    })).join('\n');
  }
  function exports() {
    $('dl-md').href = 'data:text/markdown;charset=utf-8,' + encodeURIComponent(markdown());
    var out = JSON.parse(JSON.stringify(D));
    out.bands = { warn: S.warn, fail: S.fail };
    out.alpha = S.alpha;
    arr(out.columns).forEach(function (c, i) { c.verdict = verdict(COLS[i]); });
    $('dl-json').href = 'data:application/json;charset=utf-8,' + encodeURIComponent(JSON.stringify(out, null, 2));
  }
  function copyGh() {
    $('copy-gh').addEventListener('click', function () {
      var txt = markdown() + '\n\n<sub>rmoriebricklayer ' + D.version + ' drift report</sub>';
      var done = function () { $('copied').textContent = 'copied'; };
      // without the clipboard (a file:// page in some browsers), the text is shown selected to copy by hand
      var byHand = function () {
        var ta = $('gh-text') || el('textarea', { id: 'gh-text', rows: '8', 'aria-label': 'GitHub comment' });
        ta.value = txt;
        $('copied').parentNode.appendChild(ta);
        ta.focus();
        ta.select();
        $('copied').textContent = 'selected: copy it with Ctrl+C or Cmd+C';
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(txt).then(done, byHand);
      } else {
        byHand();
      }
    });
  }
  var TABS = ['columns', 'overview', 'manifest', 'history', 'chain'];
  function showTab(t) {
    TABS.forEach(function (u) {
      $('pane-' + u).hidden = u !== t;
      $('tab-' + u).setAttribute('aria-selected', String(u === t));
    });
    // a pane drawn while hidden had no width: draw it again at its own
    if (t === 'overview') { fingerprint(); multiples(); }
    if (t === 'columns') detail();
    if (t === 'chain') chain();
    if (t === 'manifest' && D.manifest) manifestTree(D.manifest, arr(D.manifest[Object.keys(D.manifest)[0]]).length);
  }
  function tabs() {
    TABS.forEach(function (t) { $('tab-' + t).addEventListener('click', function () { showTab(t); }); });
  }
  function keys() {
    document.addEventListener('keydown', function (ev) {
      var tag = (ev.target.tagName || '').toLowerCase();
      if (ev.key === '/' && tag !== 'input') {
        ev.preventDefault();
        showTab('columns');
        $('search').focus();
        return;
      }
      if ((ev.key === 'ArrowDown' || ev.key === 'ArrowUp') && tag !== 'input' && !$('pane-columns').hidden) {
        var v = visible();
        if (!v.length) return;
        ev.preventDefault();
        var at = v.indexOf(S.sel);
        at = ev.key === 'ArrowDown' ? Math.min(v.length - 1, at + 1) : Math.max(0, at - 1);
        select(v[at]);
      }
    });
    $('search').addEventListener('input', function (ev) { S.q = ev.target.value; table(); });
  }
  function redraw() {
    heroPaint();
    chain();
    refresh();
    if (D.manifest) manifestTree(D.manifest, arr(D.manifest[Object.keys(D.manifest)[0]]).length);
    if (S.runs.length) historyPlots(S.runs);
  }
  function theme() {
    var root = document.documentElement;
    var dark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    $('theme').textContent = dark ? 'light theme' : 'dark theme';
    $('theme').addEventListener('click', function () {
      dark = !dark;
      root.setAttribute('data-theme', dark ? 'dark' : 'light');
      $('theme').textContent = dark ? 'light theme' : 'dark theme';
      redraw();
    });
  }
  $('reset').addEventListener('click', function () {
    S.warn = B0.warn;
    S.fail = B0.fail;
    S.alpha = B0.alpha;
    refresh();
  });
  // a new width draws every chart again at it
  var resizing = 0;
  window.addEventListener('resize', function () {
    clearTimeout(resizing);
    resizing = setTimeout(function () {
      heroPaint();
      detail();
      if (!$('pane-overview').hidden) { fingerprint(); multiples(); }
      if (!$('pane-chain').hidden) chain();
      if (!$('pane-manifest').hidden && D.manifest) manifestTree(D.manifest, arr(D.manifest[Object.keys(D.manifest)[0]]).length);
    }, 150);
  });

  provenance();
  tableHead();
  filters();
  bands();
  tabs();
  keys();
  theme();
  copyGh();
  historyInput();
  manifest();
  chain();
  var first = order().filter(function (i) { return heroShape(COLS[i]); })[0];
  S.sel = first != null ? first : (visible().length ? visible()[0] : -1);
  refresh();
  heroShow(S.sel >= 0 ? COLS[S.sel] : null);
})();
