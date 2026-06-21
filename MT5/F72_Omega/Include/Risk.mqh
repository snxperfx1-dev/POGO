//+------------------------------------------------------------------+
//|                                                         Risk.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Risk does NOT sit outside the narrative. It reads the trinity  |
//|   directly and emits a per-trade % risk plus the equivalent      |
//|   broker-normalized lot size. Phase 5.1 wraps that core with     |
//|   equity-tier guards so the same engine works identically on     |
//|   $30 cent accounts and $1M institutional accounts — same        |
//|   intelligence, different operating envelope.                    |
//|                                                                  |
//|   Tiers (defaults, overridable from EA inputs):                  |
//|     base         0.25%   — engine perceives but is uncertain     |
//|     normal       0.50%   — coherent narrative                    |
//|     strong       1.00%   — strong narrative                      |
//|     exceptional  2.00%   — exceptional alignment                 |
//|                                                                  |
//|   Phase 5.1 guards:                                              |
//|     - equity-tier classification (MICRO/SMALL/STANDARD/LARGE/    |
//|       INSTITUTIONAL) → tier-aware conviction floors              |
//|     - stop-distance ATR floor (kills the tight-stop runaway)     |
//|     - per-ticket notional cap (% of equity)                      |
//|     - pre-trade margin precheck                                  |
//|                                                                  |
//|   Hard ceiling 2% per trade — never exceeded regardless of state.|
//+------------------------------------------------------------------+
#ifndef __OMEGA_RISK_MQH__
#define __OMEGA_RISK_MQH__

#include "Common.mqh"
#include "Memory.mqh"
#include "Capital.mqh"
#include "Logger.mqh"

//=== Phase 5.1 — Equity tier classification ========================
//   Same engine, same intelligence, different operating envelope per
//   account size. MICRO mode is opt-in (forced over-risk acknowledged).
enum ENUM_OMEGA_TIER
  {
   TIER_MICRO         = 0,   // <$200 — broker min dominates, A+ only
   TIER_SMALL         = 1,   // $200..$1K — ALIVE-tier only, light pyramid
   TIER_STANDARD      = 2,   // $1K..$50K — production
   TIER_LARGE         = 3,   // $50K..$500K — production + notional caps
   TIER_INSTITUTIONAL = 4    // >$500K — bounded by aggregate leverage
  };

class OmegaRisk
  {
private:
   double m_base;
   double m_normal;
   double m_strong;
   double m_exceptional;
   double m_hardCeiling;

   // Phase 5.1 — guard parameters
   double m_minStopAtrMult;
   int    m_minStopAtrPeriod;
   double m_maxNotionalPct;
   double m_microThreshold;
   double m_smallThreshold;
   double m_largeThreshold;
   double m_instThreshold;
   bool   m_allowMicro;
   double m_marginUseMaxPct;

public:
                     OmegaRisk()
     {
      m_base        = 0.25;
      m_normal      = 0.50;
      m_strong      = 1.00;
      m_exceptional = 2.00;
      m_hardCeiling = 2.00;
      m_minStopAtrMult    = 0.75;
      m_minStopAtrPeriod  = 14;
      m_maxNotionalPct    = 1000.0;
      m_microThreshold    = 200.0;
      m_smallThreshold    = 1000.0;
      m_largeThreshold    = 50000.0;
      m_instThreshold     = 500000.0;
      m_allowMicro        = false;
      m_marginUseMaxPct   = 80.0;
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

   void InitGuards(double minStopAtrMult, int minStopAtrPeriod,
                   double maxNotionalPct, double microThr, double smallThr,
                   double largeThr, double instThr, bool allowMicro,
                   double marginUseMaxPct)
     {
      m_minStopAtrMult    = minStopAtrMult;
      m_minStopAtrPeriod  = minStopAtrPeriod;
      m_maxNotionalPct    = maxNotionalPct;
      m_microThreshold    = microThr;
      m_smallThreshold    = smallThr;
      m_largeThreshold    = largeThr;
      m_instThreshold     = instThr;
      m_allowMicro        = allowMicro;
      m_marginUseMaxPct   = marginUseMaxPct;
      OmegaLogger::LogInfo("RISK",
         StringFormat("Guards · stopFloor=%.2f×ATR(%d) · notionalCap=%.0f%% equity · tiers MICRO<%.0f SMALL<%.0f LARGE<%.0f INST≥%.0f · allowMicro=%s · marginUseMax=%.0f%%",
                      minStopAtrMult, minStopAtrPeriod, maxNotionalPct,
                      microThr, smallThr, largeThr, instThr,
                      allowMicro ? "YES" : "NO", marginUseMaxPct));
     }

   ENUM_OMEGA_TIER TierFor(double equity) const
     {
      if(equity < m_microThreshold)  return TIER_MICRO;
      if(equity < m_smallThreshold)  return TIER_SMALL;
      if(equity < m_largeThreshold)  return TIER_STANDARD;
      if(equity < m_instThreshold)   return TIER_LARGE;
      return TIER_INSTITUTIONAL;
     }

   string TierStr(ENUM_OMEGA_TIER t) const
     {
      switch(t)
        {
         case TIER_MICRO:         return "MICRO";
         case TIER_SMALL:         return "SMALL";
         case TIER_STANDARD:      return "STANDARD";
         case TIER_LARGE:         return "LARGE";
         case TIER_INSTITUTIONAL: return "INSTITUTIONAL";
        }
      return "?";
     }

   double RiskPctFor(const OmegaState &s, ENUM_OMEGA_TIER tier) const
     {
      if(!s.primed) return m_base;
      bool aPlus  = (s.life >= 75 && s.stability >= 75 && s.confidence >= 70);
      bool strong = (s.life >= 60 && s.stability >= 60 && s.confidence >= 55);
      bool normal = (s.life >= 45 && s.stability >= 45 && s.confidence >= 40);
      if(tier == TIER_MICRO)
        {
         if(!m_allowMicro)   return 0.0;
         return aPlus ? m_exceptional : 0.0;
        }
      if(tier == TIER_SMALL)
        {
         if(aPlus)           return m_exceptional;
         if(strong)          return m_strong;
         return 0.0;
        }
      if(aPlus)              return m_exceptional;
      if(strong)             return m_strong;
      if(normal)             return m_normal;
      return m_base;
     }

   double RiskPctFor(const OmegaState &s) const
     {
      return RiskPctFor(s, TIER_STANDARD);
     }

   double ResolveStopPoints(string symbol, double rawStopDistPoints) const
     {
      if(m_minStopAtrMult <= 0.0 || m_minStopAtrPeriod <= 0) return rawStopDistPoints;
      int handle = iATR(symbol, _Period, m_minStopAtrPeriod);
      if(handle == INVALID_HANDLE) return rawStopDistPoints;
      double buf[];
      ArraySetAsSeries(buf, true);
      int copied = CopyBuffer(handle, 0, 0, 1, buf);
      IndicatorRelease(handle);
      if(copied <= 0 || buf[0] <= 0) return rawStopDistPoints;
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0) return rawStopDistPoints;
      double atrPts   = buf[0] / point;
      double floorPts = atrPts * m_minStopAtrMult;
      return MathMax(rawStopDistPoints, floorPts);
     }

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

      if(m_maxNotionalPct > 0.0)
        {
         double contract = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
         double askPx    = SymbolInfoDouble(symbol, SYMBOL_ASK);
         if(askPx <= 0) askPx = SymbolInfoDouble(symbol, SYMBOL_BID);
         if(contract > 0 && askPx > 0)
           {
            double notionalCap = (equity * m_maxNotionalPct / 100.0) / (askPx * contract);
            if(notionalCap > 0 && lots > notionalCap)
              {
               OmegaLogger::LogInfo("RISK",
                  StringFormat("%s · notional cap engaged · lots %.2f→%.2f (≤%.0f%% equity)",
                               symbol, lots, notionalCap, m_maxNotionalPct));
               lots = notionalCap;
              }
           }
        }

      double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      if(stepLot <= 0) stepLot = 0.01;
      lots = MathFloor(lots / stepLot) * stepLot;
      lots = OmegaMath::Clamp(lots, minLot, maxLot);
      return lots;
     }

   bool PassesMarginCheck(string symbol, int direction, double lots, double openPx) const
     {
      if(lots <= 0 || m_marginUseMaxPct <= 0.0) return true;
      double margin = 0.0;
      ENUM_ORDER_TYPE ot = (direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(!OrderCalcMargin(ot, symbol, lots, openPx, margin)) return true;
      double freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
      if(freeMargin <= 0) return false;
      bool ok = (margin <= freeMargin * (m_marginUseMaxPct / 100.0));
      if(!ok)
         OmegaLogger::LogWarning("RISK",
            StringFormat("%s · margin precheck FAIL · req=%.2f freeMargin=%.2f cap=%.0f%%",
                          symbol, margin, freeMargin, m_marginUseMaxPct));
      return ok;
     }

   double Base()        const { return m_base; }
   double Normal()      const { return m_normal; }
   double Strong()      const { return m_strong; }
   double Exceptional() const { return m_exceptional; }
   double HardCeiling() const { return m_hardCeiling; }
   bool   AllowMicro()  const { return m_allowMicro; }
  };

#endif // __OMEGA_RISK_MQH__
