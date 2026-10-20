// The drift report's script: drawn by rmoriebricklayer::drfthtml() into the page, reading the
// JSON in #drift-data. No library and no network: every chart is SVG built here, every value is
// set as text (never as markup), and the downloads are data: URLs made in the browser.
(function () {
  'use strict';
  var D = JSON.parse(document.getElementById('drift-data').textContent);
  var arr = function (v) { return v == null ? [] : (Array.isArray(v) ? v : [v]); };
  var $ = function (id) { return document.getElementById(id); };
  var SVGNS = 'http://www.w3.org/2000/svg';
  var COLS = arr(D.columns);
  var B0 = { warn: D.bands.warn, fail: D.bands.fail, alpha: D.alpha };
  var S = { warn: B0.warn, fail: B0.fail, alpha: B0.alpha, sel: -1, sort: 'verdict', desc: false, q: '', filt: {} };
  var RANK = { fail: 0, warn: 1, ok: 2, untested: 3 };
  var MARK = { ok: '\u2714 ok', warn: '\u26a0 warn', fail: '\u2716 fail', untested: '\u2013 untested' };
  var VCOL = { ok: '#2166AC', warn: '#E69F00', fail: '#D6604D', untested: '#8C8C8C' };
  var REF = '#0072B2', CUR = '#D55E00';

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
  function pct(v) { v = num(v); return v == null ? '\u2014' : (100 * v).toFixed(1) + '%'; }
  function verdict(c) {
    var p = num(c.p_value), psi = num(c.psi);
    var large = c.nref != null && c.ncur != null && c.nref >= D.psiminn && c.ncur >= D.psiminn;
    var v = p == null ? 'untested' : 'ok';
    if (psi != null && psi > S.warn) v = 'warn';
    if ((p != null && p < S.alpha) || (psi != null && large && psi > S.fail)) v = 'fail';
    return v;
  }
  function missChange(c) {
    return c.misscur == null || c.missref == null ? null : c.misscur - c.missref;
  }
  function note(c, v) {
    var p = num(c.p_value);
    if (v === 'fail') {
      return c.column + ' moved: ' + (p != null && p < S.alpha ?
        'the ' + c.test + ' test gives p = ' + fmt(p) + ', below alpha ' + fmt(S.alpha) :
        'its PSI of ' + fmt(c.psi) + ' is above the fail band ' + fmt(S.fail)) + '; ' + D.meaning + '.';
    }
    if (v === 'warn') {
      return c.column + ' is worth a look: its PSI of ' + fmt(c.psi) + ' is above the warn band ' +
        fmt(S.warn) + ', though the test gives p = ' + fmt(p) + '.';
    }
    if (v === 'ok') {
      return c.column + ' looks the same in both: PSI ' + fmt(c.psi) + ', below the warn band ' +
        fmt(S.warn) + ', and p = ' + fmt(p) + '.';
    }
    return c.column + ' was not tested: ' + (c.note ? c.note : 'no test applies') + '.';
  }
  function chip(v) { return el('span', { 'class': 'chip ' + v }, MARK[v]); }

  // ---- header -------------------------------------------------------------------------------
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
    var rows = [['capsule', p.name], ['source', p.url], ['pinned sha256', p.sha256 ? String(p.sha256).slice(0, 16) + '\u2026' : null],
      ['data date', p.date], ['rows', D.nref + ' reference, ' + D.ncur + ' current'], ['written', D.written],
      ['by', 'rmoriebricklayer ' + D.version]];
    rows.forEach(function (r) {
      if (r[1] == null) return;
      dl.appendChild(el('dt', {}, r[0]));
      dl.appendChild(el('dd', {}, r[1]));
    });
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
    var idx = Object.keys(COLS).map(Number).filter(function (i) {
      var c = COLS[i], v = verdict(c);
      var kinds = ['ok', 'warn', 'fail'].filter(function (k) { return S.filt[k]; });
      var types = ['numeric', 'categorical'].filter(function (k) { return S.filt[k]; });
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
      var th = el('th', { scope: 'row' }, c.column);
      tr.appendChild(th);
      tr.appendChild(el('td', {}, c.type));
      tr.appendChild(el('td', {}, c.test));
      [c.statistic, c.p_value, c.psi].forEach(function (x) { tr.appendChild(el('td', { 'class': 'num' }, fmt(x))); });
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

  // ---- charts ----------------------------------------------------------------------------------
  var W = 360, H = 200, M = { l: 40, r: 8, t: 10, b: 40 };
  function frame(label) {
    var s = sv('svg', { viewBox: '0 0 ' + W + ' ' + H, role: 'img', 'aria-label': label, xmlns: SVGNS });
    s.appendChild(sv('title', {}, label));
    return s;
  }
  function yaxis(s, lo, hi, f) {
    var y = function (v) { return M.t + (H - M.t - M.b) * (1 - (v - lo) / (hi - lo || 1)); };
    [lo, (lo + hi) / 2, hi].forEach(function (v) {
      s.appendChild(sv('line', { x1: M.l, x2: W - M.r, y1: y(v), y2: y(v), 'class': 'axis' }));
      s.appendChild(sv('text', { x: M.l - 4, y: y(v) + 3, 'text-anchor': 'end' }, f(v)));
    });
    return y;
  }
  function legend(s, items) {
    items.forEach(function (it, i) {
      s.appendChild(sv('rect', { x: M.l + i * 90, y: H - 12, width: 9, height: 9, fill: it[1] }));
      s.appendChild(sv('text', { x: M.l + i * 90 + 13, y: H - 4 }, it[0]));
    });
  }
  function bars(label, names, series, signed) {
    var s = frame(label);
    var all = [0];
    series.forEach(function (sr) { all = all.concat(sr.v.map(function (v) { return num(v) || 0; })); });
    var lo = signed ? Math.min.apply(null, all) : 0, hi = Math.max.apply(null, all);
    if (hi === lo) hi = lo + 1;
    var y = yaxis(s, lo, hi, function (v) { return fmt(v); });
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
      if (room >= 2) {
        s.appendChild(sv('text', { x: M.l + (i + 0.5) * bw, y: H - M.b + 12, 'text-anchor': 'middle' },
          String(nm).length > room ? String(nm).slice(0, room - 1) + '\u2026' : nm));
      }
    });
    legend(s, series.filter(function (sr) { return typeof sr.col !== 'function'; }).map(function (sr) { return [sr.name, sr.col]; }));
    return s;
  }
  function histogram(c) {
    var h = c.hist, lo = arr(h.lo), hi = arr(h.hi), r = arr(h.ref), q = arr(h.cur);
    var s = frame('Distribution of ' + c.column + ': reference against current');
    var top = Math.max.apply(null, r.concat(q).concat([1e-9]));
    var y = yaxis(s, 0, top, pct);
    var x0 = lo[0], x1 = hi[hi.length - 1];
    var x = function (v) { return M.l + (W - M.l - M.r) * (v - x0) / (x1 - x0 || 1); };
    [[r, REF, 0.35], [q, CUR, 0]].forEach(function (sr) {
      var d = 'M' + x(x0) + ',' + y(0);
      sr[0].forEach(function (v, i) { d += ' L' + x(lo[i]) + ',' + y(v) + ' L' + x(hi[i]) + ',' + y(v); });
      d += ' L' + x(x1) + ',' + y(0);
      s.appendChild(sv('path', { d: d, fill: sr[2] ? sr[1] : 'none', 'fill-opacity': sr[2], stroke: sr[1], 'stroke-width': 2 }));
    });
    s.appendChild(sv('text', { x: M.l, y: H - M.b + 12 }, fmt(x0)));
    s.appendChild(sv('text', { x: W - M.r, y: H - M.b + 12, 'text-anchor': 'end' }, fmt(x1)));
    legend(s, [['reference', REF], ['current', CUR]]);
    return s;
  }
  function bins(c) {
    var b = c.bins;
    return { names: arr(b.bin), ref: arr(b.ref), cur: arr(b.cur), contrib: arr(b.contrib) };
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
  function summaryTable(c) {
    var th = document.querySelector('#sumtable thead'), tb = document.querySelector('#sumtable tbody');
    th.textContent = '';
    tb.textContent = '';
    var rows = [['n', c.nref, c.ncur], ['missing', pct(c.missref), pct(c.misscur)]];
    if (c.stats) {
      arr(c.stats.stat).forEach(function (k, i) { rows.push([k, fmt(arr(c.stats.ref)[i]), fmt(arr(c.stats.cur)[i])]); });
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
  function detail() {
    if (S.sel < 0) return;
    var c = COLS[S.sel], v = verdict(c);
    $('detail-title').textContent = c.column + ' (' + MARK[v] + ')';
    $('note').textContent = note(c, v);
    summaryTable(c);
    if (c.bins) {
      var b = bins(c);
      chart('chart-cmp', c.hist ? histogram(c) :
        bars('Category shares of ' + c.column + ': reference against current', b.names,
          [{ name: 'reference', v: b.ref, col: REF }, { name: 'current', v: b.cur, col: CUR }]));
      var signed = b.contrib.map(function (t, i) { return (num(b.cur[i]) >= num(b.ref[i]) ? 1 : -1) * (num(t) || 0); });
      chart('chart-psi', bars('PSI of ' + c.column + ' by bin, up where the current sample has more', b.names,
        [{ name: 'PSI term', v: signed, col: function (t) { return t >= 0 ? CUR : REF; } }], true));
    } else {
      chart('chart-cmp', null);
      chart('chart-psi', null);
    }
    $('fig-benford').hidden = !c.benford;
    if (c.benford) {
      var bf = c.benford, n = bf.n, nr = arr(bf.ref).reduce(function (a, x) { return a + x; }, 0) || 1;
      var e = [1, 2, 3, 4, 5, 6, 7, 8, 9].map(function (d) { return Math.log10(1 + 1 / d); });
      var s = bars('First digits of ' + c.column + ' against Benford (p = ' + fmt(bf.p_value) + ')',
        ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
        [{ name: 'current', v: arr(bf.cur).map(function (k) { return k / n; }), col: CUR },
          { name: 'reference', v: arr(bf.ref).map(function (k) { return k / nr; }), col: REF }]);
      var top = Math.max.apply(null, e.concat(arr(bf.cur).map(function (k) { return k / n; }), arr(bf.ref).map(function (k) { return k / nr; })));
      var y = function (v) { return M.t + (H - M.t - M.b) * (1 - v / top); };
      var bw = (W - M.l - M.r) / 9;
      s.appendChild(sv('polyline', { points: e.map(function (v, i) { return (M.l + (i + 0.5) * bw) + ',' + y(v); }).join(' '),
        fill: 'none', stroke: '#4D4D4D', 'stroke-width': 2, 'stroke-dasharray': '4 3' }));
      s.appendChild(sv('text', { x: W - M.r, y: M.t + 10, 'text-anchor': 'end' },
        (num(bf.p_value) < S.alpha ? 'departs from' : 'consistent with') + ' Benford'));
      chart('chart-benford', s);
    }
  }
  function select(i) {
    S.sel = i;
    table();
    detail();
    var tr = document.querySelector('#coltable tbody tr[data-i="' + i + '"]');
    if (tr) tr.focus();
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
    exports();
  }

  // ---- manifest and history ------------------------------------------------------------------
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
  }
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
  function historyPlots(runs) {
    var box = $('history-plots');
    box.textContent = '';
    var names = [];
    runs.forEach(function (r) { r.cols.forEach(function (c) { if (names.indexOf(c.column) < 0) names.push(c.column); }); });
    names.forEach(function (nm) {
      var v = runs.map(function (r) {
        var c = r.cols.filter(function (x) { return x.column === nm; })[0];
        return c ? num(c.psi) : null;
      });
      var s = frame('PSI of ' + nm + ' over ' + runs.length + ' runs');
      var top = Math.max.apply(null, v.filter(function (x) { return x != null; }).concat([S.fail * 1.1]));
      var y = yaxis(s, 0, top, fmt);
      var x = function (i) { return M.l + (W - M.l - M.r) * (runs.length > 1 ? i / (runs.length - 1) : 0.5); };
      [['warn', S.warn], ['fail', S.fail]].forEach(function (b) {
        s.appendChild(sv('line', { x1: M.l, x2: W - M.r, y1: y(b[1]), y2: y(b[1]), stroke: VCOL[b[0]], 'stroke-dasharray': '4 3' }));
      });
      var pts = v.map(function (p, i) { return p == null ? null : x(i) + ',' + y(p); }).filter(Boolean);
      s.appendChild(sv('polyline', { points: pts.join(' '), fill: 'none', stroke: VCOL.ok, 'stroke-width': 2 }));
      v.forEach(function (p, i) {
        if (p == null) return;
        var c = sv('circle', { cx: x(i), cy: y(p), r: p > S.fail ? 5 : 3, fill: p > S.fail ? VCOL.fail : VCOL.ok });
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
          if (texts.length === files.length) historyPlots(historyRuns(texts));
        };
        rd.readAsText(f);
      });
    });
  }

  // ---- exports, tabs, keys, theme ----------------------------------------------------------------
  function markdown() {
    var n = { ok: 0, warn: 0, fail: 0, untested: 0 };
    var idx = Object.keys(COLS).map(Number).sort(function (a, b) {
      return RANK[verdict(COLS[a])] - RANK[verdict(COLS[b])] || (num(COLS[b].psi) || 0) - (num(COLS[a].psi) || 0);
    });
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
  function tabs() {
    ['columns', 'manifest', 'history'].forEach(function (t) {
      $('tab-' + t).addEventListener('click', function () {
        ['columns', 'manifest', 'history'].forEach(function (u) {
          $('pane-' + u).hidden = u !== t;
          $('tab-' + u).setAttribute('aria-selected', String(u === t));
        });
      });
    });
  }
  function keys() {
    document.addEventListener('keydown', function (ev) {
      var tag = (ev.target.tagName || '').toLowerCase();
      if (ev.key === '/' && tag !== 'input') {
        ev.preventDefault();
        $('search').focus();
        return;
      }
      if ((ev.key === 'ArrowDown' || ev.key === 'ArrowUp') && tag !== 'input') {
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
  function theme() {
    var root = document.documentElement;
    var dark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    $('theme').textContent = dark ? 'light theme' : 'dark theme';
    $('theme').addEventListener('click', function () {
      dark = !dark;
      root.setAttribute('data-theme', dark ? 'dark' : 'light');
      $('theme').textContent = dark ? 'light theme' : 'dark theme';
    });
  }
  $('reset').addEventListener('click', function () {
    S.warn = B0.warn;
    S.fail = B0.fail;
    S.alpha = B0.alpha;
    refresh();
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
  S.sel = visible().length ? visible()[0] : -1;
  refresh();
})();
