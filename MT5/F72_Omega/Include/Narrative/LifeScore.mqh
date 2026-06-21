//+------------------------------------------------------------------+
//|                                                    LifeScore.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 7 — "Is the trade alive?" The single judgement the art   |
//|   compresses to. Direct port of the Pine `_life` formula.        |
//|                                                                  |
//|   Composite of:                                                  |
//|     +0.45 × cpForce            — compression persistence force   |
//|     +0.30 × residualEnergy     — owner curve's energy            |
//|     +12   if compression tightening (counter side suffocating)   |
//|     -25   if recursion budget complete and not progressing       |
//|     -20   if force leaking and not progressing                   |
//|     +28   if progressing (price attacking owner extreme NOW)     |
//|     ±retrX bonus by retrace depth (shallow=healthy, deep=danger) |
//|     +10   base anchor                                            |
//|                                                                  |
//|   Output: 0..100. Used directly as the LifeScore in the Trinity. |
//|   Above 60 = ALIVE / HOLD. Below 32 = DEAD / FLIP. Middle =      |
//|   WEAKENING / MANAGE.                                            |
//+------------------------------------------------------------------+
#ifndef __OMEGA_NARRATIVE_LIFESCORE_MQH__
#define __OMEGA_NARRATIVE_LIFESCORE_MQH__

#include "../Common.mqh"

//=== Inputs to the Life formula ====================================
struct LifeInputs
  {
   double  cpForce;             // 0..100, from Force composite
   double  residualEnergy;      // 0..100, owner curve's energy
   double  cmpTighten;          // signed Δ compression
   double  retrX;               // 0..100, retrace from owner extreme toward origin
   bool    progressing;         // owner extreme is being attacked this bar
   bool    recursionComplete;   // tree depth has spent the budget
   bool    forceLeaking;        // ForceState == LEAKING

                     LifeInputs()
     {
      cpForce = 50.0; residualEnergy = 50.0; cmpTighten = 0.0; retrX = 50.0;
      progressing = false; recursionComplete = false; forceLeaking = false;
     }
  };

//=== The aliveness verdict =========================================
enum ENUM_LIFE_VERDICT
  {
   LIFE_DEAD       = 0,   // life ≤ 32 → FLIP to counter side
   LIFE_WEAKENING  = 1,   // 32 < life < 45 → MANAGE
   LIFE_HOLDING    = 2,   // 45 ≤ life < 60 → HOLD with caution
   LIFE_ALIVE      = 3    // life ≥ 60 → HOLD with conviction
  };

class LifeScore
  {
public:
   //--- Compute the life score from the formula above.
   static double Compute(const LifeInputs &in)
     {
      double life = in.cpForce * 0.45
                  + in.residualEnergy * 0.30
                  + (in.cmpTighten > 0.0 ? 12.0 : 0.0)
                  - (in.recursionComplete && !in.progressing ? 25.0 : 0.0)
                  - (in.forceLeaking      && !in.progressing ? 20.0 : 0.0)
                  + (in.progressing ? 28.0 : 0.0)
                  + (in.retrX < 25.0 ?  16.0 :
                     in.retrX < 45.0 ?   6.0 :
                     in.retrX > 75.0 ? -12.0 : 0.0)
                  + 10.0;
      return OmegaMath::Clamp(life, 0.0, 100.0);
     }

   //--- Verdict bucket
   static ENUM_LIFE_VERDICT Verdict(double life)
     {
      if(life >= 60.0) return LIFE_ALIVE;
      if(life >= 45.0) return LIFE_HOLDING;
      if(life >  32.0) return LIFE_WEAKENING;
      return LIFE_DEAD;
     }

   static string VerdictString(ENUM_LIFE_VERDICT v)
     {
      switch(v)
        {
         case LIFE_DEAD:      return "DEAD";
         case LIFE_WEAKENING: return "WEAKENING";
         case LIFE_HOLDING:   return "HOLDING";
         case LIFE_ALIVE:     return "ALIVE";
        }
      return "UNKNOWN";
     }
  };

#endif // __OMEGA_NARRATIVE_LIFESCORE_MQH__
