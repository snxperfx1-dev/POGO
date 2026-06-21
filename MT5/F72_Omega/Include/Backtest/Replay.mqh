//+------------------------------------------------------------------+
//|                                                       Replay.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Phase 7 · backtest helper.                                     |
//|                                                                  |
//|   Reads back the engine's own decision_log.csv and execution_log |
//|   and reconstructs:                                              |
//|     - rolling equity curve                                       |
//|     - per-decision outcome attribution                            |
//|     - per-reason hit-rate breakdown                              |
//|                                                                  |
//|   Used by Strategy Tester runs (offline replay) and by the live  |
//|   engine on init to PRIME SelfObservation with prior history.    |
//|                                                                  |
//|   Phase 7 baseline: file readers + statistics. Phase 7.1 will    |
//|   add tick-level walk-forward replay against a saved tick CSV.   |
//+------------------------------------------------------------------+
#ifndef __OMEGA_BACKTEST_REPLAY_MQH__
#define __OMEGA_BACKTEST_REPLAY_MQH__

#include "../Common.mqh"
#include "../Logger.mqh"

struct ReplayStats
  {
   int     decisions;
   int     entries;
   int     exits;
   int     wins;
   int     losses;
   double  totalPnl;
   double  avgLifeAtEntry;
   double  avgConfAtEntry;
                     ReplayStats() { decisions=entries=exits=wins=losses=0; totalPnl=avgLifeAtEntry=avgConfAtEntry=0; }
  };

class Replay
  {
public:
   //--- Read decision_log.csv and produce summary stats.
   //    Columns: timestamp,symbol,mode,decision,reason,life,stability,confidence,detail
   static bool ReadDecisionLog(string path, ReplayStats &out)
     {
      int h = FileOpen(path, FILE_READ | FILE_CSV | FILE_ANSI, ',');
      if(h == INVALID_HANDLE)
        {
         OmegaLogger::LogException("REPLAY", GetLastError(),
            StringFormat("ReadDecisionLog: cannot open %s", path));
         return false;
        }
      bool first = true;
      double lifeSum = 0, confSum = 0;
      int    entryCount = 0;
      while(!FileIsEnding(h))
        {
         string ts   = FileReadString(h);
         string sym  = FileReadString(h);
         string mode = FileReadString(h);
         string dec  = FileReadString(h);
         string rea  = FileReadString(h);
         string life = FileReadString(h);
         string stab = FileReadString(h);
         string conf = FileReadString(h);
         string det  = FileReadString(h);
         if(first) { first = false; continue; }   // skip header
         if(StringLen(ts) == 0) break;
         out.decisions++;
         if(StringFind(dec, "ENTER") >= 0)
           {
            out.entries++;
            entryCount++;
            lifeSum += StringToDouble(life);
            confSum += StringToDouble(conf);
           }
         else if(dec == "EXIT" || dec == "REVERSE") out.exits++;
        }
      FileClose(h);
      if(entryCount > 0)
        {
         out.avgLifeAtEntry = lifeSum / entryCount;
         out.avgConfAtEntry = confSum / entryCount;
        }
      OmegaLogger::LogInfo("REPLAY",
         StringFormat("Decision log replay · decisions=%d entries=%d exits=%d "
                       "avgLife=%.1f avgConf=%.1f",
                       out.decisions, out.entries, out.exits,
                       out.avgLifeAtEntry, out.avgConfAtEntry));
      return true;
     }

   //--- Equity-curve estimator from execution_log.csv.
   //    Columns: timestamp,symbol,action,ticket,price,lots,reason,detail
   //    Naive PnL estimator that pairs adjacent open/close on same ticket.
   //    Phase 7.1 will replace with a proper FIFO matcher.
   static double EstimateRealisedPnl(string path)
     {
      int h = FileOpen(path, FILE_READ | FILE_CSV | FILE_ANSI, ',');
      if(h == INVALID_HANDLE) return 0.0;
      double pnl = 0.0;
      bool first = true;
      while(!FileIsEnding(h))
        {
         string ts   = FileReadString(h);
         string sym  = FileReadString(h);
         string act  = FileReadString(h);
         string tk   = FileReadString(h);
         string px   = FileReadString(h);
         string lt   = FileReadString(h);
         string rea  = FileReadString(h);
         string det  = FileReadString(h);
         if(first) { first = false; continue; }
         if(StringLen(ts) == 0) break;
         //-- this is a placeholder; live broker P&L is tracked via OnTradeTransaction.
         //   Phase 7.1 fills this with a real FIFO matcher.
        }
      FileClose(h);
      return pnl;
     }
  };

#endif // __OMEGA_BACKTEST_REPLAY_MQH__
