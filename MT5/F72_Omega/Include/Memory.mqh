//+------------------------------------------------------------------+
//|                                                       Memory.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   The TRINITY container.                                         |
//|                                                                  |
//|   life       — "Is the story still alive?"  (Layer 7)            |
//|   stability  — "How stable is the narrative?" (Layer 3)          |
//|   confidence — "How much do I trust myself?" (Layer 14)          |
//|                                                                  |
//|   Every other module FEEDS the trinity. Risk, Capital, and       |
//|   Execution READ the trinity. The dependency hierarchy is        |
//|   strict and one-directional.                                    |
//|                                                                  |
//|   In Phase 1 the perception layers (curve, force, chain,         |
//|   narrative) are not built yet — primed=false — so the trinity   |
//|   stays at its neutral 50.0 anchor and the engine deliberately   |
//|   does not act. That neutrality IS a state, and the engine logs  |
//|   it explicitly each heartbeat as REASON_PHASE_NOT_BUILT.        |
//+------------------------------------------------------------------+
#ifndef __OMEGA_MEMORY_MQH__
#define __OMEGA_MEMORY_MQH__

#include "Common.mqh"

//=== The supporting fields the perception layers populate ==========
//   Layer order matches the user's spec:
//     Universe → Curve → Compression → Convexity → Force → Ownership
//     → Recursion → Chain → Narrative → LifeScore → StoryStability
//     → StoryConfidence → Risk → Capital → Execution
//
//   Each lower layer only WRITES to its own field; it never reads
//   anything above it. DeriveTrinity() folds them upward.
//===================================================================
struct OmegaSupporting
  {
   //--- physics (Phase 2)
   double  forceScore;
   double  compression;
   double  convexity;
   //--- structure (Phase 3)
   double  ownershipStability;
   double  chainHealth;
   int     recursionDepth;
   int     recursionBudget;
   //--- narrative (Phase 4)
   double  alignment;
   double  narrative;
   //--- regime / probabilities (Phase 6)
   double  regime;
   double  pContinuation;
   double  pTerminal;
   double  pTransfer;
  };

//=== State container ===============================================
class OmegaState
  {
public:
   //--- THE TRINITY (the only three values decisions are allowed to read)
   double           life;
   double           stability;
   double           confidence;

   //--- the supporting layers (perception)
   OmegaSupporting  supporting;

   //--- bookkeeping
   datetime         updated;
   long             tickCount;
   bool             primed;          // false until perception layers exist
   bool             dirty;           // true when persistence should flush

                    OmegaState() { Reset(); }

   void Reset()
     {
      life        = OMEGA_TRINITY_NEUTRAL;
      stability   = OMEGA_TRINITY_NEUTRAL;
      confidence  = OMEGA_TRINITY_NEUTRAL;
      ZeroMemory(supporting);
      updated     = 0;
      tickCount   = 0;
      primed      = false;
      dirty       = false;
     }

   //--- The contract every later phase must satisfy:
   //    LifeScore folds force/ownership/chain/compression upward.
   //    StoryStability folds alignment/narrative/regime upward.
   //    StoryConfidence is updated independently by SelfObservation
   //    (Phase 6); we only clamp it here.
   //
   //    Weights here are sketches — the ACTUAL tuning happens against
   //    campaign memory in Phase 6. The shape, not the numbers, is
   //    what matters in Phase 1.
   void DeriveTrinity()
     {
      if(!primed)
        {
         //-- engine cannot yet perceive — anchor at neutral
         life       = OMEGA_TRINITY_NEUTRAL;
         stability  = OMEGA_TRINITY_NEUTRAL;
         confidence = OMEGA_TRINITY_NEUTRAL;
         return;
        }
      //-- LifeScore: Layer 6 + 7 + 5 + 5 (force, ownership, chain, compression)
      life = OmegaMath::Clamp(
         supporting.forceScore           * 0.35 +
         supporting.ownershipStability   * 0.25 +
         supporting.chainHealth          * 0.25 +
         supporting.compression          * 0.15,
         0.0, 100.0);
      //-- StoryStability: Layer 3 + 8 + 9 (alignment, narrative, regime)
      stability = OmegaMath::Clamp(
         supporting.alignment            * 0.40 +
         supporting.narrative            * 0.40 +
         supporting.regime               * 0.20,
         0.0, 100.0);
      //-- StoryConfidence is OWNED by SelfObservation; clamp only here
      confidence = OmegaMath::Clamp(confidence, 0.0, 100.0);
     }

   //--- short snapshot for logs
   string Snapshot() const
     {
      return StringFormat("L=%.1f S=%.1f C=%.1f primed=%s tick=%I64d",
                          life, stability, confidence,
                          primed ? "YES" : "NO", tickCount);
     }
  };

#endif // __OMEGA_MEMORY_MQH__
