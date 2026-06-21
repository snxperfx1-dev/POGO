//+------------------------------------------------------------------+
//|                                                         Risk.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Risk does NOT sit outside the narrative. It reads the trinity  |
//|   directly and emits a per-trade % risk plus the equivalent      |
//|   broker-normalized lot size. Phase 5.1 + 5.1.1 wrap that core   |
//|   with equity-tier guards + a per-tier behavior matrix so the    |
//|   same engine works identically on $30 cent accounts and $1M     |
//|   institutional accounts — same intelligence, different envelope.|
//|                                                                  |
//|   Phase 5.1.1 per-tier matrix (defaults; all overridable from    |
//|   EA inputs):                                                    |
//|     ┌──────────────┬────────┬────────┬─────────┬────────┬───────┐|
//|     │ Tier         │ MICRO  │ SMALL  │ STD     │ LARGE  │ INST  │|
//|     ├──────────────┼────────┼────────┼─────────┼────────┼───────┤|
//|     │ Equity range │ <$200  │<$1K    │<$50K    │<$500K  │≥$500K │|
//|     │ Risk ceiling │ 8.00%  │ 3.00%  │  1.00%  │ 1.00%  │ 0.75% │|
//|     │ Min life     │ 75     │ 60     │  45     │ 45     │ 45    │|
//|     │ Min stab     │ 65     │ 55     │  45     │ 45     │ 45    │|
//|     │ Min conf     │ 60     │ 50     │  40     │ 40     │ 40    │|
//|     │ Pyramid      │ 1      │ 2      │  3      │ 4      │ 4     │|
//|     │ Stop ATR×    │ 1.25   │ 0.85   │  0.75   │ 0.75   │ 0.75  │|
//|     └──────────────┴────────┴────────┴─────────┴────────┴───────┘|
//|                                                                  |
//|   Cent accounts (`m_centAccount`): displayed equity divided by   |
//|   100 internally for tier classification + notional cap math.    |
//|   So a "$3,000" cent account trades like a $30 USD account and   |
//|   correctly classifies as MICRO.                                 |
//|                                                                  |
//|   Undersized behavior: when broker volume_min forces actual risk |
//|   above the tier ceiling, the engine asks `ResolveUndersized()`  |
//|   per the InpUndersizedBehavior policy:                          |
//|     - AUTO     : SKIP for STD+, PROCEED for MICRO/SMALL          |
//|     - SKIP     : never proceed when actual > intended            |
//|     - PROCEED  : always proceed at broker min, log oversized     |
//|     - STRICT   : skip even when actual == intended (paranoid)    |
//+------------------------------------------------------------------+
#ifndef __OMEGA_RISK_MQH__
#define __OMEGA_RISK_MQH__

#include "Common.mqh"
#include "Memory.mqh"
#include "Capital.mqh"
#include "Logger.mqh"

//=== Phase 5.1 — Equity tier classification ========================
enum ENUM_OMEGA_TIER
  {
   TIER_MICRO         = 0,
   TIER_SMALL         = 1,
   TIER_STANDARD      = 2,
   TIER_LARGE         = 3,
   TIER_INSTITUTIONAL = 4
  };

//=== Phase 5.1.1 — Undersized-trade behavior =======================
enum ENUM_OMEGA_UNDERSIZED
  {
   UNDERSIZED_AUTO     = 0,
   UNDERSIZED_SKIP     = 1,
   UNDERSIZED_PROCEED  = 2,
   UNDERSIZED_STRICT   = 3
  };

class OmegaRisk
  {
private:
   double m_base;
   double m_normal;
   double m_strong;
   double m_exceptional;
   double m_hardCeiling;

   double m_minStopAtrMult;
   int    m_minStopAtrPeriod;
   double m_maxNotionalPct;
   double m_microThreshold;
   double m_smallThreshold;
   double m_largeThreshold;
   double m_instThreshold;
   bool   m_allowMicro;
   double m_marginUseMaxPct;

   double m_tierMaxRiskPct[5];
   double m_tierMinLife[5];
   double m_tierMinStab[5];
   double m_tierMinConf[5];
   int    m_tierMaxBudget[5];
   double m_tierStopAtrMult[5];

   bool   m_centAccount;
   int    m_undersizedBehavior;

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
      m_tierMaxRiskPct[TIER_MICRO]=8.00; m_tierMaxRiskPct[TIER_SMALL]=3.00;
      m_tierMaxRiskPct[TIER_STANDARD]=1.00; m_tierMaxRiskPct[TIER_LARGE]=1.00;
      m_tierMaxRiskPct[TIER_INSTITUTIONAL]=0.75;
      m_tierMinLife[TIER_MICRO]=75; m_tierMinLife[TIER_SMALL]=60;
      m_tierMinLife[TIER_STANDARD]=45; m_tierMinLife[TIER_LARGE]=45; m_tierMinLife[TIER_INSTITUTIONAL]=45;
      m_tierMinStab[TIER_MICRO]=65; m_tierMinStab[TIER_SMALL]=55;
      m_tierMinStab[TIER_STANDARD]=45; m_tierMinStab[TIER_LARGE]=45; m_tierMinStab[TIER_INSTITUTIONAL]=45;
      m_tierMinConf[TIER_MICRO]=60; m_tierMinConf[TIER_SMALL]=50;
      m_tierMinConf[TIER_STANDARD]=40; m_tierMinConf[TIER_LARGE]=40; m_tierMinConf[TIER_INSTITUTIONAL]=40;
      m_tierMaxBudget[TIER_MICRO]=1; m_tierMaxBudget[TIER_SMALL]=2;
      m_tierMaxBudget[TIER_STANDARD]=3; m_tierMaxBudget[TIER_LARGE]=4; m_tierMaxBudget[TIER_INSTITUTIONAL]=4;
      m_tierStopAtrMult[TIER_MICRO]=1.25; m_tierStopAtrMult[TIER_SMALL]=0.85;
      m_tierStopAtrMult[TIER_STANDARD]=0.75; m_tierStopAtrMult[TIER_LARGE]=0.75; m_tierStopAtrMult[TIER_INSTITUTIONAL]=0.75;
      m_centAccount         = false;
      m_undersizedBehavior  = UNDERSIZED_AUTO;
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
     }

   void InitTiers(double microMaxR, double smallMaxR, double stdMaxR, double largeMaxR, double instMaxR,
                  double microL, double microS, double microC,
                  double smallL, double smallS, double smallC,
                  int microBudget, int smallBudget, int stdBudget, int largeBudget, int instBudget,
                  double microStopAtr, double smallStopAtr, double stdStopAtr, double largeStopAtr, double instStopAtr,
                  bool centAccount, int undersizedBehavior)
     {
      m_tierMaxRiskPct[TIER_MICRO]=microMaxR; m_tierMaxRiskPct[TIER_SMALL]=smallMaxR;
      m_tierMaxRiskPct[TIER_STANDARD]=stdMaxR; m_tierMaxRiskPct[TIER_LARGE]=largeMaxR;
      m_tierMaxRiskPct[TIER_INSTITUTIONAL]=instMaxR;
      m_tierMinLife[TIER_MICRO]=microL; m_tierMinStab[TIER_MICRO]=microS; m_tierMinConf[TIER_MICRO]=microC;
      m_tierMinLife[TIER_SMALL]=smallL; m_tierMinStab[TIER_SMALL]=smallS; m_tierMinConf[TIER_SMALL]=smallC;
      m_tierMaxBudget[TIER_MICRO]=microBudget; m_tierMaxBudget[TIER_SMALL]=smallBudget;
      m_tierMaxBudget[TIER_STANDARD]=stdBudget; m_tierMaxBudget[TIER_LARGE]=largeBudget;
      m_tierMaxBudget[TIER_INSTITUTIONAL]=instBudget;
      m_tierStopAtrMult[TIER_MICRO]=microStopAtr; m_tierStopAtrMult[TIER_SMALL]=smallStopAtr;
      m_tierStopAtrMult[TIER_STANDARD]=stdStopAtr; m_tierStopAtrMult[TIER_LARGE]=largeStopAtr;
      m_tierStopAtrMult[TIER_INSTITUTIONAL]=instStopAtr;
      m_centAccount        = centAccount;
      m_undersizedBehavior = undersizedBehavior;
     }

   double EffectiveEquity(const OmegaCapital &cap) const
     {
      double raw = cap.Equity();
      return m_centAccount ? (raw / 100.0) : raw;
     }

   ENUM_OMEGA_TIER TierFor(double equity) const
     {
      if(equity < m_microThreshold)  return TIER_MICRO;
      if(equity < m_smallThreshold)  return TIER_SMALL;
      if(equity < m_largeThreshold)  return TIER_STANDARD;
      if(equity < m_instThreshold)   return TIER_LARGE;
      return TIER_INSTITUTIONAL;
     }

   ENUM_OMEGA_TIER TierForCap(const OmegaCapital &cap) const
     {
      return TierFor(EffectiveEquity(cap));
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

   string UndersizedStr(int m) const
     {
      switch(m)
        {
         case UNDERSIZED_AUTO:    return "AUTO";
         case UNDERSIZED_SKIP:    return "SKIP";
         case UNDERSIZED_PROCEED: return "PROCEED";
         case UNDERSIZED_STRICT:  return "STRICT";
        }
      return "?";
     }

   double TierMaxRiskPct(ENUM_OMEGA_TIER t) const { return m_tierMaxRiskPct[(int)t]; }
   double TierMinLife(ENUM_OMEGA_TIER t)    const { return m_tierMinLife[(int)t]; }
   double TierMinStab(ENUM_OMEGA_TIER t)    const { return m_tierMinStab[(int)t]; }
   double TierMinConf(ENUM_OMEGA_TIER t)    const { return m_tierMinConf[(int)t]; }
   int    TierMaxBudget(ENUM_OMEGA_TIER t)  const { return m_tierMaxBudget[(int)t]; }
   double TierStopAtrMult(ENUM_OMEGA_TIER t) const { return m_tierStopAtrMult[(int)t]; }

   double RiskPctFor(const OmegaState &s, ENUM_OMEGA_TIER tier) const
     {
      double cap = MathMin(TierMaxRiskPct(tier), m_hardCeiling);
      if(!s.primed) return MathMin(m_base, cap);
      if(tier == TIER_MICRO && !m_allowMicro) return 0.0;
      if(s.life       < TierMinLife(tier)) return 0.0;
      if(s.stability  < TierMinStab(tier)) return 0.0;
      if(s.confidence < TierMinConf(tier)) return 0.0;
      double pct = m_base;
      bool aPlus  = (s.life >= 75 && s.stability >= 75 && s.confidence >= 70);
      bool strong = (s.life >= 60 && s.stability >= 60 && s.confidence >= 55);
      bool normal = (s.life >= 45 && s.stability >= 45 && s.confidence >= 40);
      if(aPlus)        pct = m_exceptional;
      else if(strong)  pct = m_strong;
      else if(normal)  pct = m_normal;
      return MathMin(pct, cap);
     }

   double RiskPctFor(const OmegaState &s) const { return RiskPctFor(s, TIER_STANDARD); }

   double ResolveStopPoints(string symbol, double rawStopDistPoints, ENUM_OMEGA_TIER tier) const
     {
      double mult = TierStopAtrMult(tier);
      if(mult <= 0.0 || m_minStopAtrPeriod <= 0) return rawStopDistPoints;
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
      double floorPts = atrPts * mult;
      return MathMax(rawStopDistPoints, floorPts);
     }

   double ResolveStopPoints(string symbol, double rawStopDistPoints) const
     {
      return ResolveStopPoints(symbol, rawStopDistPoints, TIER_STANDARD);
     }

   double CalcActualRiskPct(string symbol, double lots, double stopDistPoints, double equity) const
     {
      if(lots <= 0 || stopDistPoints <= 0 || equity <= 0) return 0.0;
      double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(tickSize <= 0 || tickValue <= 0 || point <= 0) return 0.0;
      double lossPerLot = (stopDistPoints * point / tickSize) * tickValue;
      double lossMoney  = lossPerLot * lots;
      return (lossMoney / equity) * 100.0;
     }

   bool ResolveUndersized(ENUM_OMEGA_TIER tier, double intendedPct, double actualPct) const
     {
      if(actualPct <= intendedPct + 0.01) return true;
      int mode = m_undersizedBehavior;
      if(mode == UNDERSIZED_STRICT)  return false;
      if(mode == UNDERSIZED_SKIP)    return false;
      if(mode == UNDERSIZED_PROCEED) return true;
      return (tier == TIER_MICRO || tier == TIER_SMALL);
     }

   double LotsFor(string symbol, double riskPct, double stopDistPoints, const OmegaCapital &cap) const
     {
      riskPct = OmegaMath::Clamp(riskPct, 0.0, m_hardCeiling);
      double throttle = cap.Throttle();
      double effectivePct = riskPct * throttle;
      if(effectivePct <= 0.0) return 0.0;
      double equity = EffectiveEquity(cap);
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
            if(notionalCap > 0 && lots > notionalCap) lots = notionalCap;
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
      return ok;
     }

   double Base()        const { return m_base; }
   double Normal()      const { return m_normal; }
   double Strong()      const { return m_strong; }
   double Exceptional() const { return m_exceptional; }
   double HardCeiling() const { return m_hardCeiling; }
   bool   AllowMicro()  const { return m_allowMicro; }
   bool   CentAccount() const { return m_centAccount; }
   int    UndersizedBehavior() const { return m_undersizedBehavior; }
  };

#endif // __OMEGA_RISK_MQH__
