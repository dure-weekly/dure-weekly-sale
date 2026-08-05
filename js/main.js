/* ==========================================================================
   경기두레생협 주간할인 생활재 랜딩페이지 - 공통 스크립트
   - products.json / stores.json fetch 및 렌더링
   - 매장 찾기: 지도 API 없는 순수 문자열 매칭 로직
   ========================================================================== */

/* ------------------------------------------------------------ 공통 유틸 */

function formatPrice(n) {
  return n.toLocaleString("ko-KR") + "원";
}

function formatPeriodLabel(period) {
  // period.start / period.end : "YYYY-MM-DD" (월요일 ~ 일요일 고정)
  const WEEKDAY_KO = ["일", "월", "화", "수", "목", "금", "토"];
  const toLabel = (isoStr) => {
    const [y, m, d] = isoStr.split("-").map((v) => parseInt(v, 10));
    const weekday = WEEKDAY_KO[new Date(y, m - 1, d).getDay()];
    return `${m}.${d}(${weekday})`;
  };
  return `${toLabel(period.start)} – ${toLabel(period.end)}`;
}

async function fetchJSON(path) {
  const res = await fetch(path);
  if (!res.ok) {
    throw new Error(`${path} 요청 실패: ${res.status}`);
  }
  return res.json();
}

/* -------------------------------------------------------- 상품 렌더링 */

function renderPeriodBadges(period) {
  const label = formatPeriodLabel(period);
  document.querySelectorAll("[data-period-badge]").forEach((el) => {
    el.textContent = label;
  });
}

function buildProductCard(product) {
  const card = document.createElement("article");
  card.className = "product-card";
  const saveAmount = Math.max(product.originalPrice - product.salePrice, 0);

  // 상품 이미지는 ecoop 원본 이미지를 fetch로 그려주되, 외부 서버 이미지라 로드 실패 가능성이
  // 있으므로 onerror 시 자기 자신을 숨기고 뒤에 깔린 이모지 플레이스홀더가 드러나게 한다.
  const imageHtml = product.image
    ? `<img class="product-image" src="${product.image}" alt="${product.name}" loading="lazy" onerror="this.remove();" />`
    : "";

  card.innerHTML = `
    <div class="product-thumb">
      <span class="discount-badge" aria-hidden="true"><strong>${product.discountRate}%</strong><span class="badge-sub">할인</span></span>
      ${imageHtml}
      <span class="product-icon-wrap" aria-hidden="true">${product.icon || "🥬"}</span>
    </div>
    <div class="product-body">
      <p class="product-name">${product.name}</p>
      <p class="product-desc">${product.description}</p>
      <div class="price-block">
        <div class="price-row">
          <span class="price-original">${formatPrice(product.originalPrice)}</span>
          <span class="price-sale">${formatPrice(product.salePrice)}</span>
        </div>
        <span class="price-save">${formatPrice(saveAmount)} 절약</span>
      </div>
    </div>
  `;
  return card;
}

async function initProducts() {
  const grid = document.getElementById("product-grid");
  const countEl = document.getElementById("product-total-count");
  if (!grid) return;

  grid.innerHTML = `<p class="product-grid-status">이번 주 할인 생활재를 불러오는 중입니다...</p>`;

  try {
    const data = await fetchJSON("data/products.json");
    renderPeriodBadges(data.period);

    grid.innerHTML = "";
    const products = data.products || [];
    if (products.length === 0) {
      grid.innerHTML = `<p class="product-grid-status">이번 주 등록된 할인 상품이 없습니다.</p>`;
      return;
    }

    if (countEl) countEl.textContent = products.length;

    products.forEach((product) => {
      grid.appendChild(buildProductCard(product));
    });
  } catch (err) {
    console.error(err);
    grid.innerHTML = `<p class="product-grid-status">할인 상품 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.</p>`;
  }
}

/* --------------------------------------------------------- 매장 매칭 로직 */

/**
 * 문자열에서 공백/특수문자를 제거해 비교하기 쉽게 정규화한다.
 */
function normalizeText(str) {
  return (str || "").replace(/\s+/g, "").trim();
}

/**
 * 입력 주소(query)와 매장(store.keywords)을 문자열 포함 관계로 비교해
 * 점수를 매긴다. 지도 API 없이 시/구/동 키워드 매칭만으로 동작하는
 * "간이 지역 매칭" 로직 (기획서 §5 방식 B).
 *
 * - 매칭된 키워드 길이를 모두 합산해 점수를 매긴다. 여러 단위가 동시에 일치하면
 *   (예: "부천시"+"중동") 점수가 합산되어, 동/구 단위까지 일치하는 매장이
 *   시 단위만 일치하는 매장보다 우선하도록 한다.
 * - 입력값이 키워드를 포함하거나, 키워드가 입력값을 포함하면 매칭으로 인정한다.
 * - 결과 카드에 보여줄 대표 키워드(matchedKeyword)는 길이가 아니라
 *   동 > 구 > 시 > 매장명 우선순위로 골라, 가장 구체적인 지역명이 표시되게 한다.
 */
function scoreStore(query, store) {
  let totalScore = 0;
  const hitKeywords = [];

  (store.keywords || []).forEach((rawKeyword) => {
    const keyword = normalizeText(rawKeyword);
    if (!keyword) return;

    if (query.includes(keyword) || keyword.includes(query)) {
      totalScore += keyword.length;
      hitKeywords.push(rawKeyword);
    }
  });

  if (totalScore === 0) {
    return { score: 0, matchedKeyword: "" };
  }

  const priorityFields = [store.dong, store.district, store.city, store.name.replace("점", "")];
  let matchedKeyword = hitKeywords[0];
  for (const field of priorityFields) {
    const normalizedField = normalizeText(field);
    if (normalizedField && hitKeywords.some((k) => normalizeText(k) === normalizedField)) {
      matchedKeyword = field;
      break;
    }
  }

  return { score: totalScore, matchedKeyword };
}

/**
 * 입력 텍스트 기준으로 매장을 매칭해 점수순으로 정렬된 배열을 반환한다.
 * 점수가 같으면(예: "부천"처럼 넓은 지역어만 입력해 여러 매장이 동점일 때)
 * 결과가 배열 순서에 따라 뒤죽박죽 섞이지 않도록 매장명 가나다순으로 2차 정렬한다.
 * @param {string} rawQuery
 * @param {Array} stores
 * @returns {Array<{store, score, matchedKeyword}>}
 */
function matchStores(rawQuery, stores) {
  const query = normalizeText(rawQuery);
  if (!query) return [];

  const scored = stores
    .map((store) => {
      const { score, matchedKeyword } = scoreStore(query, store);
      return { store, score, matchedKeyword };
    })
    .filter((entry) => entry.score > 0);

  scored.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return a.store.name.localeCompare(b.store.name, "ko");
  });

  return scored;
}

/* --------------------------------------------------------- 매장 찾기 UI */

function buildStoreResultCard(store, matchedKeyword) {
  const label = matchedKeyword ? `"${matchedKeyword}" 일치` : "";
  const card = document.createElement("div");
  card.className = "store-result-card";
  card.innerHTML = `
    <span class="store-result-icon" aria-hidden="true">🏪</span>
    <div>
      <p class="store-result-name">${store.name}${label ? `<span class="match-tag">${label}</span>` : ""}</p>
      <p class="store-result-info">📞 <a href="tel:${store.phone}">${store.phone}</a></p>
      <p class="store-result-info">📍 ${store.address}</p>
    </div>
  `;
  return card;
}

async function initStoreFinder() {
  const form = document.getElementById("store-finder-form");
  const input = document.getElementById("store-finder-input");
  const resultsEl = document.getElementById("store-results");
  const statusEl = document.getElementById("store-result-status");
  if (!form || !input || !resultsEl) return;

  let allStores = [];
  try {
    const data = await fetchJSON("data/stores.json");
    allStores = data.stores || [];
  } catch (err) {
    console.error(err);
    statusEl.textContent = "매장 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.";
    return;
  }

  function renderResults(query) {
    resultsEl.innerHTML = "";
    const allMatched = matchStores(query, allStores);
    const matched = allMatched.slice(0, 3);

    if (matched.length === 0) {
      statusEl.textContent = `"${query}"와(과) 일치하는 지역을 찾지 못했어요. 아래에서 전체 매장을 확인해보세요.`;
      return;
    }

    let statusText = `"${query}" 근처 매장 ${matched.length}곳을 찾았어요.`;
    if (allMatched.length > matched.length) {
      statusText += ` 일치하는 매장이 ${allMatched.length}곳 더 있어요 — 전체 매장 보기를 이용하세요.`;
    }
    statusEl.textContent = statusText;

    matched.forEach(({ store, matchedKeyword }) => {
      resultsEl.appendChild(buildStoreResultCard(store, matchedKeyword));
    });
  }

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const query = input.value.trim();
    if (!query) {
      statusEl.textContent = "동/구/시 등 지역명을 입력해주세요. 예) 부천시 중동, 시흥 은행동";
      resultsEl.innerHTML = "";
      return;
    }
    renderResults(query);
  });

  document.querySelectorAll(".example-chip").forEach((chip) => {
    chip.addEventListener("click", () => {
      input.value = chip.dataset.example || chip.textContent;
      renderResults(input.value.trim());
      input.focus();
    });
  });
}

/* -------------------------------------------------- 전체 매장 목록(서브페이지) */

function groupStoresByCity(stores) {
  const groups = {};
  stores.forEach((store) => {
    const city = store.city || "기타";
    if (!groups[city]) groups[city] = [];
    groups[city].push(store);
  });
  return groups;
}

function buildStoreListCard(store) {
  const card = document.createElement("div");
  card.className = "store-list-card";
  card.innerHTML = `
    <p class="store-result-name">🏪 ${store.name}</p>
    <p class="store-result-info">📞 <a href="tel:${store.phone}">${store.phone}</a></p>
    <p class="store-result-info">📍 ${store.address}</p>
  `;
  return card;
}

async function initAllStoresList() {
  const container = document.getElementById("all-stores-list");
  if (!container) return;

  container.innerHTML = `<p class="product-grid-status">매장 목록을 불러오는 중입니다...</p>`;

  try {
    const data = await fetchJSON("data/stores.json");
    const stores = data.stores || [];
    const groups = groupStoresByCity(stores);
    const cityOrder = ["부천시", "시흥시", "광명시"];
    const cities = Object.keys(groups).sort((a, b) => {
      const ai = cityOrder.indexOf(a);
      const bi = cityOrder.indexOf(b);
      return (ai === -1 ? 99 : ai) - (bi === -1 ? 99 : bi);
    });

    container.innerHTML = "";
    const countEl = document.getElementById("store-total-count");
    if (countEl) countEl.textContent = stores.length;

    cities.forEach((city) => {
      const list = groups[city];
      const section = document.createElement("section");
      section.className = "region-group";
      section.innerHTML = `
        <h2 class="region-title">${city} <span class="region-count">${list.length}개 매장</span></h2>
      `;
      const grid = document.createElement("div");
      grid.className = "store-list-grid";
      list.forEach((store) => grid.appendChild(buildStoreListCard(store)));
      section.appendChild(grid);
      container.appendChild(section);
    });
  } catch (err) {
    console.error(err);
    container.innerHTML = `<p class="product-grid-status">매장 목록을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.</p>`;
  }
}

/* ---------------------------------------------------------------- Init */

document.addEventListener("DOMContentLoaded", () => {
  initProducts();
  initStoreFinder();
  initAllStoresList();
});
