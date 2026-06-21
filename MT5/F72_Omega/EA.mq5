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
#include "Include/Execution.mqh"
#include "Include/Session.mqh"
#include "Include/News.mqh"

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

//================== GLOBALS =========================================
OmegaState     g_state;
OmegaCapital   g_capital;
OmegaRisk      g_risk;
CampaignDB     g_db;
OmegaExecution g_exec;
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

//--- 6. Execution shell
   g_exec.Init(InpMode, InpMagic, GetPointer(g_capital), GetPointer(g_risk), GetPointer(g_db));

//--- 7. Heartbeat
   EventSetTimer(MathMax(1, InpHeartbeatSec));

   OmegaLogger::LogInfo("EA",
      "Phase 1 skeleton initialized · perception layers (Curve / Force / Chain / Narrative) deferred to Phase 2+.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   OmegaLogger::LogInfo("EA",
      StringFormat("Shutting down · reason=%d · ticks=%I64d", reason, g_tickCount));
   OmegaLogger::Flush();
   OmegaLogger::Shutdown();
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

//--- Phase 1: trinity stays neutral (primed=false). Once Phase 2+
//    populates supporting fields, set g_state.primed = true and
//    DeriveTrinity() folds them up automatically.
   g_state.DeriveTrinity();
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
         "%s · cap=%s · dd(d/w/hard)=%.2f%%/%.2f%%/%.2f%% · throttle=%.2f · session=%s · news=%s · %s",
         _Symbol,
         OmegaStr::CapitalStateToString(g_capital.State()),
         g_capital.DailyDrawdownPct(),
         g_capital.WeeklyDrawdownPct(),
         g_capital.HardDrawdownPct(),
         g_capital.Throttle(),
         OmegaStr::SessionToString(OmegaSession::Current()),
         OmegaNews::Environment(),
         g_state.Snapshot()));

      //--- Phase 1: emit a single OBSERVE / PHASE_NOT_BUILT decision per
      //    heartbeat to demonstrate the explainability path. Once Phase 2+
      //    wires the engine, this is replaced by per-tick decisions
      //    emerging from the trinity.
      g_exec.HandleDecision(_Symbol, OMEGA_DEC_OBSERVE, REASON_PHASE_NOT_BUILT,
                             g_state, 0,
                             "Skeleton heartbeat — perception layers not built yet");

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
