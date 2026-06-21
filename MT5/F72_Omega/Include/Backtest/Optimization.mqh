//+------------------------------------------------------------------+
//|                                                 Optimization.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Phase 7 · MT5-Strategy-Tester optimisation surface.            |
//|                                                                  |
//|   Provides a single OnTester() function the EA can route to,     |
//|   plus a fitness composite so the optimiser doesn't only chase   |
//|   raw P/L — it weighs:                                           |
//|     +1.0 × profit factor                                         |
//|     +0.5 × Sharpe-like (return / drawdown)                       |
//|     -1.0 × max drawdown %                                        |
//|     +0.3 × hit rate                                              |
//|     -0.5 × decision contradiction rate (overfit penalty)         |
//|                                                                  |
//|   Phase 7 baseline returns the composite as a single double; the |
//|   tester ranks runs by it.                                       |
//+------------------------------------------------------------------+
#ifndef __OMEGA_BACKTEST_OPTIMIZATION_MQH__
#define __OMEGA_BACKTEST_OPTIMIZATION_MQH__

#include "../Common.mqh"
#include "../Logger.mqh"

class Optimization
  {
public:
   //--- Composite fitness for OnTester(). Higher = better.
   //    Inputs are stats the engine already tracks; the EA passes them
   //    in from SelfObservation + Capital + Tester results.
   static double Fitness(double profitFactor,
                          double netProfit,
                          double maxDrawdownPct,
                          double hitRate,
                          double contradictionRate)
     {
      double score = 0.0;
      score += profitFactor * 1.0;
      if(maxDrawdownPct > 0.01)
         score += (netProfit / maxDrawdownPct) * 0.5;
      score -= maxDrawdownPct * 1.0;
      score += hitRate * 30.0;          // 0..1 → 0..30
      score -= contradictionRate * 50.0;
      OmegaLogger::LogInfo("OPT",
         StringFormat("Fitness · pf=%.2f net=%.2f mdd=%.2f hr=%.2f contr=%.2f → %.2f",
                       profitFactor, netProfit, maxDrawdownPct,
                       hitRate, contradictionRate, score));
      return score;
     }

   //--- Convenience wrapper for the EA's OnTester.
   //    Pulls TesterStatistics directly so the EA's OnTester is one line.
   static double OnTesterDefault()
     {
      double profit  = TesterStatistics(STAT_PROFIT);
      double pf      = TesterStatistics(STAT_PROFIT_FACTOR);
      double mddPct  = TesterStatistics(STAT_BALANCE_DDREL_PERCENT);
      long   trades  = (long)TesterStatistics(STAT_TRADES);
      long   wins    = (long)TesterStatistics(STAT_PROFIT_TRADES);
      double hitRate = (trades > 0) ? (double)wins / trades : 0.0;
      //-- contradictionRate not available from tester; default 0 in offline runs
      return Fitness(pf, profit, mddPct, hitRate, 0.0);
     }
  };

#endif // __OMEGA_BACKTEST_OPTIMIZATION_MQH__
