//+------------------------------------------------------------------+
//|                                                            EA.mq5|
//|                                                        F72 OMEGA |
//|                                                                  |
//|   "Is the story still alive?"                                    |
//|                                                                  |
//|   This is Phase 1 — the skeleton. The engine does NOT trade yet. |
//|   It boots the trinity, the capital state machine, the campaign  |
//|   memory, the structured logger, and the order shell. Once       |
//|   attached in OBSERVER mode it logs heartbeat decisions and      |
//|   capital state every InpHeartbeatSec seconds — proving the      |
//|   architecture is alive while explicitly stating it does not yet |
//|   perceive (REASON_PHASE_NOT_BUILT).                             |
//|                                                                  |
//|   Phase roadmap is in MT5/F72_Omega/README.md.                   |
//+------------------------------------------------------------------+
#property copyright "F72 OMEGA"
#property version   "1.00"
#property strict
#property description "F72 OMEGA — multi-timeframe curve organism."
#property description "Phase 1: skeleton + risk + memory + paper mode."
#property description "Trinity: LifeScore · StoryStability · StoryConfidence."

#include "Include/Common.mqh"
#include "Include/Logger.mqh"
#include "Include/Memory.mqh"
#include "Include/CampaignDB.mqh"
#include "Include/Capital.mqh"
#include "Include/Risk.mqh"
#include "Include/PaperTrade.mqh"
#include "Include/Position/PositionHealth.mqh"
#include "Include/Position/CampaignPositions.mqh"
#include "Include/Position/DecisionEngine.mqh"
#include "Include/Execution.mqh"
#include "Include/Session.mqh"
#include "Include/News.mqh"
#include "Include/Curve/Curve.mqh"
#include "Include/Narrative/Story.mqh"
#include "Include/Meta/Meta.mqh"
#include "Include/Backtest/Replay.mqh"
#include "Include/Backtest/Optimization.mqh"
#include "Include/Backtest/Shadow.mqh"

//================== INPUTS ==========================================
input group "═══ Mode (Layer: Human Override Philosophy) ═══"
input ENUM_OMEGA_MODE     InpMode             = OMEGA_MODE_OBSERVER;  // Operating mode
input ulong               InpMagic            = 7270001;              // Magic number

input group "═══ Risk (dynamic — driven by Trinity) ═══"
input double              InpBaseRiskPct      = 0.25;                 // Base risk per trade (%)
input double              InpNormalRiskPct    = 0.50;                 // Normal narrative (%)
input double              InpStrongRiskPct    = 1.00;                 // Strong narrative (%)
input double              InpExcepRiskPct     = 2.00;                 // Exceptional alignment (%)
input double              InpHardCeilingPct   = 2.00;                 // Per-trade hard ceiling (%)

input group "═══ Capital — drawdown circuit breakers ═══"
input double              InpDailyLossLimit   = 3.0;                  // Daily loss limit (%)
input double              InpWeeklyLossLimit  = 8.0;                  // Weekly loss limit (%)
input double              InpHardLimit        = 15.0;                 // Hard kill switch (%)

input group "═══ Logging ═══"
input ENUM_OMEGA_LOG_LEVEL InpLogLevel        = LOG_INFO;              // Log verbosity

input group "═══ Engine ═══"
input int                 InpHeartbeatSec     = 5;                    // Heartbeat / persistence cadence (s)

input group "═══ Curve physics (Phase 2) ═══"
input int                 InpAtrLen           = 14;                   // ATR length
input int                 InpEffLen           = 10;                   // Efficiency lookback
input double              InpEffThresh        = 0.65;                 // Efficiency threshold
input double              InpDispThresh       = 1.5;                  // Displacement threshold (ATR)
input double              InpConvMult         = 0.01;                 // Convexity multiplier (ATR)
input int                 InpPivotLen         = 5;                    // Pivot length
input int                 InpStructLen        = 10;                   // Structure pivot length
input double              InpImpulseMult      = 1.5;                  // Impulse ATR multiple
input double              InpChochBufATR      = 0.75;                 // CHoCH buffer (ATR)

input group "═══ Meta (Phase 6) ═══"
input double              InpSelfTrustBlend   = 0.30;                 // Self-trust blend into Confidence (0..1)

input group "═══ Backtest / Shadow (Phase 7) ═══"
input string              InpShadowTag        = "";                   // Shadow tag (empty=disable)

//================== GLOBALS =========================================
OmegaState        g_state;
OmegaCapital      g_capital;
OmegaRisk         g_risk;
CampaignDB        g_db;
CampaignPositions g_positions;   // Phase 5: campaign-aware position manager
OmegaExecution    g_exec;
OmegaCurve        g_curve;       // Phase 2: multi-TF perception
OmegaStory        g_story;       // Phase 4: narrative engine
OmegaMeta         g_meta;        // Phase 6: probability + self-observation + regime
OmegaNewsCalendar g_news;        // Phase 7: optional CSV calendar
ShadowLogger      g_shadow;      // Phase 7: optional parallel logger
DecisionParams    g_dparams;     // Phase 5: decision tunables
datetime       g_lastHeartbeat = 0;
long           g_tickCount     = 0;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- 1. Logger (everything else logs through it)
   OmegaLogger::Init(InpLogLevel);
   OmegaLogger::LogInfo("EA", StringFormat(
      "F72 OMEGA %s · symbol=%s · mode=%s · magic=%I64u · build=%d",
      OMEGA_VERSION, _Symbol, OmegaStr::ModeToString(InpMode), InpMagic,
      (int)TerminalInfoInteger(TERMINAL_BUILD)));

//--- 2. Trinity (state container)
   g_state.Reset();
   OmegaLogger::LogInfo("EA", "Trinity initialized neutral · " + g_state.Snapshot());

//--- 3. Capital state machine
   g_capital.Init(InpDailyLossLimit, InpWeeklyLossLimit, InpHardLimit);

//--- 4. Risk
   g_risk.Init(InpBaseRiskPct, InpNormalRiskPct, InpStrongRiskPct,
                InpExcepRiskPct, InpHardCeilingPct);

//--- 5. Campaign memory
   g_db.Init();

//--- 6. Execution shell + Position manager (Phase 5).
//    Init order: exec first (creates trade shell), then positions
//    (uses exec.TradeShell()), then exec.SetPositions(...) wires the
//    decision-handling path to the position manager.
   g_exec.Init(InpMode, InpMagic, GetPointer(g_capital), GetPointer(g_risk), GetPointer(g_db));
   g_positions.Init(_Symbol, InpMagic, g_exec.TradeShell(),
                     GetPointer(g_capital), GetPointer(g_risk), GetPointer(g_db));
   g_exec.SetPositions(GetPointer(g_positions));

//--- 7. Perception (Phase 2): multi-TF curve engine.
   if(!g_curve.Init(_Symbol, (ENUM_TIMEFRAMES)_Period,
                     InpPivotLen, InpStructLen, InpImpulseMult, InpChochBufATR,
                     InpAtrLen, InpEffLen, InpEffThresh, InpDispThresh, InpConvMult))
     {
      OmegaLogger::LogException("EA", -1, "Curve init failed — perception offline.");
     }

//--- 8. Narrative (Phase 4): LifeScore + NarrativeTracker + ConfidenceTracker.
   g_story.Init(_Symbol);

//--- 9. Meta (Phase 6): SelfObservation + Probability cloud + Regime.
   g_meta.Init(InpSelfTrustBlend);

//--- 10. News calendar (Phase 7, optional).
   g_news.Load();

//--- 11. Shadow logger (Phase 7, optional).
   if(InpShadowTag != "")
      g_shadow.Init(InpShadowTag);

//--- 12. Heartbeat
   EventSetTimer(MathMax(1, InpHeartbeatSec));

   OmegaLogger::LogInfo("EA",
      "Phases 1-7 online · Trinity LIVE · Engine ready to trade in mode " +
      OmegaStr::ModeToString(InpMode));
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_shadow.Shutdown();
   g_curve.Deinit();
   OmegaLogger::LogInfo("EA",
      StringFormat("Shutting down · reason=%d · ticks=%I64d", reason, g_tickCount));
   OmegaLogger::Flush();
   OmegaLogger::Shutdown();
  }

//+------------------------------------------------------------------+
//| OnTester — strategy-tester optimisation fitness                  |
//+------------------------------------------------------------------+
double OnTester()
  {
   return Optimization::OnTesterDefault();
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_tickCount++;
   g_state.tickCount = g_tickCount;
   g_state.updated   = TimeCurrent();

//--- Capital state machine — runs even before perception exists,
//    so circuit breakers protect equity from any external losses
//    on the account during testing.
   g_capital.Update();

//--- Phase 2: drive the multi-TF curve engine. Each CurveState
//    consumes its own bar-close events and updates per-TF
//    structure / physics. The curve writes the supporting fields,
//    DeriveTrinity() folds them upward.
   if(g_curve.Update())
     {
      g_curve.DeriveSupporting(g_state.supporting);
      g_state.primed = g_curve.primed;
      //--- Phase 4: narrative reads curve+tree and writes life/stability/
      //    confidence DIRECTLY into g_state. DeriveTrinity is now a clamp.
      bool storyAdvanced = g_story.Update(g_state, g_curve);
      g_state.DeriveTrinity();

      //--- Phase 6: meta layer overlays Self-Observation, Probability,
      //    Regime ON TOP of Story's trinity. Confidence gets blended
      //    with SelfTrust; supporting.regime + probability cloud now live.
      if(storyAdvanced)
        {
         g_meta.Update(g_state, g_curve, g_story);
         g_state.DeriveTrinity();
        }

      //--- Phase 5: each closed bar, ask the decision engine, route the
      //    answer through Execution → CampaignPositions, then trail stops.
      if(storyAdvanced)
        {
         int activeSame    = g_positions.CountActive(g_curve.tree.ownerDir);
         int activeCounter = g_positions.CountActive(-g_curve.tree.ownerDir);
         DecisionResult dr = DecisionEngine::Decide(g_state, g_curve, g_story,
                                                     activeSame, activeCounter, g_dparams);
         dr.stopDistPoints = DecisionEngine::ComputeStopDistPoints(_Symbol, g_curve,
                              dr.suggestedDirection != 0 ? dr.suggestedDirection : g_curve.tree.ownerDir,
                              g_dparams);
         long campaignId = (g_curve.tree.ownerIndex >= 0)
                            ? g_curve.tree.tree[g_curve.tree.ownerIndex].id : 0;
         g_meta.RecordDecision(dr.decision);
         g_exec.HandleDecision(_Symbol, dr.decision, dr.reason, g_state,
                                dr.stopDistPoints, dr.detail,
                                dr.suggestedRole, dr.suggestedDirection, campaignId);
         g_positions.BarUpdate(g_state, g_curve);
         g_shadow.Log(dr.decision, dr.reason, g_state.life, g_state.stability,
                       g_state.confidence, dr.detail);
        }
     }
   else g_state.DeriveTrinity();

   //-- per-tick: update MFE/MAE on every position
   g_positions.TickUpdate();
  }

//+------------------------------------------------------------------+
//| OnTimer — heartbeat & explainability                             |
//+------------------------------------------------------------------+
void OnTimer()
  {
   datetime now = TimeCurrent();
   if(g_lastHeartbeat == 0 || (now - g_lastHeartbeat) >= InpHeartbeatSec)
     {
      g_lastHeartbeat = now;

      OmegaLogger::LogInfo("HEARTBEAT", StringFormat(
         "%s · cap=%s · dd(d/w/hard)=%.2f%%/%.2f%%/%.2f%% · throttle=%.2f · session=%s · news=%s · %s · curve[%s] · story[%s] · pos[%s] · %s",
         _Symbol,
         OmegaStr::CapitalStateToString(g_capital.State()),
         g_capital.DailyDrawdownPct(),
         g_capital.WeeklyDrawdownPct(),
         g_capital.HardDrawdownPct(),
         g_capital.Throttle(),
         OmegaStr::SessionToString(OmegaSession::Current()),
         g_news.CurrentEnvironment(),
         g_state.Snapshot(),
         g_curve.Snapshot(),
         g_story.Snapshot(),
         g_positions.Snapshot(),
         g_meta.Snapshot()));

      //--- Phase 2: emit a HEARTBEAT decision so the explainability path
      //    keeps logging trinity + curve snapshot every interval. Once
      //    Phase 4 wires Narrative + LifeScore, real ENTER/HOLD/EXIT
      //    decisions emerge per tick from the trinity.
      ENUM_OMEGA_REASON reason = g_state.primed ? REASON_HEARTBEAT : REASON_PHASE_NOT_BUILT;
      g_exec.HandleDecision(_Symbol, OMEGA_DEC_OBSERVE, reason,
                             g_state, 0,
                             g_curve.primed
                              ? "Curve primed — narrative / chain pending Phase 3-4"
                              : "Curve warming up — waiting for chart-TF readiness");

      OmegaLogger::Flush();
     }
  }

//+------------------------------------------------------------------+
//| OnTradeTransaction — precise order tracking                      |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
//--- Phase 1: log every deal. Phase 5 will tie deals to campaign
//    positions and update PositionHealth.
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      OmegaLogger::LogInfo("TRADE", StringFormat(
         "Deal #%I64u · symbol=%s · type=%d · vol=%.2f · price=%.5f · order=#%I64u",
         trans.deal, trans.symbol, (int)trans.deal_type, trans.volume,
         trans.price, trans.order));
     }
   else if(trans.type == TRADE_TRANSACTION_ORDER_ADD)
     {
      OmegaLogger::LogInfo("TRADE", StringFormat(
         "Order added · #%I64u · symbol=%s · type=%d",
         trans.order, trans.symbol, (int)trans.order_type));
     }
   else if(trans.type == TRADE_TRANSACTION_ORDER_DELETE)
     {
      OmegaLogger::LogInfo("TRADE", StringFormat(
         "Order removed · #%I64u · symbol=%s",
         trans.order, trans.symbol));
     }
  }
//+------------------------------------------------------------------+
