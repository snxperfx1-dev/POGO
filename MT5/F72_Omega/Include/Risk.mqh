//+------------------------------------------------------------------+
//|                                                         Risk.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Risk does NOT sit outside the narrative. It reads the trinity  |
//|   directly and emits a per-trade % risk plus the equivalent      |
//|   broker-normalized lot size. The only inputs that matter are    |
//|     - life       (is the story alive?)                           |
//|     - stability  (how stable?)                                   |
//|     - confidence (how much do I trust myself?)                   |
//|     - capital throttle (drawdown breath)                         |
//|                                                                  |
//|   Tiers (defaults, overridable from EA inputs):                  |
//|     base         0.25%   — engine perceives but is uncertain     |
//|     normal       0.50%   — coherent narrative                    |
//|     strong       1.00%   — strong narrative                      |
//|     exceptional  2.00%   — exceptional alignment                 |
//|                                                                  |
//|   Hard ceiling 2% per trade — never exceeded regardless of state.|
//+------------------------------------------------------------------+
#ifndef __OMEGA_RISK_MQH__
#define __OMEGA_RISK_MQH__

#include "Common.mqh"
#include "Memory.mqh"
#include "Capital.mqh"
#include "Logger.mqh"

class OmegaRisk
  {
private:
   double m_base;
   double m_normal;
   double m_strong;
   double m_exceptional;
   double m_hardCeiling;

public:
                     OmegaRisk()
     {
      m_base        = 0.25;
      m_normal      = 0.50;
      m_strong      = 1.00;
      m_exceptional = 2.00;
      m_hardCeiling = 2.00;
     }

   void Init(double basePct, double normalPct, double strongPct, double excepPct, double ceilingPct = 2.0)
     {
      m_base        = basePct;
      m_normal      = normalPct;
      m_strong      = strongPct;
      m_exceptional = excepPct;
      m_hardCeiling = ceilingPct;
      OmegaLogger::LogInfo("RISK",
         StringFormat("Initialized · base=%.2f%% normal=%.2f%% strong=%.2f%% excep=%.2f%% ceiling=%.2f%%",
                      basePct, normalPct, strongPct, excepPct, ceilingPct));
     }

   //--- Conviction tier from the trinity. Conservative by design;
   //    Phase 6 SelfObservation tunes these against campaign memory.
   double RiskPctFor(const OmegaState &s) const
     {
      if(!s.primed)
         return m_base;
      if(s.life >= 75 && s.stability >= 75 && s.confidence >= 70)
         return m_exceptional;
      if(s.life >= 60 && s.stability >= 60 && s.confidence >= 55)
         return m_strong;
      if(s.life >= 45 && s.stability >= 45 && s.confidence >= 40)
         return m_normal;
      return m_base;
     }

   //--- Convert risk% + stop distance to broker-normalized lots.
   //    Returns 0 lots if any input is invalid (which suppresses entry).
   double LotsFor(string symbol, double riskPct, double stopDistPoints, const OmegaCapital &cap) const
     {
      riskPct = OmegaMath::Clamp(riskPct, 0.0, m_hardCeiling);
      double throttle = cap.Throttle();
      double effectivePct = riskPct * throttle;
      if(effectivePct <= 0.0) return 0.0;

      double equity = cap.Equity();
      double riskMoney = equity * effectivePct / 100.0;

      double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(tickSize <= 0 || tickValue <= 0 || point <= 0 || stopDistPoints <= 0) return 0.0;

      double lossPerLot = (stopDistPoints * point / tickSize) * tickValue;
      if(lossPerLot <= 0) return 0.0;

      double lots = riskMoney / lossPerLot;

      double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      if(stepLot <= 0) stepLot = 0.01;
      lots = MathFloor(lots / stepLot) * stepLot;
      lots = OmegaMath::Clamp(lots, minLot, maxLot);
      return lots;
     }

   //--- accessors
   double Base()        const { return m_base; }
   double Normal()      const { return m_normal; }
   double Strong()      const { return m_strong; }
   double Exceptional() const { return m_exceptional; }
   double HardCeiling() const { return m_hardCeiling; }
  };

#endif // __OMEGA_RISK_MQH__
