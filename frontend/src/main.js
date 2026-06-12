const state = {
  scenario: "calm",
  base: 1,
  shock: 0.12,
  stable: 8,
  points: []
};

const fees = {
  low: { bps: 5, raw: 500, color: "#4fd1b3", label: "Calm regime" },
  med: { bps: 30, raw: 3000, color: "#e9b44c", label: "Normal volatility" },
  high: { bps: 100, raw: 10000, color: "#eb6a6f", label: "High volatility" }
};

const qs = (selector) => document.querySelector(selector);
const qsa = (selector) => [...document.querySelectorAll(selector)];

function feeForVol(vol) {
  if (vol < 0.001) return fees.low;
  if (vol < 0.005) return fees.med;
  return fees.high;
}

function generatePath() {
  const path = [];
  let price = state.base;
  const calmNoise = state.scenario === "calm" ? 0.0015 : 0.003;
  for (let i = 0; i < state.stable; i++) {
    price *= 1 + (i % 2 === 0 ? calmNoise : -calmNoise);
    path.push(price);
  }
  if (state.scenario !== "calm") {
    price *= 1 + state.shock;
    path.push(price);
    price *= 1 - state.shock * 0.45;
    path.push(price);
    price *= 1 + state.shock * 0.35;
    path.push(price);
  }
  const recovery = state.scenario === "recovery" ? state.stable * 3 : state.stable;
  for (let i = 0; i < recovery; i++) {
    const drift = (state.base - price) * 0.08;
    price += drift;
    path.push(price);
  }
  return path;
}

function runSimulation() {
  const path = generatePath();
  let previous = path[0];
  let ewma = 0;
  state.points = path.map((price, index) => {
    const move = index === 0 ? 0 : Math.abs(price - previous) / previous;
    ewma = (move + 9 * ewma) / 10;
    previous = price;
    return { index, price, move, ewma, fee: feeForVol(ewma) };
  });
  render();
}

function drawChart() {
  const canvas = qs("#feeChart");
  const ctx = canvas.getContext("2d");
  const { width, height } = canvas;
  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = "#11161b";
  ctx.fillRect(0, 0, width, height);

  const pad = 44;
  const plotW = width - pad * 2;
  const plotH = height - pad * 2;
  const maxVol = Math.max(0.006, ...state.points.map((p) => p.ewma)) * 1.25;

  ctx.strokeStyle = "#2b3138";
  ctx.lineWidth = 1;
  for (let i = 0; i <= 4; i++) {
    const y = pad + (plotH * i) / 4;
    ctx.beginPath();
    ctx.moveTo(pad, y);
    ctx.lineTo(width - pad, y);
    ctx.stroke();
  }

  const yFor = (vol) => pad + plotH - (vol / maxVol) * plotH;
  const xFor = (i) => pad + (i / Math.max(1, state.points.length - 1)) * plotW;

  ctx.setLineDash([8, 8]);
  [
    { value: 0.001, color: fees.low.color },
    { value: 0.005, color: fees.high.color }
  ].forEach((line) => {
    ctx.strokeStyle = line.color;
    ctx.beginPath();
    ctx.moveTo(pad, yFor(line.value));
    ctx.lineTo(width - pad, yFor(line.value));
    ctx.stroke();
  });
  ctx.setLineDash([]);

  ctx.lineWidth = 3;
  ctx.strokeStyle = "#72a7ff";
  ctx.beginPath();
  state.points.forEach((point, i) => {
    const x = xFor(i);
    const y = yFor(point.ewma);
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.stroke();

  state.points.forEach((point, i) => {
    ctx.fillStyle = point.fee.color;
    ctx.beginPath();
    ctx.arc(xFor(i), yFor(point.ewma), 5, 0, Math.PI * 2);
    ctx.fill();
  });

  ctx.fillStyle = "#a9b0a8";
  ctx.font = "14px ui-sans-serif, system-ui";
  ctx.fillText("EWMA volatility", pad, 24);
  ctx.fillText("swaps", width - pad - 38, height - 14);
}

function renderLedger() {
  const last = state.points[state.points.length - 1];
  const rows = [
    ["01", "beforeSwap", `Pool reads ${last.fee.bps} bps from hook storage`],
    ["02", "afterSwap", `Hook emits SwapPriceUpdate with sqrtPrice ${last.price.toFixed(4)}x`],
    ["03", "ReactVM", `RSC updates EWMA to ${(last.ewma * 100).toFixed(3)}%`],
    ["04", "Callback", `Fee tier maps to ${last.fee.raw} and queues updateFeeFromReactive`],
    ["05", "Next swap", `Pool uses ${last.fee.bps} bps without oracle or proof latency`]
  ];
  qs("#ledger").innerHTML = rows
    .map((row) => `<tr><td>${row[0]}</td><td>${row[1]}</td><td>${row[2]}</td></tr>`)
    .join("");
}

function render() {
  const last = state.points[state.points.length - 1];
  qs("#heroFee").textContent = `${last.fee.bps} bps`;
  qs("#heroRegime").textContent = last.fee.label;
  qs("#statusPill").textContent = `${state.points.length} swaps · EWMA ${(last.ewma * 100).toFixed(3)}%`;
  qs("#basePriceOut").textContent = `${Number(state.base).toFixed(2)}x`;
  qs("#shockSizeOut").textContent = `${Math.round(state.shock * 100)}%`;
  qs("#stableSwapsOut").textContent = state.stable;
  drawChart();
  renderLedger();
}

function bind() {
  qs("#basePrice").addEventListener("input", (event) => {
    state.base = Number(event.target.value);
    runSimulation();
  });
  qs("#shockSize").addEventListener("input", (event) => {
    state.shock = Number(event.target.value);
    runSimulation();
  });
  qs("#stableSwaps").addEventListener("input", (event) => {
    state.stable = Number(event.target.value);
    runSimulation();
  });
  qsa(".scenario").forEach((button) => {
    button.addEventListener("click", () => {
      qsa(".scenario").forEach((item) => item.classList.remove("active"));
      button.classList.add("active");
      state.scenario = button.dataset.scenario;
      runSimulation();
    });
  });
  qs("#runBtn").addEventListener("click", runSimulation);
  qs("#resetBtn").addEventListener("click", () => {
    state.scenario = "calm";
    state.base = 1;
    state.shock = 0.12;
    state.stable = 8;
    qs("#basePrice").value = state.base;
    qs("#shockSize").value = state.shock;
    qs("#stableSwaps").value = state.stable;
    qsa(".scenario").forEach((item) => item.classList.toggle("active", item.dataset.scenario === "calm"));
    runSimulation();
  });
  qs("#copyBtn").addEventListener("click", async () => {
    const ledger = qsa("#ledger tr").map((row) => row.innerText).join("\n");
    await navigator.clipboard.writeText(ledger);
    qs("#statusPill").textContent = "Ledger copied";
  });
  qs("#loadEnvBtn").addEventListener("click", () => {
    qs("#hookAddress").value = "VOLATILITY_FEE_HOOK";
    qs("#rscAddress").value = "VOLATILITY_FEE_RSC";
    qs("#poolId").value = "0x...";
  });
}

bind();
runSimulation();
if (window.lucide) window.lucide.createIcons();
