//+------------------------------------------------------------------+
//|                                                  PaperTrade.mqh  |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Order shell. Wraps CTrade. In OBSERVER / COPILOT / PAPER /     |
//|   SHADOW modes intercepts every order call, logs it via the      |
//|   structured execution log, and returns success WITHOUT sending. |
//|   Only AUTONOMOUS mode passes through to the real CTrade.        |
//|                                                                  |
//|   This is the explainability barrier between the engine and the |
//|   broker — every Phase from 5 onward executes through here, so  |
//|   shadow / paper / live paths all share identical accounting.   |
//+------------------------------------------------------------------+
#ifndef __OMEGA_PAPER_MQH__
#define __OMEGA_PAPER_MQH__

#include <Trade/Trade.mqh>
#include "Common.mqh"
#include "Logger.mqh"

class OmegaPaperTrade
  {
private:
   CTrade            m_trade;
   ENUM_OMEGA_MODE   m_mode;
   ulong             m_paperTicket;       // monotonic faux ticket for paper trades

   bool LiveMode() const { return (m_mode == OMEGA_MODE_AUTONOMOUS); }

public:
                     OmegaPaperTrade()
     {
      m_mode        = OMEGA_MODE_AUTONOMOUS;
      m_paperTicket = 1000000;
     }

   void Init(ENUM_OMEGA_MODE mode, ulong magic, int slippagePts = 20)
     {
      m_mode = mode;
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints((ulong)slippagePts);
      m_trade.SetTypeFillingBySymbol(_Symbol);
      m_trade.SetMarginMode();
      OmegaLogger::LogInfo("PAPER",
         StringFormat("Init · mode=%s · magic=%I64u · slippagePts=%d",
                      OmegaStr::ModeToString(mode), magic, slippagePts));
     }

   void SetMode(ENUM_OMEGA_MODE mode)
     {
      if(mode != m_mode)
        {
         OmegaLogger::LogWarning("PAPER",
            StringFormat("Mode changed %s -> %s",
                         OmegaStr::ModeToString(m_mode),
                         OmegaStr::ModeToString(mode)));
         m_mode = mode;
        }
     }
   ENUM_OMEGA_MODE Mode() const { return m_mode; }

   //--- BUY → returns broker ticket (or paper ticket); 0 = failure
   ulong Buy(string symbol, double lots, double sl, double tp, ENUM_OMEGA_REASON reason, string detail)
     {
      double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(LiveMode())
        {
         bool ok = m_trade.Buy(lots, symbol, price, sl, tp, detail);
         ulong tk = m_trade.ResultOrder();
         OmegaLogger::LogExecution(symbol, "BUY", tk,
                                    m_trade.ResultPrice(), lots, reason,
            StringFormat("live=%s ret=%u %s", ok?"true":"false",
                         m_trade.ResultRetcode(), detail));
         return ok ? tk : 0;
        }
      ulong ticket = ++m_paperTicket;
      OmegaLogger::LogExecution(symbol, "BUY-PAPER", ticket, price, lots, reason,
         StringFormat("sl=%.5f tp=%.5f %s", sl, tp, detail));
      return ticket;
     }

   //--- SELL → returns broker ticket (or paper ticket); 0 = failure
   ulong Sell(string symbol, double lots, double sl, double tp, ENUM_OMEGA_REASON reason, string detail)
     {
      double price = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(LiveMode())
        {
         bool ok = m_trade.Sell(lots, symbol, price, sl, tp, detail);
         ulong tk = m_trade.ResultOrder();
         OmegaLogger::LogExecution(symbol, "SELL", tk,
                                    m_trade.ResultPrice(), lots, reason,
            StringFormat("live=%s ret=%u %s", ok?"true":"false",
                         m_trade.ResultRetcode(), detail));
         return ok ? tk : 0;
        }
      ulong ticket = ++m_paperTicket;
      OmegaLogger::LogExecution(symbol, "SELL-PAPER", ticket, price, lots, reason,
         StringFormat("sl=%.5f tp=%.5f %s", sl, tp, detail));
      return ticket;
     }

   //--- CLOSE
   bool Close(ulong ticket, ENUM_OMEGA_REASON reason, string detail)
     {
      if(LiveMode())
        {
         bool ok = m_trade.PositionClose(ticket);
         OmegaLogger::LogExecution("-", "CLOSE", ticket, 0, 0, reason,
            StringFormat("live=%s ret=%u %s", ok?"true":"false",
                         m_trade.ResultRetcode(), detail));
         return ok;
        }
      OmegaLogger::LogExecution("-", "CLOSE-PAPER", ticket, 0, 0, reason, detail);
      return true;
     }

   //--- Modify SL/TP (used by PositionHealth in Phase 5)
   bool ModifySLTP(ulong ticket, double sl, double tp, ENUM_OMEGA_REASON reason, string detail)
     {
      if(LiveMode())
        {
         bool ok = m_trade.PositionModify(ticket, sl, tp);
         OmegaLogger::LogExecution("-", "MODIFY", ticket, 0, 0, reason,
            StringFormat("sl=%.5f tp=%.5f live=%s ret=%u %s",
                         sl, tp, ok?"true":"false", m_trade.ResultRetcode(), detail));
         return ok;
        }
      OmegaLogger::LogExecution("-", "MODIFY-PAPER", ticket, 0, 0, reason,
         StringFormat("sl=%.5f tp=%.5f %s", sl, tp, detail));
      return true;
     }
  };

#endif // __OMEGA_PAPER_MQH__
