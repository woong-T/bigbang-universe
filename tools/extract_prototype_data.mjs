// 프로토타입(prototype/index.html)의 게임 데이터를 data/*.json 으로 뽑아내는 스크립트.
// 사용법: node tools/extract_prototype_data.mjs
// 선택지 효과(fx 함수)는 Godot 쪽에서 읽을 수 있는 "효과 목록(effects)"으로 바꿔 저장한다.
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const html = fs.readFileSync(path.join(root, "prototype/index.html"), "utf8");

// SAGES 부터 SEEDS 끝까지(그림 데이터 VIS_STAGE 직전)를 잘라 실행한다.
const start = html.indexOf("const SAGES=");
const end = html.indexOf("// ---------- 그림 칸");
if (start < 0 || end < 0) throw new Error("프로토타입에서 데이터 구간을 찾지 못했어요.");
const src = html.slice(start, end) + "\n;({SAGES,GAUGES,STAGES,EVENTS,ENDINGS,SEEDS,VIS_STAGE:null})";
const ctx = { Math, clamp: (v, a = 0, b = 100) => Math.max(a, Math.min(b, v)) };
vm.createContext(ctx);
const D = vm.runInContext(src, ctx);

// ---------- fx 함수 → effects 변환 ----------
const NUM = String.raw`-?\d*\.?\d+`;
function parseStatements(body) {
  const ops = [];
  for (let raw of body.split(";")) {
    const t = raw.trim();
    if (!t) continue;
    let m;
    if ((m = t.match(new RegExp(String.raw`^s\.(\w+)\+=rnd\((${NUM}),(${NUM})\)$`))))
      ops.push({ op: "add_random", key: m[1], min: +m[2], max: +m[3] });
    else if ((m = t.match(new RegExp(String.raw`^s\.(\w+)\+=\((${NUM})-s\.\1\)\*(${NUM})$`))))
      ops.push({ op: "move_toward", key: m[1], target: +m[2], amount: +m[3] });
    else if ((m = t.match(new RegExp(String.raw`^s\.(\w+)(\+|-)=(${NUM})$`))))
      ops.push({ op: "add", key: m[1], value: m[2] === "-" ? -m[3] : +m[3] });
    else if ((m = t.match(new RegExp(String.raw`^s\.(\w+)=(${NUM})\+\(s\.\1-(${NUM})\)\*(${NUM})(?:\+rnd\((${NUM}),(${NUM})\))?$`)))) {
      ops.push({ op: "scale_from", key: m[1], center: +m[2], factor: +m[4] });
      if (m[5] !== undefined) ops.push({ op: "add_random", key: m[1], min: +m[5], max: +m[6] });
    } else if ((m = t.match(new RegExp(String.raw`^s\.(\w+)=(${NUM})$`))))
      ops.push({ op: "set", key: m[1], value: +m[2] });
    else if ((m = t.match(/^f\.(\w+)=1$/)))
      ops.push({ op: "flag", flag: m[1] });
    else throw new Error("해석하지 못한 효과: " + t);
  }
  return ops;
}
// 주사위: if(Math.random()<p){...;st.diceRes="..."}else{...;st.diceRes="..."}
function parseDice(body) {
  const m = body.match(/(?:const r=Math\.random\(\);)?if\((?:Math\.random\(\)|r)<([\d.]+)\)\{(.*?)st\.diceRes="(.*?)"\}else\{(.*?)st\.diceRes="(.*?)"\}/);
  if (!m) throw new Error("주사위 효과를 해석하지 못했어요: " + body);
  return [
    { chance: +m[1], effects: parseStatements(m[2]), result: m[3] },
    { chance: +(1 - m[1]).toFixed(4), effects: parseStatements(m[4]), result: m[5] },
  ];
}
function fxToData(fn) {
  const s = fn.toString();
  const body = s.slice(s.indexOf("{") + 1, s.lastIndexOf("}"));
  if (body.includes("Math.random")) return { dice: parseDice(body) };
  return { effects: parseStatements(body) };
}
function choice(c, extra = {}) {
  const o = { text: c.t };
  if (c.s) o.subtitle = c.s;
  if (c.who) o.sage = c.who;
  Object.assign(o, fxToData(c.fx));
  if (c.res) o.result = c.res;
  return Object.assign(o, extra);
}

// ---------- 각 데이터 ----------
const sages = Object.entries(D.SAGES).map(([id, v]) => ({ id, name: v.n, year: v.y, desc: v.d, claim: v.c, theory: v.t, verdict: v.v }));

const gauges = D.GAUGES.map(g => {
  const o = { key: g.k, name: g.n, subtitle: g.sub, good_min: g.lo, good_max: g.hi };
  if (g.map) o.display_offset = 50; // LIFE 는 0 기준이라 화면에는 +50 해서 보여 준다
  return o;
});

const stages = D.STAGES.map((x, i) => ({
  index: i,
  id: x.scene,
  era: x.era,
  short: x.short,
  time: x.time,
  temperature: x.temp,
  desc: x.desc,
  term: { word: x.term[0], meaning: x.term[1] },
  choices: x.choices.map(c => choice(c)),
}));
// 상태에 따라 바뀌는 시대 설명(프로토타입 stageView). mode: replace / prefix / suffix. 위에서부터 처음 맞는 것 하나 + suffix 는 따로.
const DESC_VARIANTS = {
  8: [{ when: { flag: "noinf" }, mode: "prefix", text: "인플레이션이 부족해서 공간이 아직 쭈글쭈글해요. 어떤 곳은 너무 빽빽하고 어떤 곳은 텅 비었어요. " }],
  9: [
    { when: { key: "DM", op: "<=", value: 0 }, mode: "replace", time: "5억 ~ 20억 년", text: "암흑물질이 없어서 가스가 한참 늦게야 뭉쳤어요. 다른 우주보다 수억 년 늦게, 드디어 첫 별이 불을 켜요! 어떤 별이 먼저 태어날까요?" },
    { when: { flag: "hot" }, mode: "replace", text: "빠른 암흑물질이 작은 덩어리를 지워서, 거대한 가스 판이 먼저 생기고 그것이 쪼개지며 별이 태어나요. 어떤 별이 먼저 태어날까요?" },
  ],
  10: [
    { when: { key: "DM", op: "<=", value: 0 }, mode: "replace", text: "암흑물질이 없어서 은하라고 부를 만한 큰 무리가 거의 없어요. 작은 별 무리들이 서로 멀어지고 있어요. 우주가 얼마나 빨리 커지는지 정해 볼까요?" },
    { when: { flag: "bhfirst" }, mode: "replace", text: "블랙홀이 먼저 자란 우주예요. 은하 중심마다 밝은 퀘이사가 빛나요. 은하들은 서로 멀어지고 있어요. 우주가 얼마나 빨리 커지는지 정해 볼까요?" },
  ],
  11: [{ when: { flag: "steady" }, mode: "replace", text: "이 우주는 빈 곳에서 새 물질이 생겨나며 늘 같은 모습을 유지하려고 해요. 그래도 빈 공간의 '미는 힘'(우주상수 Λ)은 정해야 해요. 얼마나 셀까요?" }],
};
for (const s of stages) {
  const v = [...(DESC_VARIANTS[s.index] || [])];
  if (s.index >= 8) v.push({ when: { flag: "anti" }, mode: "suffix", text: " (이 우주의 원자는 모두 반물질이에요.)" });
  if (v.length) s.desc_variants = v;
}

// cond 함수는 손으로 옮긴다(3개뿐).
const EVENT_COND = {
  monopole: { flag: "noinf" },
  bubble: { flag: "multi" },
  pigeon: { not_sage: "penzias" },
};
const events = D.EVENTS.map(e => {
  const o = { id: e.id, after_stages: e.after, title: e.title, desc: e.desc };
  if (EVENT_COND[e.id]) o.condition = EVENT_COND[e.id];
  if (e.dice) o.dice = true;
  if (e.id === "monopole" || e.id === "bubble") o.forced = true;
  o.choices = e.choices.map(c => choice(c));
  return o;
});

// pickEnding / diffs 의 조건을 데이터로 옮긴 것(프로토타입 420~435행과 같은 순서).
// when: all(모두 만족) / any(하나라도) 조합. 항목은 {key, op, value} 또는 {flag}.
const c = (key, op, value) => ({ key, op, value });
const ENDING_RULES = {
  vacuum: { flag: "vac" },
  annihil: c("M", "<=", 5),
  early: c("D", ">=", 88),
  rip: c("L", ">=", 90),
  static: { flag: "stat" },
  crunch: { any: [{ all: [c("L", "<=", 35), c("D", ">=", 54)] }, { all: [c("L", "<=", 70), c("D", ">=", 72)] }] },
  empty: { any: [c("L", ">=", 75), c("D", "<=", 20)] },
  smooth: c("F", "<=", 16),
  bh: c("F", ">=", 84),
  lonely: c("DM", "<=", 0),
  chem: { any: [c("C", ">=", 78), c("C", "<=", 22)] },
  eds: c("L", "<=", 35),
  ours: { all: [c("L", ">=", 50), c("L", "<=", 70), c("D", ">=", 38), c("D", "<=", 62), c("F", ">=", 32), c("F", "<=", 68), c("M", ">=", 30), c("M", "<=", 70), c("C", ">=", 32), c("C", "<=", 68), c("DM", ">=", 25), c("DM", "<=", 80)] },
  unknown: null, // 기본값
};
// story 가 상태에 따라 갈리는 엔딩들
const ENDING_STORY = {
  static: { prefix: "미는 힘과 당기는 힘이 딱 맞서 우주가 멈췄어요. 아인슈타인이 1917년에 꿈꾼 변하지 않는 우주예요. 하지만 은하 하나만 뭉쳐도 균형이 깨져요. ",
    variants: [{ when: c("D", ">=", 50), text: "이 우주는 물질 쪽이 아주 조금 무거웠어요. 결국 쪼그라들기 시작했어요." }],
    default: "이 우주는 미는 힘이 아주 조금 셌어요. 결국 끝없이 빨리 커지기 시작했어요." },
  empty: { variants: [{ when: c("L", ">=", 75), text: "미는 힘이 너무 일찍 너무 셌어요. 가스가 뭉치기도 전에 서로 멀리 흩어졌어요. 은하는 드물고, 그마저 보이지 않을 만큼 멀어져요. 밤하늘에 아무것도 없어요." }],
    default: "우주가 너무 가벼웠어요. 중력이 서로를 붙잡지 못해 가스가 흩어졌어요. 별이 몇 개만 켜졌다 꺼지고, 우주는 텅 빈 채 차갑게 식어요." },
  chem: { variants: [{ when: c("C", ">=", 50), text: "헬륨이 넘치고 수소가 모자랐어요. 별은 밝고 짧게 살다 가고, 물을 만들 수소가 거의 없어요. 은하는 있지만 바다는 어디에도 없어요." }],
    default: "무거운 원소를 만드는 계단이 끊겼어요. 별은 빛나지만 탄소와 산소가 거의 없어서 행성과 생명의 재료가 모자라요." },
  unknown: { prefix: "우리 우주와 닮았지만 어딘가 달라요. ", use_diffs: true,
    diffs_suffix: " 우주가 태어났어요.", no_diffs: "아주 작은 차이들이 쌓여 낯선 하늘이 만들어졌어요.",
    suffix: " 이곳에 과학자가 있다면, 그들의 과학 교과서는 우리 것과 몇 쪽이 다를 거예요." },
};
const endings = {
  order_note: "위에서부터 차례로 검사해서 조건(when)을 처음 만족하는 엔딩이 결말이 된다. when 이 null 이면 항상 만족(기본값).",
  list: D.ENDINGS.map(e => {
    const o = { id: e.id, name: e.name, fate: e.fate, scene: e.scene, color: e.color, when: ENDING_RULES[e.id] ?? null };
    if (ENDING_STORY[e.id]) o.story = ENDING_STORY[e.id];
    else o.story = { default: e.story({}) };
    return o;
  }),
  // "미지의 우주" 설명에 붙는 차이점 문구(프로토타입 diffs 함수). 마지막 문구의 끝 "고"는 "는"으로 바꾼다.
  diffs: [
    [c("D", ">", 62), "조금 무거워 팽창이 느리고"],
    [c("D", "<", 38), "가벼워 은하가 드물고"],
    [c("F", ">", 68), "얼룩이 커서 거대한 은하 무리가 일찍 자라고"],
    [c("F", "<", 32), "매끈해서 은하가 늦게 생기고"],
    [c("C", ">", 68), "헬륨이 많아 별이 빨리 타고"],
    [c("C", "<", 32), "무거운 원소가 귀하고"],
    [c("DM", ">", 80), "암흑물질이 짙어 은하가 빽빽하고"],
    [{ all: [c("DM", ">", 0), c("DM", "<", 25)] }, "암흑물질이 옅고"],
    [c("M", ">", 70), "물질이 넘쳐나고"],
    [{ all: [c("M", ">", 0), c("M", "<", 30)] }, "물질이 귀하고"],
    [{ all: [c("L", ">", 35), c("L", "<", 50)] }, "미는 힘이 약하고"],
    [{ all: [c("L", ">", 70), c("L", "<", 75)] }, "미는 힘이 세고"],
    [{ flag: "hot" }, "큰 구조부터 쪼개져 생기고"],
  ].map(([when, text]) => ({ when, text })),
};
// 사용한 엔딩 조건과 프로토타입 로직이 같은지 대충 확인
for (const e of D.ENDINGS) if (!(e.id in ENDING_RULES)) throw new Error("엔딩 조건 누락: " + e.id);

const seeds = D.SEEDS.map(x => ({ name: x.n, desc: x.d, ...fxToData(x.fx) }));

// 게임 규칙(프로토타입 fresh / checkStop / maybeEvent / maybeVac)
const rules = {
  initial_state: { D: 50, F: 50, M: 50, C: 50, DM: 50, L: 50, LIFE: 0, age: 13.8 },
  initial_random: [{ op: "add_random", key: "D", min: -4, max: 4 }],
  clamp_keys: ["D", "F", "M", "C", "DM", "L"],
  clamp_min: 0,
  clamp_max: 100,
  seed_clamp_keys: ["D", "F"],
  events: {
    max_per_run: 5,
    base_chance: 0.4,
    catch_up_every_stages: 3,
    note: "시대가 끝날 때 after_stages 에 그 시대 번호가 있는 사건 중 하나가 나올 수 있다. forced 사건은 조건이 맞으면 반드시 나온다. 지금까지 나온 사건 수가 floor((시대+1)/3) 보다 적으면 확률 없이 나온다.",
  },
  vacuum_decay: { flag: "vac", from_stage: 4, chance: 0.3,
    text: "언덕 꼭대기에서 버티던 힉스 장이 마침내 더 깊은 골짜기로 굴러떨어졌어요. 새로운 진공의 거품이 빛의 속도로 퍼지며 질량과 힘의 규칙을 통째로 바꿔요." },
  // 중간에 우주가 끝나 버리는 조건. 위에서부터 검사.
  early_stops: [
    { stages: [3, 3], when: c("M", "<=", 5), ending: "annihil", text: "물질이 하나도 남지 않았어요. 원자를 만들 재료가 없으니 다음 시대는 오지 않아요." },
    { stages: [2, 8], when: c("D", ">=", 88), ending: "early", text: "우주가 너무 무거워요. 팽창이 멈추고 다시 쪼그라들기 시작했어요." },
    { stages: [9, 10], when: c("D", ">=", 88), ending: "crunch", text: "우주가 너무 무거워요. 팽창이 멈추고 다시 쪼그라들기 시작했어요." },
    { stages: [2, 10], when: c("D", "<=", 12), ending: "empty", text: "우주가 너무 가벼워요. 물질이 뭉치기도 전에 뿔뿔이 흩어져 버렸어요." },
    { stages: [7, 8], when: c("F", "<=", 16), ending: "smooth", text: "얼룩이 너무 작아 중력이 키울 씨앗이 없어요. 첫 별이 영영 태어나지 못해요." },
    { stages: [7, 10], when: c("F", ">=", 84), ending: "bh", text: "덩어리가 너무 커요. 별이 생기기 전에 모두 블랙홀로 무너져 버렸어요." },
    { stages: [10, 10], when: c("D", ">=", 72), ending: "crunch", text: "미는 힘이 드러나기도 전에 중력이 팽창을 붙잡았어요. 우주가 되돌아오기 시작해요." },
  ],
};

const out = { sages, gauges, stages, events, endings, seeds, rules };
for (const [name, data] of Object.entries(out)) {
  fs.writeFileSync(path.join(root, "data", name + ".json"), JSON.stringify(data, null, 2) + "\n");
}
console.log(`stages ${stages.length}, choices ${stages.reduce((a, s) => a + s.choices.length, 0)}, events ${events.length}, endings ${endings.list.length}, sages ${sages.length}, seeds ${seeds.length}`);
