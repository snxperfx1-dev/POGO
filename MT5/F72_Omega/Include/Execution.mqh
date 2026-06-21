//+------------------------------------------------------------------+
//|                                                    Execution.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer-15 surface. Receives a (decision, reason, state) triple, |
//|   gates it through Capital state, and routes it to the           |
//|   CampaignPositions manager for actual order plumbing.           |
//|                                                                  |
//|   Phase 5 wires real entries:                                    |
//|     ENTER_LONG / ENTER_SHORT / ADD  → CampaignPositions::Open    |
//|     EXIT                            → CampaignPositions::CloseAll|
//|     REVERSE                         → CloseAll(same)+Open(opp)   |
//|     REDUCE                          → ReduceOldest                |
//|     OBSERVE / HOLD                  → log only                   |
//|                                                                  |
//|   The Capital state machine still gates entries (RESTRICTED      |
//|   suppresses new entries; SUSPENDED suppresses everything).      |
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
#include "Position/PositionHealth.mqh"
#include "Position/CampaignPositions.mqh"

class OmegaExecution
  {
private:
   OmegaPaperTrade     m_trade;
   OmegaCapital       *m_capital;
   OmegaRisk          *m_risk;
   CampaignDB         *m_db;
   CampaignPositions  *m_positions;

public:
                     OmegaExecution()
     {
      m_capital   = NULL;
      m_risk      = NULL;
      m_db        = NULL;
      m_positions = NULL;
     }

   void Init(ENUM_OMEGA_MODE mode, ulong magic,
             OmegaCapital *capital, OmegaRisk *risk, CampaignDB *db,
             CampaignPositions *positions = NULL)
     {
      m_trade.Init(mode, magic);
      m_capital   = capital;
      m_risk      = risk;
      m_db        = db;
      m_positions = positions;
      OmegaLogger::LogInfo("EXEC", "Initialized");
     }

   //--- Late-bind the position manager (avoids constructor circular dep)
   void SetPositions(CampaignPositions *positions) { m_positions = positions; }

   //--- expose the trade shell so CampaignPositions can share it
   OmegaPaperTrade* TradeShell() { return GetPointer(m_trade); }
   void SetMode(ENUM_OMEGA_MODE mode) { m_trade.SetMode(mode); }
   ENUM_OMEGA_MODE Mode() const       { return m_trade.Mode(); }

   //--- The single decision-handling entry point. Logs every decision,
   //    gates by capital state, then routes to CampaignPositions.
   void HandleDecision(string symbol, ENUM_OMEGA_DECISION dec, ENUM_OMEGA_REASON reason,
                        const OmegaState &state, double stopDistPts, string detail,
                        ENUM_POSITION_ROLE role = POS_ENTRY,
                        int suggestedDir = 0,
                        long campaignId = 0)
     {
      OmegaLogger::LogDecision(symbol, m_trade.Mode(), dec, reason,
                                state.life, state.stability, state.confidence, detail);
      if(dec == OMEGA_DEC_OBSERVE || dec == OMEGA_DEC_HOLD) return;

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
      bool isEntryDec = (dec == OMEGA_DEC_ENTER_LONG ||
                         dec == OMEGA_DEC_ENTER_SHORT ||
                         dec == OMEGA_DEC_ADD ||
                         dec == OMEGA_DEC_REVERSE);
      if(cs == CAPITAL_RESTRICTED && isEntryDec)
        {
         OmegaLogger::LogDecision(symbol, m_trade.Mode(), OMEGA_DEC_OBSERVE,
                                   REASON_DAILY_LIMIT,
                                   state.life, state.stability, state.confidence,
                                   "Capital RESTRICTED — entry suppressed (managing only)");
         return;
        }

      if(m_positions == NULL)
        {
         OmegaLogger::LogException("EXEC", -2, "Positions not wired");
         return;
        }
      if(stopDistPts <= 0 && isEntryDec)
        {
         OmegaLogger::LogWarning("EXEC",
            StringFormat("%s · %s · invalid stopDistPts %.0f — skipped",
                          symbol, OmegaStr::DecisionToString(dec), stopDistPts));
         return;
        }

      switch(dec)
        {
         case OMEGA_DEC_ENTER_LONG:
            m_positions.Open(+1, role, stopDistPts, campaignId, reason, detail, state);
            break;
         case OMEGA_DEC_ENTER_SHORT:
            m_positions.Open(-1, role, stopDistPts, campaignId, reason, detail, state);
            break;
         case OMEGA_DEC_ADD:
            if(suggestedDir == 0) suggestedDir = +1;
            m_positions.Open(suggestedDir, role, stopDistPts, campaignId, reason, detail, state);
            break;
         case OMEGA_DEC_REVERSE:
           {
            int oldDir = -suggestedDir;     // counter side currently held
            m_positions.CloseAll(oldDir, REASON_OWNERSHIP_TRANSFER,
                                  "REVERSE: closing prior side before flip");
            m_positions.Open(suggestedDir, POS_ORIGIN, stopDistPts, campaignId,
                              reason, "REVERSE: flipped to counter", state);
            break;
           }
         case OMEGA_DEC_EXIT:
            m_positions.CloseAll(suggestedDir, reason, detail);
            break;
         case OMEGA_DEC_REDUCE:
            if(suggestedDir == 0) suggestedDir = +1;
            m_positions.ReduceOldest(suggestedDir, reason, detail);
            break;
         case OMEGA_DEC_TRANSFER:
            //-- TRANSFER mirrors REVERSE today; Phase 6 will distinguish
            //   gradual hand-offs (transfer) from hard flips (reverse).
           {
            int oldDirT = -suggestedDir;
            m_positions.CloseAll(oldDirT, REASON_OWNERSHIP_TRANSFER, detail);
            m_positions.Open(suggestedDir, POS_ORIGIN, stopDistPts, campaignId,
                              reason, detail, state);
            break;
           }
         default:
            break;
        }
     }
  };

#endif // __OMEGA_EXECUTION_MQH__
