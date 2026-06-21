//+------------------------------------------------------------------+
//|                                                   FlipEngine.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 14 — FU candle / flip zone engine.                       |
//|                                                                  |
//|   Detects FU spikes (dominant rejection wicks at local extremes) |
//|   on the chart timeframe and tracks each as a flip zone.         |
//|   Mirrors the Pine `f_fuPool` logic.                             |
//|                                                                  |
//|   Zone lifecycle:                                                |
//|     1. spike detected → zone TOUCHED at birth                    |
//|     2. price returns within tolerance → REACTED if it reverses,  |
//|        VIOLATED if close breaks past the wick tip                |
//|     3. age > maxAge → EXPIRED                                    |
//|                                                                  |
//|   "True induction" is the LOWEST active flip zone in the         |
//|   current owner direction with the strongest reaction count.     |
//|   The DecisionEngine will read it as a high-conviction protective|
//|   level.                                                         |
//+------------------------------------------------------------------+
#ifndef __OMEGA_FLIP_ENGINE_MQH__
#define __OMEGA_FLIP_ENGINE_MQH__

#include "ParticipantZone.mqh"
#include "../Logger.mqh"
#include "../Curve/Curve.mqh"

#define OMEGA_FLIP_CAP        24
#define OMEGA_FLIP_AGE_MAX   300
#define OMEGA_FLIP_WICK_FRAC 0.30   // wick / range threshold

class FlipEngine
  {
private:
   ParticipantZone m_zones[OMEGA_FLIP_CAP];
   int             m_count;
   long            m_detectedTotal;

   //--- detection state
   double          m_prevHigh;
   double          m_prevLow;
   datetime        m_lastBarTime;
   string          m_symbol;

   //--- composite outputs
   double          m_quality;          // 0..100 average defence score
   int             m_trueInductionIdx; // index of "lowest" active flip in owner dir
   double          m_truePx;
   int             m_truePxDir;

   int FindFreeSlot()
     {
      for(int i = 0; i < m_count; i++)
         if(!m_zones[i].active && m_zones[i].state == ZONE_EXPIRED) return i;
      if(m_count < OMEGA_FLIP_CAP) return m_count++;
      //-- evict oldest
      int evict = 0;
      datetime oldest = m_zones[0].born;
      for(int i = 1; i < m_count; i++)
         if(m_zones[i].born < oldest) { oldest = m_zones[i].born; evict = i; }
      return evict;
     }

   void MaybeRecord(double tip, int dir, double atr, double bodyHi, double bodyLo)
     {
      int slot = FindFreeSlot();
      if(slot < 0) return;
      double midPx = (dir == -1) ? (bodyHi + (tip - bodyHi) * 0.5)
                                 : (tip + (bodyLo - tip) * 0.5);
      double tol = atr * 0.30;
      m_zones[slot].Init(ZONE_TYPE_FU_FLIP, dir, midPx, tol);
      m_detectedTotal++;
      OmegaLogger::LogInfo("FLIP",
         StringFormat("FU detected · dir=%d tip=%.5f mid=%.5f tol=%.5f", dir, tip, midPx, tol));
     }

public:
                     FlipEngine()
     {
      Reset();
      m_symbol = "";
     }

   void Reset()
     {
      for(int i = 0; i < OMEGA_FLIP_CAP; i++) m_zones[i].Reset();
      m_count          = 0;
      m_detectedTotal  = 0;
      m_prevHigh = m_prevLow = 0;
      m_lastBarTime    = 0;
      m_quality        = OMEGA_TRINITY_NEUTRAL;
      m_trueInductionIdx = -1;
      m_truePx         = 0; m_truePxDir = 0;
     }

   void Init(string sym)
     {
      Reset();
      m_symbol = sym;
      OmegaLogger::LogInfo("FLIP", StringFormat("Init %s · cap=%d wickFrac=%.2f age=%d",
                            sym, OMEGA_FLIP_CAP, OMEGA_FLIP_WICK_FRAC, OMEGA_FLIP_AGE_MAX));
     }

   //--- per closed bar
   bool Update(OmegaCurve &curve)
     {
      CurveState *chart = curve.ChartTfState();
      if(chart == NULL || !chart.physics.ready) return false;
      datetime t = chart.lastBarTime;
      if(t == 0 || t == m_lastBarTime) return false;
      m_lastBarTime = t;

      double atr = chart.physics.atr;
      if(atr <= 0) return false;

      double h1 = iHigh(m_symbol,  chart.tf, 1);
      double l1 = iLow(m_symbol,   chart.tf, 1);
      double o1 = iOpen(m_symbol,  chart.tf, 1);
      double c1 = iClose(m_symbol, chart.tf, 1);

      //--- detect FU spike at local extreme
      double rng = MathMax(h1 - l1, 1e-10);
      double upperWick = h1 - MathMax(o1, c1);
      double lowerWick = MathMin(o1, c1) - l1;
      bool localTop = (m_prevHigh > 0 && h1 >= m_prevHigh);
      bool localBot = (m_prevLow  > 0 && l1 <= m_prevLow);
      bool bearFu   = (upperWick / rng) >= OMEGA_FLIP_WICK_FRAC && (localTop || c1 < o1);
      bool bullFu   = (lowerWick / rng) >= OMEGA_FLIP_WICK_FRAC && (localBot || c1 > o1);

      if(bearFu)
         MaybeRecord(h1, -1, atr, MathMax(o1, c1), MathMin(o1, c1));
      if(bullFu)
         MaybeRecord(l1, +1, atr, MathMax(o1, c1), MathMin(o1, c1));

      m_prevHigh = h1; m_prevLow = l1;

      //--- update existing zones
      double scoreSum = 0; int activeN = 0;
      for(int i = 0; i < m_count; i++)
        {
         if(m_zones[i].active)
           {
            m_zones[i].Update(h1, l1, c1, atr);
            m_zones[i].ExpireIfOld(OMEGA_FLIP_AGE_MAX);
           }
         if(m_zones[i].active) { activeN++; scoreSum += m_zones[i].DefenceScore(); }
        }
      m_quality = (activeN > 0) ? (scoreSum / activeN) : OMEGA_TRINITY_NEUTRAL;

      //--- pick the "true induction" — strongest defence at the most-protective price
      //    in the OWNER's direction.
      int    ownerDir = curve.tree.ownerDir;
      m_trueInductionIdx = -1;
      if(ownerDir != 0)
        {
         double bestScore = -1.0;
         double bestPx    = 0.0;
         for(int i = 0; i < m_count; i++)
           {
            if(!m_zones[i].active) continue;
            if(m_zones[i].direction != ownerDir) continue;
            double s = m_zones[i].DefenceScore();
            //-- prefer zones with reactions; tie-break by extremity (lowest for bull / highest for bear)
            if(s > bestScore || (MathAbs(s - bestScore) < 1e-6 &&
               ((ownerDir == 1 && m_zones[i].price < bestPx) ||
                (ownerDir == -1 && m_zones[i].price > bestPx))))
              {
               bestScore = s;
               bestPx    = m_zones[i].price;
               m_trueInductionIdx = i;
              }
           }
         if(m_trueInductionIdx >= 0)
           {
            m_truePx    = m_zones[m_trueInductionIdx].price;
            m_truePxDir = ownerDir;
           }
        }
      return true;
     }

   //--- accessors
   double Quality()      const { return m_quality; }
   int    Active()       const
     {
      int n = 0;
      for(int i = 0; i < m_count; i++) if(m_zones[i].active) n++;
      return n;
     }
   long   DetectedTotal() const { return m_detectedTotal; }
   bool   HasTrueInduction() const { return m_trueInductionIdx >= 0; }
   double TrueInductionPrice() const { return m_truePx; }
   int    TrueInductionDir()   const { return m_truePxDir; }

   string Snapshot() const
     {
      return StringFormat("flip[q=%.0f active=%d detected=%I64d ind=%s%s]",
                          m_quality, Active(), m_detectedTotal,
                          HasTrueInduction() ? "Y" : "N",
                          HasTrueInduction()
                            ? StringFormat(" px=%.5f", m_truePx)
                            : "");
     }
  };

#endif // __OMEGA_FLIP_ENGINE_MQH__
