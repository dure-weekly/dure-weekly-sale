/* ==========================================================================
   경기두레생협 주간할인 생활재 랜딩페이지 - 공통 스크립트
   - products.json / stores.json fetch 및 렌더링
   - 매장 찾기: 지도 API 없는 순수 문자열 매칭 로직
   ========================================================================== */

/* ------------------------------------------------------------ 공통 유틸 */

// 숫자 뒤 단위("원")를 작게 따로 감싸서, 숫자 자체의 가독성을 높인다.
function formatPrice(n) {
  return `${n.toLocaleString("ko-KR")}<span class="unit">원</span>`;
}

// 정가·중간가처럼 "최종가가 아닌" 값은 원 단위 없이 숫자만 — 모바일에서 원이 다음 줄로
// 밀려나 줄바꿈되는 문제를 막고, 최종 판매가만 원이 붙어 더 도드라지게 한다.
function formatNumberOnly(n) {
  return n.toLocaleString("ko-KR");
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

// 상품/예약 데이터는 매주 바뀌는데, 브라우저나 CDN이 옛 버전을 캐시해두면
// 새로고침해도 갱신이 안 보일 수 있다. 매 요청마다 타임스탬프를 붙이고
// cache: "no-store"로 강제해, 항상 최신 파일을 받아오게 한다.
async function fetchJSON(path) {
  const bustedPath = path + (path.includes("?") ? "&" : "?") + "v=" + Date.now();
  const res = await fetch(bustedPath, { cache: "no-store" });
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

  // itemType이 "햇출하"면 할인이 아니라 "이번 주 새로 들어온 생활재"라는 뜻 —
  // %대신 전용 배지를 쓰고, 정가/할인가가 같으므로 취소선·절약문구 없이 가격 한 줄만 보여준다.
  // discountRate가 0이어도 햇출하가 아닌 경우(예: "3개이상 구매시 할인" 같은 조건부 할인)가 있으므로
  // itemType으로 구분한다 — note(특이사항)가 있으면 별도 배지로 그 조건을 보여준다.
  const isNewArrival = product.itemType === "햇출하";
  const badgeHtml = isNewArrival
    ? `<span class="discount-badge discount-badge-new" aria-hidden="true"><strong>🌱</strong><span class="badge-sub">햇출하</span></span>`
    : product.discountRate > 0
    ? `<span class="discount-badge" aria-hidden="true"><strong>${product.discountRate}<span class="unit">%</span></strong><span class="badge-sub">할인</span></span>`
    : "";
  // 수산쿠폰 주간: 이미 주간할인가가 있던 품목은 정가→주간할인가→쿠폰최종가 3단으로,
  // 나머지(쿠폰으로만 할인되는 품목)는 정가→최종가 2단으로 보여주되 둘 다 쿠폰 태그를 단다
  // (사전예약 수산쿠폰 카드와 동일한 톤 — coupon-tag + price-chain-arrow 재사용).
  const couponTagHtml = product.category === "seafood_coupon" ? `<span class="coupon-tag">🐟 수산쿠폰</span>` : "";
  const priceHtml = product.hasCoupon && product.couponPrice != null
    ? `<div class="price-block">
        ${couponTagHtml}
        <div class="price-row price-row-chain">
          <span class="price-original">${formatNumberOnly(product.originalPrice)}</span>
          <span class="price-chain-arrow" aria-hidden="true">→</span>
          <span class="price-mid">${formatNumberOnly(product.salePrice)}</span>
          <span class="price-chain-arrow" aria-hidden="true">→</span>
          <span class="price-sale">${formatPrice(product.couponPrice)}</span>
        </div>
        <span class="price-save">${formatPrice(Math.max(product.originalPrice - product.couponPrice, 0))} 절약</span>
      </div>`
    : product.discountRate > 0
    ? `<div class="price-block">
        ${couponTagHtml}
        <div class="price-row">
          <span class="price-original">${formatNumberOnly(product.originalPrice)}</span>
          <span class="price-sale">${formatPrice(product.salePrice)}</span>
        </div>
        <span class="price-save">${formatPrice(saveAmount)} 절약</span>
      </div>`
    : `<div class="price-block"><div class="price-row"><span class="price-sale">${formatPrice(product.salePrice)}</span></div></div>`;
  // 특이사항 문구 길이가 제각각이라(예: "4+1증정" vs "2개 구매시 육수 증정") 고정 폰트 크기로는
  // 짧은 건 헐렁하고 긴 건 줄임표(...)로 잘린다 — 글자 수 구간별로 폰트를 줄여 한 줄에 맞춘다.
  const noteText = product.note && product.note.trim() !== "" ? product.note.trim() : "";
  let noteHtml = "";
  if (noteText) {
    const displayLen = noteText.length;
    let noteFontRem = 1.37;
    if (displayLen > 6) noteFontRem = 1.05;
    if (displayLen > 10) noteFontRem = 0.86;
    if (displayLen > 14) noteFontRem = 0.72;
    // 즉석반찬(맛찬)의 "3개이상 구매 20%할인" 같은 문구는 다른 분류보다 길어서
    // 말줄임(...)으로 잘리면 내용을 알 수 없다 — 맛찬만 줄바꿈을 허용한다.
    const noteWrapClass = product.category === "snack_side" ? " note-badge-thumb-wrap" : "";
    noteHtml = `<span class="note-badge note-badge-thumb${noteWrapClass}" style="font-size: ${noteFontRem}rem;">${noteText}</span>`;
  }

  card.innerHTML = `
    <div class="product-thumb">
      ${noteHtml}
      ${badgeHtml}
      ${imageHtml}
      <span class="product-icon-wrap" aria-hidden="true">${product.icon || "🥬"}</span>
    </div>
    <div class="product-body">
      <p class="product-name">${product.name}</p>
      <p class="product-desc">${product.description}</p>
      ${priceHtml}
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
    const item = products[i];
    grid.appendChild(item.__isReservation ? buildReservationCard(item) : buildProductCard(item));
  }

  const shownAfter = grid.querySelectorAll(".product-card").length;
  const nudgeAlreadyShown = !!grid.querySelector(".product-nudge");
  if (!nudgeAlreadyShown && start < PRODUCT_NUDGE_AFTER && shownAfter >= PRODUCT_NUDGE_AFTER && shownAfter < products.length) {
    grid.appendChild(buildStoreNudgeCard());
  }

  renderProductLoadMoreButton(products, grid, loadMoreWrap);
}

// "더보기"로 한참 내려간 상태에서 다시 섹션 맨 위로 돌아갈 수 있게, 더보기 버튼 옆에 짝지어 보여준다.
function buildScrollTopButton(sectionId) {
  const btn = document.createElement("button");
  btn.type = "button";
  btn.className = "btn btn-outline btn-totop";
  btn.textContent = "▲ 처음으로";
  btn.addEventListener("click", () => {
    document.getElementById(sectionId)?.scrollIntoView({ behavior: "smooth", block: "start" });
  });
  return btn;
}

function renderProductLoadMoreButton(products, grid, loadMoreWrap) {
  if (!loadMoreWrap) return;
  loadMoreWrap.innerHTML = "";

  const shownCount = grid.querySelectorAll(".product-card").length;
  // 품목이 적어 "더보기"가 필요 없어도 "처음으로"는 항상 보여준다(분류를 눌러 내려본 뒤 돌아가기 위함).
  if (shownCount < products.length) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "btn btn-outline btn-loadmore";
    btn.textContent = `더보기 (${shownCount}/${products.length})`;
    btn.addEventListener("click", () => renderNextProductBatch(products, grid, loadMoreWrap));
    loadMoreWrap.appendChild(btn);
  }
  loadMoreWrap.appendChild(buildScrollTopButton("products"));
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
  { value: "snack", label: "간식", icon: "🍪" },
  { value: "seafood_coupon", label: "수산쿠폰", icon: "🎟️" },
  { value: "snack_side", label: "즉석반찬(맛찬)", icon: "🍱" },
  { value: "sanitary", label: "생리대", icon: "🌸" },
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
  생리대: { category: "sanitary" },
  생리용품: { category: "sanitary" },
  수산쿠폰: { category: "seafood_coupon" },
  쿠폰: { category: "seafood_coupon" },
  간식: { category: "snack" },
  디저트: { category: "snack" },
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

// 카테고리 칩은 검색어가 없을 때만 적용된다. 검색어를 입력한 순간부터는 선택된 카테고리를
// 무시하고 주간할인(products)+사전예약(reservations) 전체 범위에서 찾는다.
function renderProductFilter(allProducts, allReservations, grid, loadMoreWrap, filterWrap, searchInput) {
  if (!filterWrap) return;

  const presentCategories = new Set(allProducts.map((p) => p.category));
  const chips = CATEGORY_LABELS.filter((c) => c.value === "all" || presentCategories.has(c.value));

  const state = { category: "all", query: "" };

  function applyFilters() {
    let filtered;
    if (state.query.trim()) {
      const productMatches = allProducts.filter((p) => matchesSearchQuery(p, state.query));
      const reservationMatches = allReservations
        .filter((r) => matchesSearchQuery(r, state.query))
        .map((r) => ({ ...r, __isReservation: true }));
      filtered = [...productMatches, ...reservationMatches];
    } else if (state.category === "all") {
      // hideFromAll(예: 수산쿠폰 중 "정가→최종가" 2단만 있는 품목)은 전체 목록엔 안 보이고
      // 해당 카테고리 칩을 직접 눌렀을 때만 노출한다.
      filtered = allProducts.filter((p) => !p.hideFromAll);
    } else {
      filtered = allProducts.filter((p) => p.category === state.category);
      // "수산쿠폰" 칩을 직접 눌렀을 때만 적용되는 전용 정렬: 3단(정상가→주간할인→쿠폰가, hasCoupon)
      // 품목을 먼저 할인율 높은 순으로, 그다음 2단(정상가→할인가) 품목을 할인가 높은 순으로 배치한다.
      // (전체 목록에서의 노출 순서는 그대로 두고 이 칩 안에서만 다르게 정렬)
      if (state.category === "seafood_coupon") {
        filtered = filtered.slice().sort((a, b) => {
          if (a.hasCoupon !== b.hasCoupon) return a.hasCoupon ? -1 : 1;
          return a.hasCoupon ? b.discountRate - a.discountRate : b.salePrice - a.salePrice;
        });
      }
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
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "filter-chip";
    btn.setAttribute("role", "tab");
    btn.setAttribute("aria-selected", idx === 0 ? "true" : "false");
    // "전체" 옆 숫자는 hideFromAll 예외 때문에 "전체 상품 수"와 정확히 안 맞아 오해를 살 수 있어 뺀다.
    // 나머지 카테고리 칩은 그 분류 실제 개수를 그대로 보여준다.
    if (c.value === "all") {
      btn.textContent = `${c.icon} ${c.label}`;
    } else {
      const count = allProducts.filter((p) => p.category === c.value).length;
      btn.textContent = `${c.icon} ${c.label} (${count})`;
    }
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

  // 최초 렌더링도 반드시 이 함수를 거쳐야 hideFromAll(수산쿠폰 2단 품목 등)이
  // "전체" 초기 화면에서도 제대로 걸러진다 — 호출부에서 별도로 renderNextProductBatch를
  // 직접 부르면 이 필터를 건너뛰게 되므로 여기서 한 번 실행해준다.
  applyFilters();
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

    // 검색어를 입력하면 카테고리 구분 없이 주간할인+사전예약 전체 범위에서 찾아야 하므로
    // 사전예약 데이터도 미리 받아둔다(검색 안 할 땐 안 쓰이는 데이터라 실패해도 무시).
    let reservations = [];
    try {
      const reservationData = await fetchJSON("data/reservations.json");
      reservations = reservationData.reservations || [];
    } catch (err) {
      console.error(err);
    }

    renderProductFilter(products, reservations, grid, loadMoreWrap, filterWrap, searchInput);
  } catch (err) {
    console.error(err);
    grid.innerHTML = `<p class="product-grid-status">할인 생활재 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.</p>`;
  }
}

/* ------------------------------------------------------------- 사전예약 */

// 사전예약 가격은 세 가지 패턴이 있다.
// A) 정가만(상시가격 없음): 할인 아님 — 정가로만 표시, 배지 없음
// B) 정가 -> 할인가(2단): 주간할인과 동일한 discount-badge(오른쪽 상단) 사용
// C) 정가 -> 할인가 -> 쿠폰적용가(3단, 수산쿠폰): 세 값을 화살표로 이어서 표시 + 가격 위에 쿠폰 안내 태그
function buildReservationPriceBlock(item) {
  if (item.originalPrice == null) {
    return `
      <div class="price-block">
        <div class="price-row">
          <span class="price-sale">${formatPrice(item.salePrice)}</span>
        </div>
      </div>
    `;
  }

  if (item.hasCoupon && item.couponPrice != null) {
    const saveAmount = Math.max(item.originalPrice - item.couponPrice, 0);
    return `
      <div class="price-block">
        <span class="coupon-tag">🐟 수산쿠폰</span>
        <div class="price-row price-row-chain">
          <span class="price-original">${formatNumberOnly(item.originalPrice)}</span>
          <span class="price-chain-arrow" aria-hidden="true">→</span>
          <span class="price-mid">${formatNumberOnly(item.salePrice)}</span>
          <span class="price-chain-arrow" aria-hidden="true">→</span>
          <span class="price-sale">${formatPrice(item.couponPrice)}</span>
        </div>
        <span class="price-save">${formatPrice(saveAmount)} 절약</span>
      </div>
    `;
  }

  // hasCoupon인데 couponPrice가 따로 없는 경우(수산쿠폰 2단: 정상가→할인가만 있음) —
  // 체인 표시 대신 일반 2단 가격에 쿠폰 태그만 붙여서 "왜 이 가격인지" 알려준다.
  const saveAmount = Math.max(item.originalPrice - item.salePrice, 0);
  const couponTagHtml = item.hasCoupon ? `<span class="coupon-tag">🐟 수산쿠폰</span>` : "";
  return `
    <div class="price-block">
      ${couponTagHtml}
      <div class="price-row">
        <span class="price-original">${formatNumberOnly(item.originalPrice)}</span>
        <span class="price-sale">${formatPrice(item.salePrice)}</span>
      </div>
      <span class="price-save">${formatPrice(saveAmount)} 절약</span>
    </div>
  `;
}

function buildReservationCard(item) {
  const card = document.createElement("article");
  card.className = "product-card reservation-card";

  const imageHtml = item.image
    ? `<img class="product-image" src="${item.image}" alt="${item.name}" loading="lazy" onerror="this.remove();" />`
    : "";

  // 할인율은 주간할인과 완전히 동일한 discount-badge(오른쪽 상단, 같은 크기)로 표시한다.
  const badgeHtml = item.discountRate != null
    ? `<span class="discount-badge" aria-hidden="true"><strong>${item.discountRate}<span class="unit">%</span></strong><span class="badge-sub">할인</span></span>`
    : "";

  card.innerHTML = `
    <div class="product-thumb">
      ${badgeHtml}
      ${imageHtml}
      <span class="product-icon-wrap" aria-hidden="true">${item.icon || "📦"}</span>
    </div>
    <div class="product-body">
      <p class="product-name">${item.name}</p>
      <p class="product-desc">${item.description || ""}</p>
      ${buildReservationPriceBlock(item)}
      ${item.directShip ? `<span class="reservation-date-badge">🚚 직송</span>` : item.supplyDate ? `<span class="reservation-date-badge">공급: ${item.supplyDate}</span>` : ""}
    </div>
  `;
  return card;
}

const RESERVATION_PAGE_SIZE = 12;

function renderNextReservationBatch(items, grid, loadMoreWrap) {
  const start = grid.querySelectorAll(".product-card").length;
  const end = Math.min(start + RESERVATION_PAGE_SIZE, items.length);
  for (let i = start; i < end; i++) {
    grid.appendChild(buildReservationCard(items[i]));
  }
  renderReservationLoadMoreButton(items, grid, loadMoreWrap);
}

function renderReservationLoadMoreButton(items, grid, loadMoreWrap) {
  if (!loadMoreWrap) return;
  loadMoreWrap.innerHTML = "";
  const shownCount = grid.querySelectorAll(".product-card").length;
  if (shownCount < items.length) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "btn btn-outline btn-loadmore";
    btn.textContent = `더보기 (${shownCount}/${items.length})`;
    btn.addEventListener("click", () => renderNextReservationBatch(items, grid, loadMoreWrap));
    loadMoreWrap.appendChild(btn);
  }
  loadMoreWrap.appendChild(buildScrollTopButton("reservation"));
}

// 품목 수가 적어 테마별로 잘게 나누지 않고, 주간할인과 같은 큰 카테고리로만 묶는다.
const RESERVATION_CATEGORY_LABELS = [
  { value: "jeju_pork", label: "제주흑돼지", icon: "🐖" },
  { value: "meat", label: "정육", icon: "🥩" },
  { value: "seafood", label: "수산", icon: "🐟" },
  { value: "processed", label: "가공·반찬", icon: "🧂" },
  { value: "health", label: "면역·건강보조", icon: "🍯" },
  { value: "living", label: "생활용품", icon: "🧴" },
];

function renderReservationFilter(allItems, grid, loadMoreWrap, filterWrap) {
  if (!filterWrap) return;

  const presentCategories = new Set(allItems.map((it) => it.category));
  const chips = [
    { value: null, label: "전체", icon: "🏷️" },
    ...RESERVATION_CATEGORY_LABELS.filter((c) => presentCategories.has(c.value)),
  ];

  const state = { category: null };

  function applyFilter() {
    const filtered = state.category == null ? allItems : allItems.filter((it) => it.category === state.category);
    grid.innerHTML = "";
    if (filtered.length === 0) {
      grid.innerHTML = `<p class="product-grid-status">해당 분류의 사전예약 생활재가 없습니다.</p>`;
      if (loadMoreWrap) loadMoreWrap.innerHTML = "";
      return;
    }
    renderNextReservationBatch(filtered, grid, loadMoreWrap);
  }

  filterWrap.innerHTML = "";
  chips.forEach((c, idx) => {
    const count = c.value == null ? allItems.length : allItems.filter((it) => it.category === c.value).length;
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
      applyFilter();
    });
    filterWrap.appendChild(btn);
  });
}

async function initReservations() {
  const grid = document.getElementById("reservation-grid");
  const loadMoreWrap = document.getElementById("reservation-grid-loadmore");
  const filterWrap = document.getElementById("reservation-filter");
  if (!grid) return;

  grid.innerHTML = `<p class="product-grid-status">사전예약 생활재를 불러오는 중입니다...</p>`;

  try {
    const data = await fetchJSON("data/reservations.json");
    grid.innerHTML = "";
    const items = data.reservations || [];
    if (items.length === 0) {
      grid.innerHTML = `<p class="product-grid-status">현재 등록된 사전예약 생활재가 없습니다.</p>`;
      return;
    }

    renderReservationFilter(items, grid, loadMoreWrap, filterWrap);
    renderNextReservationBatch(items, grid, loadMoreWrap);
  } catch (err) {
    console.error(err);
    grid.innerHTML = `<p class="product-grid-status">사전예약 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.</p>`;
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
  initReservations();
  initStoreFinder();
  initAllStoresList();
});
