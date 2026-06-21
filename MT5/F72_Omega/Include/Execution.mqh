//+------------------------------------------------------------------+
//|                                                    Execution.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer-15 surface. Receives a (decision, reason, state) triple, |
//|   gates it through the Capital state machine, asks Risk for the  |
//|   conviction-tier-appropriate lot size, and routes it to the     |
//|   PaperTrade shell. EVERYTHING is logged.                        |
//|                                                                  |
//|   Phase 1: only the gate + log path is wired. Actual              |
//|   ENTRY/EXIT/REVERSE/TRANSFER plumbing belongs to Phase 5         |
//|   (CampaignPositions + PositionHealth). The shape is fixed now    |
//|   so later phases plug in without touching the contract.          |
//+------------------------------------------------------------------+
#ifndef __OMEGA_EXECUTION_MQH__
#define __OMEGA_EXECUTION_MQH__

#include "Common.mqh"
#include "Logger.mqh"
#include "Memory.mqh"
#include "Capital.mqh"
#include "Risk.mqh"
#include "PaperTrade.mqh"
#include "CampaignDB.mqh"

//=== Position roles within a campaign (Layer 5: granularity) =======
enum ENUM_OMEGA_POSITION_ROLE
  {
   POS_ROLE_ORIGIN     = 0,
   POS_ROLE_ENTRY      = 1,
   POS_ROLE_PROGRESS   = 2,
   POS_ROLE_TERMINAL   = 3
  };

class OmegaExecution
  {
private:
   OmegaPaperTrade  m_trade;
   OmegaCapital    *m_capital;
   OmegaRisk       *m_risk;
   CampaignDB      *m_db;

public:
                     OmegaExecution()
     {
      m_capital = NULL;
      m_risk    = NULL;
      m_db      = NULL;
     }

   void Init(ENUM_OMEGA_MODE mode, ulong magic,
             OmegaCapital *capital, OmegaRisk *risk, CampaignDB *db)
     {
      m_trade.Init(mode, magic);
      m_capital = capital;
      m_risk    = risk;
      m_db      = db;
      OmegaLogger::LogInfo("EXEC", "Initialized");
     }

   void SetMode(ENUM_OMEGA_MODE mode) { m_trade.SetMode(mode); }
   ENUM_OMEGA_MODE Mode() const       { return m_trade.Mode(); }

   //--- The single entry point for every decision.
   //    OBSERVE / HOLD log only. Everything else is gated by capital
   //    state, risk-tiered, and routed through the paper shell.
   void HandleDecision(string symbol, ENUM_OMEGA_DECISION dec, ENUM_OMEGA_REASON reason,
                        const OmegaState &state, double stopDistPts, string detail)
     {
      OmegaLogger::LogDecision(symbol, m_trade.Mode(), dec, reason,
                                state.life, state.stability, state.confidence, detail);
      if(dec == OMEGA_DEC_OBSERVE || dec == OMEGA_DEC_HOLD)
         return;

      //--- Capital gate
      if(m_capital == NULL)
        {
         OmegaLogger::LogException("EXEC", -1, "Capital not wired");
         return;
        }
      ENUM_OMEGA_CAPITAL_STATE cs = m_capital.State();
      if(cs == CAPITAL_SUSPENDED)
        {
         OmegaLogger::LogDecision(symbol, m_trade.Mode(), OMEGA_DEC_OBSERVE,
                                   REASON_HARD_LIMIT,
                                   state.life, state.stability, state.confidence,
                                   "Capital SUSPENDED — decision suppressed");
         return;
        }
      if(cs == CAPITAL_RESTRICTED &&
         (dec == OMEGA_DEC_ENTER_LONG || dec == OMEGA_DEC_ENTER_SHORT || dec == OMEGA_DEC_ADD))
        {
         OmegaLogger::LogDecision(symbol, m_trade.Mode(), OMEGA_DEC_OBSERVE,
                                   REASON_DAILY_LIMIT,
                                   state.life, state.stability, state.confidence,
                                   "Capital RESTRICTED — entry suppressed (managing only)");
         return;
        }

      //--- Risk gate
      if(m_risk == NULL)
        {
         OmegaLogger::LogException("EXEC", -2, "Risk not wired");
         return;
        }
      double riskPct = m_risk.RiskPctFor(state);
      double lots    = m_risk.LotsFor(symbol, riskPct, stopDistPts, m_capital);
      if(lots <= 0)
        {
         OmegaLogger::LogWarning("EXEC",
            StringFormat("%s · zero lots · risk=%.2f%% sd=%.0f", symbol, riskPct, stopDistPts));
         return;
        }

      //--- Phase 1 stub: SL/TP are owned by PositionHealth (Phase 5).
      //    Until then we route entries with sl=0, tp=0 (broker will
      //    accept; PositionHealth will set them post-fill).
      double sl = 0.0, tp = 0.0;

      switch(dec)
        {
         case OMEGA_DEC_ENTER_LONG:
         case OMEGA_DEC_ADD:
            m_trade.Buy(symbol, lots, sl, tp, reason,
                        StringFormat("risk=%.2f%% sd=%.0f %s", riskPct, stopDistPts, detail));
            break;
         case OMEGA_DEC_ENTER_SHORT:
            m_trade.Sell(symbol, lots, sl, tp, reason,
                         StringFormat("risk=%.2f%% sd=%.0f %s", riskPct, stopDistPts, detail));
            break;
         case OMEGA_DEC_REVERSE:
         case OMEGA_DEC_TRANSFER:
         case OMEGA_DEC_REDUCE:
         case OMEGA_DEC_EXIT:
            OmegaLogger::LogInfo("EXEC",
               StringFormat("%s · %s · deferred to Phase 5 (CampaignPositions/PositionHealth)",
                            symbol, OmegaStr::DecisionToString(dec)));
            break;
         default:
            break;
        }
     }
  };

#endif // __OMEGA_EXECUTION_MQH__
