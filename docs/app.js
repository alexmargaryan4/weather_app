// ============================================================
// Weather+ · Панель — логика
// Использует Supabase JS SDK (уже подключён в index.html) и
// Chart.js для графиков. Читает данные через RLS-политики
// "authenticated read ..." из schema.sql — то есть работает
// только под залогиненным пользователем Supabase Auth.
// ============================================================

const { supabaseUrl, supabaseAnonKey } = window.WEATHER_DASHBOARD_CONFIG;
const supabase = window.supabase.createClient(supabaseUrl, supabaseAnonKey);

const loginScreen = document.getElementById('loginScreen');
const dashboard = document.getElementById('dashboard');
const loginForm = document.getElementById('loginForm');
const loginBtn = document.getElementById('loginBtn');
const loginError = document.getElementById('loginError');
const logoutBtn = document.getElementById('logoutBtn');
const refreshBtn = document.getElementById('refreshBtn');
const lastUpdatedEl = document.getElementById('lastUpdated');

let dauChart = null;
let newChart = null;

// ------------------------------------------------------------
// Авторизация
// ------------------------------------------------------------

async function showDashboardIfLoggedIn() {
  const { data: { session } } = await supabase.auth.getSession();
  if (session) {
    loginScreen.style.display = 'none';
    dashboard.style.display = 'block';
    loadAllData();
  } else {
    loginScreen.style.display = 'flex';
    dashboard.style.display = 'none';
  }
}

loginForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  loginError.textContent = '';
  loginBtn.disabled = true;
  loginBtn.textContent = 'Вход…';

  const email = document.getElementById('email').value.trim();
  const password = document.getElementById('password').value;

  const { error } = await supabase.auth.signInWithPassword({ email, password });

  loginBtn.disabled = false;
  loginBtn.textContent = 'Войти';

  if (error) {
    loginError.textContent = 'Не удалось войти: проверьте email и пароль.';
    return;
  }

  await showDashboardIfLoggedIn();
});

logoutBtn.addEventListener('click', async () => {
  await supabase.auth.signOut();
  await showDashboardIfLoggedIn();
});

refreshBtn.addEventListener('click', () => loadAllData());

// ------------------------------------------------------------
// Загрузка всех данных дашборда
// ------------------------------------------------------------

async function loadAllData() {
  setRefreshState(true);
  try {
    await Promise.all([
      loadMetrics(),
      loadDauChart(),
      loadNewDevicesChart(),
      loadTopCities(),
      loadTopCountries(),
      loadTopFavorites(),
      loadLocales(),
      loadVersions(),
    ]);
    lastUpdatedEl.textContent = `Обновлено в ${new Date().toLocaleTimeString('ru-RU')}`;
  } catch (err) {
    console.error('Ошибка загрузки данных дашборда:', err);
    lastUpdatedEl.textContent = 'Ошибка загрузки данных';
  } finally {
    setRefreshState(false);
  }
}

function setRefreshState(loading) {
  refreshBtn.disabled = loading;
  refreshBtn.textContent = loading ? 'Обновление…' : 'Обновить';
}

// ------------------------------------------------------------
// Метрики сверху
// ------------------------------------------------------------

async function loadMetrics() {
  const now = new Date();
  const todayStart = new Date(now);
  todayStart.setHours(0, 0, 0, 0);
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  const [
    totalDevicesRes,
    dauTodayRes,
    new7Res,
    totalRequestsRes,
  ] = await Promise.all([
    supabase.from('devices').select('device_id', { count: 'exact', head: true }),
    supabase
      .from('weather_requests')
      .select('device_id', { count: 'exact', head: true })
      .gte('requested_at', todayStart.toISOString()),
    supabase
      .from('devices')
      .select('device_id', { count: 'exact', head: true })
      .gte('first_seen_at', sevenDaysAgo.toISOString()),
    supabase.from('weather_requests').select('id', { count: 'exact', head: true }),
  ]);

  setMetric('mTotal', totalDevicesRes.count);
  setMetric('mDauToday', dauTodayRes.count);
  setMetric('mNew7', new7Res.count);
  setMetric('mRequests', totalRequestsRes.count);

  document.getElementById('mNew7Sub').textContent = 'за последние 7 дней';
  document.getElementById('mRequestsSub').textContent = 'за всё время';
}

function setMetric(elId, value) {
  const el = document.getElementById(elId);
  el.textContent = value === null || value === undefined ? '—' : formatNumber(value);
}

function formatNumber(n) {
  return new Intl.NumberFormat('ru-RU').format(n);
}

// ------------------------------------------------------------
// График: активные устройства по дням (DAU)
// ------------------------------------------------------------

async function loadDauChart() {
  const { data, error } = await supabase
    .from('v_daily_active_users')
    .select('day, active_devices')
    .order('day', { ascending: true })
    .limit(30);

  if (error) throw error;

  const labels = (data || []).map((row) => formatDateShort(row.day));
  const values = (data || []).map((row) => row.active_devices);

  renderLineChart('dauChart', 'dauChart_instance', labels, values, 'Активные устройства');
}

// ------------------------------------------------------------
// График: новые устройства по дням
// ------------------------------------------------------------

async function loadNewDevicesChart() {
  const { data, error } = await supabase
    .from('v_daily_new_devices')
    .select('day, new_devices')
    .order('day', { ascending: true })
    .limit(30);

  if (error) throw error;

  const labels = (data || []).map((row) => formatDateShort(row.day));
  const values = (data || []).map((row) => row.new_devices);

  renderLineChart('newChart', 'newChart_instance', labels, values, 'Новые устройства');
}

function renderLineChart(canvasId, storeKey, labels, values, label) {
  const ctx = document.getElementById(canvasId).getContext('2d');
  const existing = storeKey === 'dauChart_instance' ? dauChart : newChart;
  if (existing) existing.destroy();

  const chart = new Chart(ctx, {
    type: 'line',
    data: {
      labels,
      datasets: [
        {
          label,
          data: values,
          borderColor: '#6fb3d9',
          backgroundColor: 'rgba(111, 179, 217, 0.12)',
          borderWidth: 2,
          pointRadius: 2,
          pointBackgroundColor: '#6fb3d9',
          tension: 0.3,
          fill: true,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          backgroundColor: '#142650',
          borderColor: 'rgba(255,255,255,0.1)',
          borderWidth: 1,
          titleColor: '#f4f2ec',
          bodyColor: '#9aa5c9',
          padding: 10,
        },
      },
      scales: {
        x: {
          grid: { display: false },
          ticks: { color: '#5c6690', font: { size: 11 } },
        },
        y: {
          beginAtZero: true,
          grid: { color: 'rgba(255,255,255,0.06)' },
          ticks: { color: '#5c6690', font: { size: 11 }, precision: 0 },
        },
      },
    },
  });

  if (storeKey === 'dauChart_instance') dauChart = chart;
  else newChart = chart;
}

function formatDateShort(isoDate) {
  const d = new Date(isoDate);
  return d.toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit' });
}

// ------------------------------------------------------------
// Топ городов
// ------------------------------------------------------------

async function loadTopCities() {
  const { data, error } = await supabase
    .from('v_top_cities')
    .select('city_name, country_code, request_count')
    .limit(8);

  if (error) throw error;
  renderRankList('topCitiesList', data, (row) => ({
    name: row.city_name,
    code: row.country_code,
    count: row.request_count,
  }));
}

// ------------------------------------------------------------
// Топ стран
// ------------------------------------------------------------

async function loadTopCountries() {
  const { data, error } = await supabase
    .from('v_top_countries')
    .select('country_code, request_count')
    .limit(8);

  if (error) throw error;
  renderRankList('topCountriesList', data, (row) => ({
    name: row.country_code || '—',
    code: null,
    count: row.request_count,
  }));
}

// ------------------------------------------------------------
// Топ избранных городов (активные, не удалённые)
// ------------------------------------------------------------

async function loadTopFavorites() {
  const { data, error } = await supabase
    .from('v_active_favorites')
    .select('city_name, country_code');

  if (error) throw error;

  const counts = new Map();
  (data || []).forEach((row) => {
    const key = `${row.city_name}|${row.country_code || ''}`;
    const entry = counts.get(key) || { name: row.city_name, code: row.country_code, count: 0 };
    entry.count += 1;
    counts.set(key, entry);
  });

  const sorted = Array.from(counts.values())
    .sort((a, b) => b.count - a.count)
    .slice(0, 8);

  renderRankList('topFavoritesList', sorted, (row) => row);
}

// ------------------------------------------------------------
// Языки устройств (locale)
// ------------------------------------------------------------

async function loadLocales() {
  const { data, error } = await supabase.from('devices').select('locale');
  if (error) throw error;

  const counts = new Map();
  (data || []).forEach((row) => {
    const key = row.locale || 'не указан';
    counts.set(key, (counts.get(key) || 0) + 1);
  });

  const sorted = Array.from(counts.entries())
    .map(([name, count]) => ({ name, code: null, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 8);

  renderRankList('localesList', sorted, (row) => row);
}

// ------------------------------------------------------------
// Версии приложения (app_version) — кто на какой версии APK
// ------------------------------------------------------------

async function loadVersions() {
  const { data, error } = await supabase.from('devices').select('app_version');
  if (error) throw error;

  const counts = new Map();
  (data || []).forEach((row) => {
    const key = row.app_version || 'неизвестно';
    counts.set(key, (counts.get(key) || 0) + 1);
  });

  const sorted = Array.from(counts.entries())
    .map(([name, count]) => ({ name, code: null, count }))
    // Сортируем по версии по убыванию (новые сверху), если это похоже на
    // семвер (1.2.3); иначе просто по количеству устройств.
    .sort((a, b) => {
      const cmp = compareVersionsDesc(a.name, b.name);
      return cmp !== 0 ? cmp : b.count - a.count;
    });

  renderRankList('versionsList', sorted, (row) => row);
}

/// Сравнивает две строки версии по убыванию (напр. "1.10.0" > "1.9.2").
/// Нечисловые/неполные значения (например "неизвестно") уходят вниз списка.
function compareVersionsDesc(a, b) {
  const pa = String(a).split('.').map((n) => parseInt(n, 10));
  const pb = String(b).split('.').map((n) => parseInt(n, 10));
  const aValid = pa.every((n) => !isNaN(n));
  const bValid = pb.every((n) => !isNaN(n));
  if (aValid && !bValid) return -1;
  if (!aValid && bValid) return 1;
  if (!aValid && !bValid) return 0;

  const len = Math.max(pa.length, pb.length);
  for (let i = 0; i < len; i++) {
    const x = pa[i] || 0;
    const y = pb[i] || 0;
    if (x !== y) return y - x;
  }
  return 0;
}

// ------------------------------------------------------------
// Универсальный рендер ранжированного списка
// ------------------------------------------------------------

function renderRankList(listElId, rows, mapFn) {
  const listEl = document.getElementById(listElId);
  listEl.innerHTML = '';

  if (!rows || rows.length === 0) {
    listEl.innerHTML = '<li class="empty-note">Пока нет данных</li>';
    return;
  }

  const items = rows.map(mapFn);
  const maxCount = Math.max(...items.map((i) => i.count || 0), 1);

  items.forEach((item, idx) => {
    const li = document.createElement('li');
    li.className = 'rank-item';

    const barPct = Math.round(((item.count || 0) / maxCount) * 100);

    li.innerHTML = `
      <span class="rank-num">${idx + 1}</span>
      <span class="rank-name">${escapeHtml(item.name)}${
        item.code ? `<span class="country-code">${escapeHtml(item.code)}</span>` : ''
      }</span>
      <span class="rank-bar-wrap"><span class="rank-bar" style="width:${barPct}%"></span></span>
      <span class="rank-count">${formatNumber(item.count || 0)}</span>
    `;
    listEl.appendChild(li);
  });
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

// ------------------------------------------------------------
// Реакция на смену состояния авторизации (например, в другой вкладке)
// ------------------------------------------------------------

supabase.auth.onAuthStateChange((_event, _session) => {
  showDashboardIfLoggedIn();
});

// ------------------------------------------------------------
// Старт
// ------------------------------------------------------------

showDashboardIfLoggedIn();
