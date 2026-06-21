//+------------------------------------------------------------------+
//|                                                  Probability.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 12 — Probability Clouds.                                 |
//|                                                                  |
//|   "Not one outcome. Many."                                       |
//|                                                                  |
//|   Updated every closed bar, normalised to sum 100:               |
//|     pContinuation — current curve persists                       |
//|     pTerminal     — current curve terminates (LIFE_DEAD soon)    |
//|     pTransfer     — ownership transfers to counter side          |
//|                                                                  |
//|   Logits are unnormalised scores; final cloud = logits / Σlogits.|
//|   Feeds OmegaSupporting.pContinuation/Terminal/Transfer.         |
//+------------------------------------------------------------------+
#ifndef __OMEGA_META_PROBABILITY_MQH__
#define __OMEGA_META_PROBABILITY_MQH__

#include "../Common.mqh"
#include "../Curve/Curve.mqh"
#include "../Narrative/Story.mqh"

struct ProbabilityCloud
  {
   double pContinuation;   // 0..100
   double pTerminal;       // 0..100
   double pTransfer;       // 0..100

                     ProbabilityCloud() { pContinuation = pTerminal = pTransfer = 0; }
  };

class Probability
  {
public:
   static ProbabilityCloud Compute(const OmegaState &state, OmegaCurve &curve, const OmegaStory &story)
     {
      ProbabilityCloud c;

      //--- continuation logit
      double lContinue = 10.0;
      lContinue += state.life * 0.6;                                 // life is the key driver
      if(story.narrative.State() == NARR_STATE_STRENGTHENING) lContinue += 25.0;
      if(state.supporting.alignment >= 66.0)                  lContinue += 20.0;
      if(curve.gForceState == FORCE_PERSISTING)               lContinue += 25.0;
      int budgetLeft = curve.tree.recursionBudget - curve.tree.treeDepth;
      if(budgetLeft > 0)                                      lContinue += budgetLeft * 8.0;
      if(story.progressing)                                   lContinue += 15.0;
      lContinue = OmegaMath::Clamp(lContinue, 0.0, 200.0);

      //--- terminal logit
      double lTerminal = 5.0;
      lTerminal += (100.0 - state.life) * 0.3;
      if(story.retrX > 75.0)                                  lTerminal += 25.0;
      if(curve.gForceState == FORCE_LEAKING)                  lTerminal += 22.0;
      if(story.recursionComplete)                             lTerminal += 30.0;
      if(curve.tree.chain.Scope(state.life) == CHAIN_WHOLE_DECAYING)
                                                              lTerminal += 35.0;
      lTerminal = OmegaMath::Clamp(lTerminal, 0.0, 200.0);

      //--- transfer logit
      double lTransfer = 5.0;
      if(curve.tree.transfersCount > 0)                       lTransfer += 30.0;
      if(curve.tree.treeDepth >= 1)                           lTransfer += 15.0;
      if(state.supporting.ownershipStability < 30.0)          lTransfer += 25.0;
      if(state.supporting.alignment < 33.0)                   lTransfer += 15.0;
      lTransfer = OmegaMath::Clamp(lTransfer, 0.0, 200.0);

      //--- normalise to 100
      double sum = lContinue + lTerminal + lTransfer;
      if(sum < 1e-9)
        {
         c.pContinuation = 33.34; c.pTerminal = 33.33; c.pTransfer = 33.33;
        }
      else
        {
         c.pContinuation = lContinue / sum * 100.0;
         c.pTerminal     = lTerminal / sum * 100.0;
         c.pTransfer     = lTransfer / sum * 100.0;
        }
      return c;
     }

   static string CloudString(const ProbabilityCloud &c)
     {
      return StringFormat("cont=%.0f%% term=%.0f%% trans=%.0f%%",
                          c.pContinuation, c.pTerminal, c.pTransfer);
     }
  };

#endif // __OMEGA_META_PROBABILITY_MQH__
