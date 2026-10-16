import { envText } from './env.js';
import { releaseInfo } from './release.js';
import { FALLBACK_COVERAGE, loadStats } from './stats.js';

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

const REFRESH_AFTER_MS = 5 * 60 * 1000;
let lastFetchAt = 0;
let refreshInFlight = false;

/* ── Formatting helpers ─────────────────────────────────────────────────── */

const peso = (value) => `₱${Math.round(value).toLocaleString('en-PH')}`;
const km = (value) => `${Number.isInteger(value) ? value : value.toFixed(1)} km`;
const count = (value) => Number(value).toLocaleString('en-PH');

function formatList(names) {
  const items = names.filter(Boolean);
  if (items.length === 0) return '';
  if (items.length === 1) return items[0];
  return `${items.slice(0, -1).join(', ')} & ${items[items.length - 1]}`;
}

function formatTime(date) {
  try {
    return new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit' }).format(date);
  } catch {
    return date.toLocaleTimeString();
  }
}

/** Prefer a live figure, but never render an empty cell. */
const orFallback = (value, key) =>
  value === null || value === undefined || Number.isNaN(value) ? FALLBACK_COVERAGE[key] : value;

/* ── Release identity ───────────────────────────────────────────────────── */

function renderRelease() {
  const { display, label, isProduction } = releaseInfo;

  $$('[data-release-display]').forEach((el) => {
    el.textContent = display;
  });

  $$('[data-release-label]').forEach((el) => {
    el.textContent = label;
  });

  $$('[data-release-chip]').forEach((el) => {
    el.hidden = isProduction;
  });

  $$('[data-release-badge]').forEach((el) => {
    el.hidden = isProduction;
    if (!isProduction) el.textContent = label;
  });

  const caveat = $('[data-release-caveat]');
  if (caveat) caveat.hidden = isProduction;
}

/* ── Download call to action ────────────────────────────────────────────── */

function renderDownload() {
  const apkUrl = envText('APK_URL');
  const apkSize = envText('APK_SIZE');
  const links = $$('[data-apk-link]');
  const notice = $('[data-apk-notice]');

  // Every download button on the page (nav, hero, driver band, footer) points at
  // the same artifact, so they enable and disable together.
  links.forEach((link) => {
    if (apkUrl) {
      link.href = apkUrl;
      link.target = '_blank';
      link.rel = 'noopener noreferrer';
      link.removeAttribute('aria-disabled');
      link.classList.remove('is-disabled');
    } else {
      // No published artifact: keep the buttons visible but inert.
      link.removeAttribute('href');
      link.removeAttribute('target');
      link.removeAttribute('rel');
      link.setAttribute('aria-disabled', 'true');
      link.classList.add('is-disabled');
      link.addEventListener('click', (event) => event.preventDefault());
    }
  });

  if (notice) notice.hidden = Boolean(apkUrl);

  const sizeRow = $('[data-apk-size-row]');
  const sizeValue = $('[data-apk-size]');
  if (sizeRow && sizeValue && apkSize) {
    sizeValue.textContent = apkSize;
    sizeRow.hidden = false;
  }
}

/* ── Statistics ─────────────────────────────────────────────────────────── */

function setText(selector, value) {
  $$(selector).forEach((el) => {
    el.textContent = value;
  });
}

function renderStatus(state, { pending = false } = {}) {
  const pill = $('[data-health-pill]');
  const text = $('[data-health-text]');
  const detail = $('[data-health-detail]');
  const retry = $('[data-health-retry]');

  if (pending) {
    if (pill) pill.className = 'status-pill is-pending';
    if (text) text.textContent = 'Checking the TriGo API…';
    if (detail) detail.textContent = '';
    return;
  }

  const { health, coverageIsLive, origin, fetchedAt } = state;
  const online = health.ok;
  const live = coverageIsLive;

  if (pill) {
    pill.className = `status-pill ${online ? 'is-ok' : live ? 'is-warn' : 'is-error'}`;
  }

  if (text) {
    if (online && live) {
      text.textContent = 'TriGo API online — showing live coverage';
    } else if (live) {
      text.textContent = 'Coverage loaded — health check unavailable';
    } else {
      text.textContent = 'Backend unreachable — showing the seeded fare matrix';
    }
  }

  if (detail) {
    const checked = formatTime(fetchedAt);
    if (online) {
      detail.textContent = `${origin} · checked at ${checked}`;
    } else if (health.error === 'timed out') {
      detail.textContent = `${origin} did not respond in time · checked at ${checked}`;
    } else {
      detail.textContent = `${origin} could not be reached · checked at ${checked}`;
    }
  }

  if (retry) retry.hidden = false;

  const sourceTag = $('[data-source-tag]');
  if (sourceTag) {
    sourceTag.textContent = live ? 'live data' : 'seeded fallback';
    sourceTag.className = live ? 'tag' : 'tag tag-slate';
  }
}

function renderCoverage(state) {
  const coverage = state.coverage;

  const municipalities = orFallback(coverage.municipalities, 'municipalities');
  const provinces = orFallback(coverage.provinces, 'provinces');
  const baseFare = orFallback(coverage.baseFare, 'baseFare');
  const perKmRate = orFallback(coverage.perKmRate, 'perKmRate');
  const radiusKm = orFallback(coverage.radiusKm, 'radiusKm');
  const maxPassengers = orFallback(coverage.maxPassengers, 'maxPassengers');

  setText('[data-stat="municipalities"]', count(municipalities));
  setText('[data-stat="provinces"]', count(provinces));
  setText('[data-stat="baseFare"]', peso(baseFare));
  setText('[data-stat="perKmRate"]', peso(perKmRate));
  setText('[data-stat="radiusKm"]', km(radiusKm));
  setText('[data-stat="maxPassengers"]', count(maxPassengers));

  const municipalityNames = coverage.municipalityNames.length
    ? coverage.municipalityNames
    : FALLBACK_COVERAGE.municipalityNames;
  const provinceNames = coverage.provinceNames.length
    ? coverage.provinceNames
    : FALLBACK_COVERAGE.provinceNames;

  setText('[data-stat-note="municipalities"]', formatList(municipalityNames));
  setText('[data-stat-note="provinces"]', formatList(provinceNames));

  const coverageSummary = `${formatList(municipalityNames)}${
    provinceNames.length ? `, ${formatList(provinceNames)}` : ''
  }`;

  setText('[data-coverage-chip]', coverageSummary);
  setText('[data-coverage-text]', coverageSummary);
}

async function refreshStats({ initial = false } = {}) {
  if (refreshInFlight) return;
  refreshInFlight = true;

  if (!initial) {
    renderStatus(null, { pending: true });
    $$('.stat-card').forEach((card) => card.classList.add('is-updating'));
  }

  try {
    const state = await loadStats();
    lastFetchAt = Date.now();
    renderStatus(state);
    renderCoverage(state);
  } catch (error) {
    // loadStats already degrades gracefully; this only guards against a bug.
    console.warn('[trigo-landing] statistics unavailable', error);
  } finally {
    refreshInFlight = false;
    $$('.stat-card').forEach((card) => card.classList.remove('is-updating'));
  }
}

/* ── Screenshots ────────────────────────────────────────────────────────── */

/**
 * Screen captures live in `screens/updated/` and are uploaded independently of
 * the page, so a missing file must degrade to a labelled placeholder inside the
 * phone frame instead of a broken-image icon.
 */
function setupScreenshots() {
  $$('[data-screenshot]').forEach((frame) => {
    const image = frame.querySelector('img');
    if (!image) return;

    const placeholder = frame.querySelector('[data-screenshot-fallback]');

    const showPlaceholder = () => {
      image.hidden = true;
      frame.classList.add('is-missing');
      if (placeholder) placeholder.hidden = false;
    };

    // A cached miss can settle before this script runs.
    if (image.complete && image.naturalWidth === 0) showPlaceholder();
    image.addEventListener('error', showPlaceholder);
  });
}

/* ── Page chrome ────────────────────────────────────────────────────────── */

function setupNav() {
  const toggle = $('[data-nav-toggle]');
  const nav = $('[data-nav]');
  const header = $('[data-header]');

  if (toggle && nav) {
    const close = () => {
      nav.classList.remove('is-open');
      toggle.setAttribute('aria-expanded', 'false');
    };

    toggle.addEventListener('click', () => {
      const open = nav.classList.toggle('is-open');
      toggle.setAttribute('aria-expanded', String(open));
    });

    nav.addEventListener('click', (event) => {
      if (event.target instanceof Element && event.target.closest('a')) close();
    });

    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') close();
    });

    window.addEventListener('resize', () => {
      if (window.innerWidth >= 900) close();
    });
  }

  if (header) {
    const onScroll = () => header.classList.toggle('is-scrolled', window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
  }
}

function setupRetry() {
  const retry = $('[data-health-retry]');
  if (retry) {
    retry.addEventListener('click', () => refreshStats());
  }

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && Date.now() - lastFetchAt > REFRESH_AFTER_MS) {
      refreshStats();
    }
  });
}

function setupFooter() {
  $$('[data-year]').forEach((el) => {
    el.textContent = String(new Date().getFullYear());
  });
}

/* ── Boot ───────────────────────────────────────────────────────────────── */

renderRelease();
renderDownload();
renderCoverage({ coverage: FALLBACK_COVERAGE });
setupScreenshots();
setupNav();
setupRetry();
setupFooter();
refreshStats({ initial: true });
