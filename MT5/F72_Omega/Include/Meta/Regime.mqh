//+------------------------------------------------------------------+
//|                                                       Regime.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 9 — regime detection.                                    |
//|                                                                  |
//|   What kind of session/day/regime are we in? Not from a clock,   |
//|   from STATE: alignment + force + narrative + chain.             |
//|                                                                  |
//|     EXPANSION_DAY  alignment ≥ 80 + force persisting + life ≥ 60 |
//|     TREND_DAY      alignment ≥ 65 + life ≥ 55                    |
//|     ROTATION_DAY   alignment ≤ 33  OR force leaking + chain weak |
//|     REVERSAL_DAY   transfer-recently OR narrative WEAKENING + dd |
//|     RANGE_DAY      everything else (low energy, inconclusive)    |
//|                                                                  |
//|   Score (0..100) is high for trending/clean, low for rotational. |
//|   Feeds OmegaSupporting.regime.                                  |
//+------------------------------------------------------------------+
#ifndef __OMEGA_META_REGIME_MQH__
#define __OMEGA_META_REGIME_MQH__

#include "../Common.mqh"
#include "../Curve/Curve.mqh"
#include "../Narrative/Story.mqh"

enum ENUM_OMEGA_REGIME
  {
   REGIME_RANGE_DAY     = 0,
   REGIME_TREND_DAY     = 1,
   REGIME_EXPANSION_DAY = 2,
   REGIME_ROTATION_DAY  = 3,
   REGIME_REVERSAL_DAY  = 4
  };

struct RegimeResult
  {
   ENUM_OMEGA_REGIME label;
   double            score;     // 0..100 — clean/trending high; messy low
   string            tag;
                     RegimeResult() { label = REGIME_RANGE_DAY; score = OMEGA_TRINITY_NEUTRAL; tag = "RANGE"; }
  };

class Regime
  {
public:
   static string LabelString(ENUM_OMEGA_REGIME r)
     {
      switch(r)
        {
         case REGIME_RANGE_DAY:     return "RANGE";
         case REGIME_TREND_DAY:     return "TREND";
         case REGIME_EXPANSION_DAY: return "EXPANSION";
         case REGIME_ROTATION_DAY:  return "ROTATION";
         case REGIME_REVERSAL_DAY:  return "REVERSAL";
        }
      return "?";
     }

   static RegimeResult Compute(const OmegaState &state, OmegaCurve &curve, const OmegaStory &story)
     {
      RegimeResult r;
      double align       = state.supporting.alignment;
      double life        = state.life;
      double force       = curve.gForce;
      bool   forceLeaking= (curve.gForceState == FORCE_LEAKING);
      bool   forcePersist= (curve.gForceState == FORCE_PERSISTING);
      double chain       = state.supporting.chainHealth;
      ENUM_NARRATIVE_STATE ns = story.narrative.State();
      bool   recentTransfer = (curve.tree.transfersCount > 0);  // Phase 6.1 — track time-windowed
      bool   narrWeakening = (ns == NARR_STATE_WEAKENING);

      //-- decision ladder
      if(align >= 80.0 && life >= 60.0 && forcePersist)
        {
         r.label = REGIME_EXPANSION_DAY;
         r.score = 80.0 + (life - 60.0) * 0.4;
        }
      else if(align >= 65.0 && life >= 55.0)
        {
         r.label = REGIME_TREND_DAY;
         r.score = 65.0 + (align - 65.0) * 0.3 + (life - 55.0) * 0.2;
        }
      else if(narrWeakening && (chain <= 40.0 || forceLeaking))
        {
         r.label = REGIME_REVERSAL_DAY;
         r.score = 35.0;
        }
      else if(align <= 33.0 || (forceLeaking && chain <= 45.0))
        {
         r.label = REGIME_ROTATION_DAY;
         r.score = 25.0;
        }
      else
        {
         r.label = REGIME_RANGE_DAY;
         r.score = 50.0;
        }
      r.score = OmegaMath::Clamp(r.score, 0.0, 100.0);
      r.tag   = LabelString(r.label);
      return r;
     }
  };

#endif // __OMEGA_META_REGIME_MQH__
