//+------------------------------------------------------------------+
//|                                                        Force.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 5/7 — Compression Persistence.                           |
//|                                                                  |
//|   "After a break + pullback, the question is NOT 'how deep will  |
//|    it retrace?' but 'can the COUNTER side even generate room to  |
//|    build?'."                                                     |
//|                                                                  |
//|   Force composite (0..100):                                      |
//|     PERSISTING   → ≥ 60  · counter-side suffocating, hold        |
//|     NEUTRAL      → 35..60 · undecided                            |
//|     LEAKING      → ≤ 35  · origin in play, ownership transferring|
//|                                                                  |
//|   Inputs (Phase 2: compression + tightening only; Phase 3 will   |
//|   fold in residual energy and recursion depth from the curve     |
//|   tree):                                                         |
//|     compNow            (0..100, current compression)             |
//|     compTighten        (Δ compression over recent bars)          |
//|     residualEnergy     (0..100, Phase 4)                         |
//|     recursionDepth     (Phase 3)                                 |
//+------------------------------------------------------------------+
#ifndef __OMEGA_FORCE_MQH__
#define __OMEGA_FORCE_MQH__

#include "Compression.mqh"

enum ENUM_OMEGA_FORCE_STATE
  {
   FORCE_LEAKING     = 0,
   FORCE_NEUTRAL     = 1,
   FORCE_PERSISTING  = 2
  };

class ForceHelper
  {
public:
   //--- Composite force score (0..100). Phase 2 inputs only.
   static double Score(double compNow, double compTighten,
                       double residualEnergy = 0.0, int recursionDepth = 0)
     {
      double s = compNow * 0.50
               + residualEnergy * 0.20
               - (double)recursionDepth * 12.0
               + MathMax(0.0, compTighten) * 0.8
               + 8.0;
      return OmegaMath::Clamp(s, 0.0, 100.0);
     }

   static ENUM_OMEGA_FORCE_STATE State(double score)
     {
      if(score >= 60.0) return FORCE_PERSISTING;
      if(score <= 35.0) return FORCE_LEAKING;
      return FORCE_NEUTRAL;
     }

   static string StateString(ENUM_OMEGA_FORCE_STATE s)
     {
      switch(s)
        {
         case FORCE_PERSISTING: return "PERSISTING";
         case FORCE_LEAKING:    return "LEAKING";
         case FORCE_NEUTRAL:    return "NEUTRAL";
        }
      return "UNKNOWN";
     }

   static string TightenTrend(double compTighten)
     {
      if(compTighten >  3.0) return "TIGHTENING";
      if(compTighten < -3.0) return "BROADENING";
      return "STABLE";
     }
  };

#endif // __OMEGA_FORCE_MQH__
