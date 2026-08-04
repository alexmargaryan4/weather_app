// ============================================================
// Weather+ · Панель — логика
// Использует Supabase JS SDK (уже подключён в index.html) и
// Chart.js для графиков. Читает данные через RLS-политики
// "authenticated read ..." из schema.sql — то есть работает
// только под залогиненным пользователем Supabase Auth.
// ============================================================

const { supabaseUrl, supabaseAnonKey } = window.WEATHER_DASHBOARD_CONFIG;
const supabase = window.supabase.createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: false,
  },
});

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
// ВРЕМЕННАЯ ДИАГНОСТИКА: показываем любую непойманную ошибку прямо
// на экране логина, чтобы можно было прочитать её текст с телефона
// без доступа к консоли разработчика. Убрать после того, как проблема
// со входом будет найдена и исправлена.
// ------------------------------------------------------------
window.addEventListener('error', (e) => {
  loginScreen.style.display = 'flex';
  dashboard.style.display = 'none';
  loginError.textContent = `[Диагностика] ${e.message}`;
});
window.addEventListener('unhandledrejection', (e) => {
  loginScreen.style.display = 'flex';
  dashboard.style.display = 'none';
  const reason = e.reason;
  const msg = (reason && (reason.message || reason.error_description || reason.hint)) || String(reason);
  loginError.textContent = `[Диагностика] ${msg}`;
});

// ------------------------------------------------------------
// Авторизация
//
// На iOS Safari событие onAuthStateChange может сработать с задержкой
// или не сразу после signInWithPassword (известная особенность WebKit
// в связке с локальным хранилищем сессии). Поэтому не полагаемся
// только на событие: переключаем экран сразу по результату самого
// запроса логина, а onAuthStateChange держим как синхронизирующий
// механизм для остальных случаев (открытие сайта с уже активной
// сессией, выход, обновление токена, логин/логаут в другой вкладке).
//
// isSessionShown защищает от того, чтобы одно и то же состояние
// (например, два подряд события с сессией) не перезапускало
// loadAllData() лишний раз.
// ------------------------------------------------------------

let isSessionShown = null; // null = ещё неизвестно, true/false = что показано сейчас

function renderAuthState(session) {
  const hasSession = !!session;
  if (isSessionShown === hasSession) return; // уже в этом состоянии — ничего не делаем
  isSessionShown = hasSession;

  if (hasSession) {
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

  const { data, error } = await supabase.auth.signInWithPassword({ email, password });

  loginBtn.disabled = false;
  loginBtn.textContent = 'Войти';

  if (error) {
    loginError.textContent = 'Не удалось войти: проверьте email и пароль.';
    return;
  }

  if (!data.session) {
    // Очень редкий случай: сервер не вернул ошибку, но и сессии нет.
    // Раньше это молча возвращало на экран логина без объяснения —
    // теперь сообщаем явно, чтобы не гадать при диагностике.
    loginError.textContent = '[Диагностика] Вход прошёл, но сессия не получена (data.session пуст).';
    return;
  }

  // Переключаем экран сразу здесь, не дожидаясь onAuthStateChange —
  // на iOS Safari это событие не всегда приходит вовремя.
  renderAuthState(data.session);
});

logoutBtn.addEventListener('click', async () => {
  await supabase.auth.signOut();
  renderAuthState(null);
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
    ]);
    lastUpdatedEl.textContent = `Обновлено в ${new Date().toLocaleTimeString('ru-RU')}`;
  } catch (err) {
    console.error('Ошибка загрузки данных дашборда:', err);
    const msg = (err && (err.message || err.error_description || err.hint)) || String(err);
    lastUpdatedEl.textContent = `Ошибка: ${msg}`;
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
// onAuthStateChange как резервный/синхронизирующий механизм:
// ловит открытие сайта с уже активной сессией, логаут/логин в другой
// вкладке, обновление токена. renderAuthState сам игнорирует повторные
// вызовы с тем же состоянием (см. isSessionShown выше), так что этот
// обработчик безопасно дублирует прямой вызов после логина/логаута.
// ------------------------------------------------------------

supabase.auth.onAuthStateChange((_event, session) => {
  renderAuthState(session);
});
