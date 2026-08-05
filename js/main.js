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
  renderDday(period);
}

// 할인 종료일(일요일, period.end)까지 남은 일수를 "D-N" / "오늘까지" 형태로 보여줘 긴급성을 더한다.
function renderDday(period) {
  const el = document.getElementById("hero-dday");
  if (!el || !period || !period.end) return;

  const [y, m, d] = period.end.split("-").map((v) => parseInt(v, 10));
  const end = new Date(y, m - 1, d);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  end.setHours(0, 0, 0, 0);

  const diffDays = Math.round((end - today) / (1000 * 60 * 60 * 24));

  if (diffDays > 0) {
    el.textContent = `· D-${diffDays}`;
  } else if (diffDays === 0) {
    el.textContent = "· 오늘까지";
  } else {
    el.textContent = "";
  }
}

// 쇼핑몰에 사진이 등록되지 않은 상품(향후 매주 자동 갱신 시 발생 가능)은 <img> 없이
// 사진 카드와 똑같은 구조(아이콘 원형 + 그라데이션 배경)로 그려서, 빈칸처럼 보이지 않고
// "의도된 아이콘 카드"로 자연스럽게 섞이게 한다.
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

const PRODUCT_PAGE_SIZE = 12;
// 두 번째 배치(24개째)를 넘기는 시점에 매장 찾기로 유도하는 넛지를 한 번만 끼워 넣어,
// 상품 목록을 계속 넘기다 스크롤 피로로 이탈하는 것을 막는다.
const PRODUCT_NUDGE_AFTER = PRODUCT_PAGE_SIZE * 2;

function buildStoreNudgeCard() {
  const card = document.createElement("div");
  card.className = "product-nudge";
  card.innerHTML = `
    <span class="product-nudge-icon" aria-hidden="true">🏪</span>
    <p class="product-nudge-text">마음에 드는 생활재를 찾으셨나요? 가까운 매장에서 실물로 확인해보세요.</p>
    <a class="btn btn-outline" href="#store-finder">📍 가까운 매장 찾기</a>
  `;
  return card;
}

// products는 이미 할인율 내림차순으로 정렬되어 내려온다(data/products.json 생성 시 정렬).
// 상품 수가 많아졌으므로(약 130개) 한 번에 다 그리지 않고 PRODUCT_PAGE_SIZE개씩 이어서 그린다.
function renderNextProductBatch(products, grid, loadMoreWrap) {
  const start = grid.querySelectorAll(".product-card").length;
  const end = Math.min(start + PRODUCT_PAGE_SIZE, products.length);
  for (let i = start; i < end; i++) {
    grid.appendChild(buildProductCard(products[i]));
  }

  const shownAfter = grid.querySelectorAll(".product-card").length;
  const nudgeAlreadyShown = !!grid.querySelector(".product-nudge");
  if (!nudgeAlreadyShown && start < PRODUCT_NUDGE_AFTER && shownAfter >= PRODUCT_NUDGE_AFTER && shownAfter < products.length) {
    grid.appendChild(buildStoreNudgeCard());
  }

  renderProductLoadMoreButton(products, grid, loadMoreWrap);
}

function renderProductLoadMoreButton(products, grid, loadMoreWrap) {
  if (!loadMoreWrap) return;
  loadMoreWrap.innerHTML = "";

  const shownCount = grid.querySelectorAll(".product-card").length;
  if (shownCount >= products.length) return;

  const btn = document.createElement("button");
  btn.type = "button";
  btn.className = "btn btn-outline btn-loadmore";
  btn.textContent = `할인 상품 더보기 (${shownCount}/${products.length})`;
  btn.addEventListener("click", () => renderNextProductBatch(products, grid, loadMoreWrap));
  loadMoreWrap.appendChild(btn);
}

/* ------------------------------------------------------- 카테고리 필터 */

// 정육/수산/과일·채소/쌀·잡곡/가공·반찬/생활용품 순서로 노출한다.
// 실제 존재하는 category 값만 칩으로 만들고, 데이터에 없는 카테고리는 자동으로 건너뛴다.
const CATEGORY_LABELS = [
  { value: "all", label: "전체", icon: "🏷️" },
  { value: "meat", label: "정육", icon: "🥩" },
  { value: "seafood", label: "수산", icon: "🐟" },
  { value: "produce", label: "과일·채소", icon: "🥬" },
  { value: "grain", label: "쌀·잡곡", icon: "🌾" },
  { value: "processed", label: "가공·반찬", icon: "🧂" },
  { value: "living", label: "생활용품", icon: "🧴" },
];

// 검색어가 상품명에 그대로 없어도("새우" 검색에 "자연산대하"가 걸리도록) 자주 쓰는 장보기 용어를
// 카테고리나 유사어로 넓혀서 매칭한다. 정확한 상품명 부분일치는 항상 기본으로 함께 적용된다.
const SEARCH_SYNONYMS = {
  고기: { category: "meat" },
  정육: { category: "meat" },
  육류: { category: "meat" },
  새우: { terms: ["새우", "대하"] },
  생선: { category: "seafood" },
  수산: { category: "seafood" },
  해산물: { category: "seafood" },
  야채: { category: "produce" },
  채소: { category: "produce" },
  나물: { category: "produce" },
  과일: { category: "produce" },
  쌀: { category: "grain" },
  잡곡: { category: "grain" },
  반찬: { category: "processed" },
  세제: { category: "living" },
  생필품: { category: "living" },
};

function matchesSearchQuery(product, rawQuery) {
  const q = normalizeText(rawQuery).toLowerCase();
  if (!q) return true;
  if (normalizeText(product.name).toLowerCase().includes(q)) return true;

  const synonym = SEARCH_SYNONYMS[rawQuery.trim()];
  if (!synonym) return false;
  if (synonym.category && product.category === synonym.category) return true;
  if (synonym.terms) {
    return synonym.terms.some((t) => normalizeText(product.name).toLowerCase().includes(normalizeText(t).toLowerCase()));
  }
  return false;
}

// 카테고리 칩과 이름 검색창은 동시에 적용된다(AND 조건).
// 예: "정육" 칩을 누른 채로 "새우"를 입력하면 결과가 0건이 되는 게 정상 동작이다.
function renderProductFilter(allProducts, grid, loadMoreWrap, filterWrap, searchInput) {
  if (!filterWrap) return;

  const presentCategories = new Set(allProducts.map((p) => p.category));
  const chips = CATEGORY_LABELS.filter((c) => c.value === "all" || presentCategories.has(c.value));

  const state = { category: "all", query: "" };

  function applyFilters() {
    let filtered = state.category === "all" ? allProducts : allProducts.filter((p) => p.category === state.category);
    if (state.query.trim()) {
      filtered = filtered.filter((p) => matchesSearchQuery(p, state.query));
    }
    grid.innerHTML = "";
    if (filtered.length === 0) {
      grid.innerHTML = `<p class="product-grid-status">조건에 맞는 할인 생활재가 없습니다.</p>`;
      if (loadMoreWrap) loadMoreWrap.innerHTML = "";
      return;
    }
    renderNextProductBatch(filtered, grid, loadMoreWrap);
  }

  filterWrap.innerHTML = "";
  chips.forEach((c, idx) => {
    const count = c.value === "all" ? allProducts.length : allProducts.filter((p) => p.category === c.value).length;
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "filter-chip";
    btn.setAttribute("role", "tab");
    btn.setAttribute("aria-selected", idx === 0 ? "true" : "false");
    btn.textContent = `${c.icon} ${c.label} (${count})`;
    btn.addEventListener("click", () => {
      filterWrap.querySelectorAll(".filter-chip").forEach((el) => el.setAttribute("aria-selected", "false"));
      btn.setAttribute("aria-selected", "true");
      state.category = c.value;
      applyFilters();
    });
    filterWrap.appendChild(btn);
  });

  if (searchInput) {
    searchInput.addEventListener("input", () => {
      state.query = searchInput.value;
      applyFilters();
    });
  }
}

async function initProducts() {
  const grid = document.getElementById("product-grid");
  const loadMoreWrap = document.getElementById("product-grid-loadmore");
  const filterWrap = document.getElementById("product-filter");
  const searchInput = document.getElementById("product-search-input");
  const countEl = document.getElementById("product-total-count");
  if (!grid) return;

  grid.innerHTML = `<p class="product-grid-status">이번 주 할인 생활재를 불러오는 중입니다...</p>`;

  try {
    const data = await fetchJSON("data/products.json");
    renderPeriodBadges(data.period);

    grid.innerHTML = "";
    const products = data.products || [];
    if (products.length === 0) {
      grid.innerHTML = `<p class="product-grid-status">이번 주 등록된 할인 생활재가 없습니다.</p>`;
      return;
    }

    if (countEl) countEl.textContent = products.length;

    renderProductFilter(products, grid, loadMoreWrap, filterWrap, searchInput);
    renderNextProductBatch(products, grid, loadMoreWrap);
  } catch (err) {
    console.error(err);
    grid.innerHTML = `<p class="product-grid-status">할인 생활재 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.</p>`;
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
