//+------------------------------------------------------------------+
//|                                                  ChainHealth.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 8 — Chain Vitality.                                      |
//|                                                                  |
//|   Three scopes of danger, distinguished:                         |
//|     - current CURVE in trouble (life low) but the chain is fine  |
//|     - current CHAIN weakening (life trending down across last N) |
//|     - the WHOLE chain decaying (life bled out across the lineage)|
//|                                                                  |
//|   Tracks two scalars:                                            |
//|     chainVitality   — 50 + (latestLife - firstLife) over recent  |
//|                       lives, clamped 0..100                      |
//|     wholeChainLife  — slow EMA of every life sample seen, 0..100 |
//|                                                                  |
//|   And rolls up into one of four labels for the supporting story. |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CHAIN_HEALTH_MQH__
#define __OMEGA_CHAIN_HEALTH_MQH__

#include "../Common.mqh"

enum ENUM_CHAIN_SCOPE
  {
   CHAIN_HEALTHY                 = 0,
   CHAIN_CURVE_ONLY              = 1,
   CHAIN_WEAKENING               = 2,
   CHAIN_WHOLE_DECAYING          = 3
  };

class ChainHealth
  {
private:
   double m_lifeSeq[];
   int    m_seqHead;
   int    m_seqCount;
   int    m_seqCapacity;
   double m_wholeChainLife;

public:
                     ChainHealth()
     {
      m_seqCapacity = 8;
      ArrayResize(m_lifeSeq, m_seqCapacity);
      Reset();
     }

   void Reset()
     {
      m_seqHead = 0;
      m_seqCount = 0;
      m_wholeChainLife = OMEGA_TRINITY_NEUTRAL;
      ArrayInitialize(m_lifeSeq, 0.0);
     }

   //--- Sample a new life value (called when a curve dies, OR each bar
   //    on the dominant owner). The slow EMA tracks the WHOLE history.
   void Sample(double life)
     {
      m_lifeSeq[m_seqHead] = life;
      m_seqHead = (m_seqHead + 1) % m_seqCapacity;
      if(m_seqCount < m_seqCapacity) m_seqCount++;
      m_wholeChainLife = m_wholeChainLife + 0.02 * (life - m_wholeChainLife);
     }

   //--- 0..100 — recent life trajectory anchored at 50
   double Vitality() const
     {
      if(m_seqCount < 2) return m_wholeChainLife;
      int latestIdx  = (m_seqHead - 1 + m_seqCapacity) % m_seqCapacity;
      int earliestIdx = (m_seqHead - m_seqCount + m_seqCapacity) % m_seqCapacity;
      double v = OMEGA_TRINITY_NEUTRAL + (m_lifeSeq[latestIdx] - m_lifeSeq[earliestIdx]);
      return OmegaMath::Clamp(v, 0.0, 100.0);
     }

   //--- 0..100 — slow EMA of every life ever sampled
   double WholeChainLife() const { return m_wholeChainLife; }

   //--- Composite label
   ENUM_CHAIN_SCOPE Scope(double currentLife) const
     {
      if(currentLife >= 50.0)            return CHAIN_HEALTHY;
      if(Vitality()  >= 50.0)            return CHAIN_CURVE_ONLY;
      if(WholeChainLife() >= 45.0)       return CHAIN_WEAKENING;
      return CHAIN_WHOLE_DECAYING;
     }

   static string ScopeString(ENUM_CHAIN_SCOPE s)
     {
      switch(s)
        {
         case CHAIN_HEALTHY:           return "HEALTHY";
         case CHAIN_CURVE_ONLY:        return "CURVE_ONLY";
         case CHAIN_WEAKENING:         return "CHAIN_WEAKENING";
         case CHAIN_WHOLE_DECAYING:    return "WHOLE_DECAYING";
        }
      return "UNKNOWN";
     }

   //--- 0..100 score for the trinity supporting field
   double Score(double currentLife) const
     {
      ENUM_CHAIN_SCOPE s = Scope(currentLife);
      switch(s)
        {
         case CHAIN_HEALTHY:        return OmegaMath::Clamp(60.0 + currentLife * 0.4, 0.0, 100.0);
         case CHAIN_CURVE_ONLY:     return OmegaMath::Clamp(50.0 + Vitality() * 0.3, 0.0, 100.0);
         case CHAIN_WEAKENING:      return OmegaMath::Clamp(35.0 + WholeChainLife() * 0.2, 0.0, 100.0);
         case CHAIN_WHOLE_DECAYING: return OmegaMath::Clamp(WholeChainLife() * 0.6, 0.0, 100.0);
        }
      return OMEGA_TRINITY_NEUTRAL;
     }
  };

#endif // __OMEGA_CHAIN_HEALTH_MQH__
