# F72 OMEGA — MetaTrader 5

> *"Is the story still alive?"*

A persistent multi-timeframe curve organism for MetaTrader 5. Not an EA in the conventional sense — a synthetic nervous system whose only job is to maintain continuous awareness of the life of the story, with entries, exits, scaling and hedging following as **consequences** of that awareness.

---

## The Trinity

Every other module feeds these. Every decision reads only these.

| Variable | 0..100 | Question it answers | Owned by |
|---|---|---|---|
| **LifeScore**       | 0–100 | Is the story still alive? | Force, Ownership, Chain, Compression |
| **StoryStability**  | 0–100 | How stable is the narrative? | Alignment, Narrative, Regime |
| **StoryConfidence** | 0–100 | How much do I trust myself? | SelfObservation (rolling self-audit) |

`Risk`, `Capital`, and `Execution` only ever read these three. They cannot read raw signals. **Risk does not sit outside the narrative.**

---

## Strict module dependency hierarchy

```
Universe → Curve → Compression → Convexity → Force → Ownership
   → Recursion → Chain → Narrative → LifeScore → StoryStability
   → StoryConfidence → Risk → Capital → Execution
```

A module may only read modules **above** it. It may only write to its own state. The Trinity is the gate; the engine has no other valid signal path.

---

## Phase roadmap

This repo delivers the engine in compile-clean, runnable phases. Each phase plugs into the same architecture without breaking earlier phases.

| Phase | Status | Modules | What you can do |
|---|---|---|---|
| **1 · Skeleton** | ✅ shipped | `EA · Common · Logger · Memory · CampaignDB · Capital · Risk · PaperTrade · Execution · Session · News` | Attach in OBSERVER mode, watch heartbeat + capital + trinity neutrality logged every N seconds |
| **2 · Curve physics** | ✅ shipped | `Curve/CurvePhysics · CurveState · Compression · Convexity · Force · Curve` | Per-TF f_se / f_phys port across M1/M3/M5/M15/H1/H4. The Trinity becomes primed once the chart-TF curve is ready: LifeScore receives Force; supporting fields receive Compression, Convexity, MTF Alignment. |
| **3 · Curve tree** | planned | `CurveNode · Ownership · Transfer · Merge · ChainHealth` | Recursive tree, ownership-by-energy, chain vitality |
| **4 · Narrative** | planned | `Story · LifeScore · NarrativeScore · Alignment · Confidence` | Trinity becomes primed; `LifeScore` and `StoryStability` go live |
| **5 · Campaign positions** | planned | `Execution+ · PositionHealth · CampaignPositions` | Origin / Entry / Progression / Terminal positions, pyramiding, hedge transfer |
| **6 · Self-observation** | planned | `Probability · SelfObservation · Capital throttle+` | Layer 12–14: probability clouds, confidence decay, regime detection |
| **7 · Backtesting** | planned | `Replay · Shadow · Optimization · News+` | Replay walks, shadow comparison, parameter study, news feed |

Every later phase is **additive** — it sets `g_state.primed = true` once it has populated `OmegaSupporting` fields, and `OmegaState::DeriveTrinity()` folds them upward without any change to upstream modules.

---

## File tree

```
MT5/F72_Omega/
├─ EA.mq5                       — main lifecycle (OnInit/Tick/Timer/TradeTransaction)
├─ Include/
│  ├─ Common.mqh                — enums, constants, Math/Str helpers
│  ├─ Logger.mqh                — explainability backbone (3 CSV sinks + Print)
│  ├─ Memory.mqh                — OmegaState · the Trinity container
│  ├─ CampaignDB.mqh            — immortal campaign memory · JSON shards
│  ├─ Capital.mqh               — equity/drawdown state machine + Throttle()
│  ├─ Risk.mqh                  — dynamic 0.25–2% sizing from the Trinity
│  ├─ PaperTrade.mqh            — order shell · live in AUTONOMOUS only
│  ├─ Execution.mqh             — decision gate (capital → risk → order)
│  ├─ Session.mqh               — informational session context
│  ├─ News.mqh                  — informational news hooks (Phase 7 wires feed)
│  └─ Curve/                    — perception (Phase 2)
│     ├─ CurvePhysics.mqh       — vel/acc/conv/csm/eff/disp + impulse/decay flags
│     ├─ CurveState.mqh         — full f_se port: pivots, BOS/CHoCH, spawn engine,
│     │                          flip zone, point4, cycle extremes, inducement
│     ├─ Compression.mqh        — compression index + tightening tracker
│     ├─ Convexity.mqh          — convexity score / shift sign / maturity
│     ├─ Force.mqh              — composite force (compression persistence)
│     └─ Curve.mqh              — multi-TF orchestrator + supporting writer
└─ README.md                    — this file
```

---

## Install

1. Copy the `F72_Omega/` folder into your MT5 data directory at:
   ```
   <MT5 data folder>/MQL5/Experts/F72_Omega/
   ```
   (Find your data folder via *MetaTrader → File → Open Data Folder*.)

2. Open MetaEditor, navigate to *Experts/F72_Omega/EA.mq5*, hit **Compile**.
   You should see **0 errors, 0 warnings**.

3. Attach `EA` to a chart (XAUUSD H1 is a good first pick). Default mode is **OBSERVER** — no orders.

4. Open the *Experts* tab and the *Files/F72_Omega/logs/* directory in your data folder. You'll see the heartbeat firing and the CSV sinks populating.

---

## Modes

| Mode | Live orders | Use case |
|---|---|---|
| **OBSERVER**   | no  | Watch the engine perceive. The default. |
| **COPILOT**    | no (Phase 5+) | Engine emits decisions, human approves. |
| **PAPER**      | no  | Decisions logged, full simulation; for backtests. |
| **SHADOW**     | no  | Engine runs alongside a live system, comparison logged. |
| **AUTONOMOUS** | YES | Engine controls fully. Only enable after live-tested. |

---

## Risk philosophy

Static risk contradicts the philosophy. Risk **breathes** with the trinity:

| Conviction | Trinity gate | Per-trade risk |
|---|---|---|
| Base        | not primed                         | `0.25%` |
| Normal      | L≥45, S≥45, C≥40                   | `0.50%` |
| Strong      | L≥60, S≥60, C≥55                   | `1.00%` |
| Exceptional | L≥75, S≥75, C≥70                   | `2.00%` |

Plus a continuous **capital throttle** (0..1) that decays risk smoothly toward zero as drawdown approaches its limits — `daily 3%`, `weekly 8%`, `hard 15%`.

---

## Persistent memory layout

```
MQL5/Files/F72_Omega/
├─ campaigns/
│  ├─ XAUUSD/
│  │  ├─ campaign_2025_000001.json
│  │  └─ campaign_2025_000002.json
│  ├─ EURUSD/
│  └─ ...
├─ rolling/
│  ├─ chain_memory.json
│  ├─ statistics.json
│  ├─ story_history.json
│  ├─ confidence_history.json
│  └─ regime_memory.json
├─ logs/
│  ├─ decision_log.csv     — every decision + trinity snapshot
│  ├─ execution_log.csv    — every order or paper-order
│  └─ exception_log.csv
├─ backtests/
├─ paper/
└─ exports/
```

`campaigns/` and `logs/` are written from Phase 1. `rolling/` is populated by Phase 4+.

---

## Inputs (Phase 1)

```
═══ Mode ═══
  InpMode             — OBSERVER / COPILOT / AUTONOMOUS / PAPER / SHADOW
  InpMagic            — magic number for own orders

═══ Risk (dynamic) ═══
  InpBaseRiskPct      — 0.25
  InpNormalRiskPct    — 0.50
  InpStrongRiskPct    — 1.00
  InpExcepRiskPct     — 2.00
  InpHardCeilingPct   — 2.00

═══ Capital — circuit breakers ═══
  InpDailyLossLimit   — 3.0
  InpWeeklyLossLimit  — 8.0
  InpHardLimit        — 15.0

═══ Logging ═══
  InpLogLevel         — DEBUG / INFO / DECISION / EXECUTION / WARNING / EXCEPTION

═══ Engine ═══
  InpHeartbeatSec     — 5

═══ Curve physics (Phase 2) ═══
  InpAtrLen           — 14    ATR length
  InpEffLen           — 10    Efficiency lookback
  InpEffThresh        — 0.65  Efficiency threshold
  InpDispThresh       — 1.5   Displacement threshold (ATR)
  InpConvMult         — 0.01  Convexity multiplier (ATR)
  InpPivotLen         — 5     Pivot length
  InpStructLen        — 10    Structure pivot length
  InpImpulseMult      — 1.5   Impulse ATR multiple
  InpChochBufATR      — 0.75  CHoCH buffer (ATR)
```

---

## Architectural invariants — do not violate

1. **Trinity is sacred.** Nothing reads `g_state.life`, `g_state.stability`, or `g_state.confidence` to *write back* into them. Lower modules only write `g_state.supporting.*`; `DeriveTrinity()` folds upward.
2. **No hidden signals.** Risk reads the Trinity; it does not read EMAs, MACDs, or any other raw indicator. If risk needs to react to a market property, that property must first be exposed through a supporting field.
3. **Explainability is mandatory.** Every decision is logged with reason code + trinity snapshot. Phase 6 SelfObservation will read these CSVs to detect contradiction.
4. **The engine never blacks out by clock.** Sessions and news are *context*, not vetoes.
5. **Capital sits below the trinity.** Drawdown affects the throttle (a multiplier), never the trinity itself.
6. **Hedge mode mandatory.** The engine must be able to hold buys and sells simultaneously (ownership transfer, counter-curves, scale).

---

## Verification checklist (after install)

- [ ] EA compiles with 0 errors, 0 warnings
- [ ] In OBSERVER mode the *Experts* tab shows `[INFO][EA] F72 OMEGA 1.0.0-phase1 ...` once on init
- [ ] Heartbeat lines appear every `InpHeartbeatSec` seconds with `cap=HEALTHY` + trinity snapshot + `curve[...]` snapshot
- [ ] After ~10 closed bars on the chart timeframe, heartbeat shows `primed=YES` and reason becomes `HEARTBEAT` (not `PHASE_NOT_BUILT`)
- [ ] `MQL5/Files/F72_Omega/logs/decision_log.csv` is populated
- [ ] No orders are placed
- [ ] `GlobalVariable` `F72_OMEGA_NEXT_CAMPAIGN_ID` exists with value `1`

If all seven are green, Phase 2 is verified and we're ready for Phase 3 (curve tree).

---

## License & credits

Internal F72 OMEGA build. Architecture authored collaboratively; implementation by Kiro.
