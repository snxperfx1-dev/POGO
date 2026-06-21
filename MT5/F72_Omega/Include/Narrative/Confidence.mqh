//+------------------------------------------------------------------+
//|                                                   Confidence.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 14 — StoryConfidence · "How much do I trust myself?"     |
//|                                                                  |
//|   Phase 4 baseline: confidence is a slow-moving composite of the |
//|   ENGINE's current internal coherence:                           |
//|                                                                  |
//|     ownership certainty   — is one curve clearly dominant?       |
//|     chain-life agreement  — does life agree with chain scope?    |
//|     compression clarity   — is compression NOT oscillating?      |
//|     narrative consistency — votes one-sided or balanced?         |
//|     alignment             — fractal stack agreement              |
//|                                                                  |
//|   Phase 6 (SelfObservation) will OVERWRITE this with rolling     |
//|   hit-rate / contradiction / regime-stability metrics derived    |
//|   from decision_log.csv. This module's API stays the same so     |
//|   the upgrade is transparent to upstream.                        |
//+------------------------------------------------------------------+
#ifndef __OMEGA_NARRATIVE_CONFIDENCE_MQH__
#define __OMEGA_NARRATIVE_CONFIDENCE_MQH__

#include "../Common.mqh"

//=== Inputs ========================================================
struct ConfidenceInputs
  {
   double  ownershipStability;   // 0..100, from tree
   double  chainHealthScore;     // 0..100, from chain
   double  life;                 // 0..100, from LifeScore
   double  compression;          // 0..100, raw
   double  compTighten;          // signed Δ
   double  alignment;            // 0..100, from Alignment
   int     supVotes;             // narrative
   int     degVotes;             // narrative
   bool    primed;
  };

class ConfidenceTracker
  {
private:
   double m_score;       // 0..100, slow-moving
   double m_alpha;       // EMA smoothing factor

public:
                     ConfidenceTracker() { Reset(); }

   void Reset()
     {
      m_score = OMEGA_TRINITY_NEUTRAL;
      m_alpha = 0.10;       // ~10-bar half-life
     }

   void Update(const ConfidenceInputs &in)
     {
      if(!in.primed)
        {
         //-- not perceiving yet → no claim of confidence
         m_score = m_score + m_alpha * (OMEGA_TRINITY_NEUTRAL - m_score);
         return;
        }

      //-- 1. Ownership certainty: directly from stability score
      double cOwn = in.ownershipStability;

      //-- 2. Chain-life agreement: chain health and life should AGREE.
      //     Penalize divergence.
      double diff = MathAbs(in.chainHealthScore - in.life);
      double cChain = OmegaMath::Clamp(100.0 - diff, 0.0, 100.0);

      //-- 3. Compression clarity: tightening is more "readable" than oscillation.
      //     Reward compression movement (either direction); penalize zero/random.
      double cComp = OmegaMath::Clamp(50.0 + MathAbs(in.compTighten) * 5.0, 0.0, 100.0);

      //-- 4. Narrative consistency: votes one-sided gives confidence,
      //     balanced votes erodes it.
      int totVotes = in.supVotes + in.degVotes;
      double cNarr = OMEGA_TRINITY_NEUTRAL;
      if(totVotes > 0)
        {
         double dom = MathMax(in.supVotes, in.degVotes) / (double)totVotes;
         cNarr = OmegaMath::Clamp(dom * 100.0, 0.0, 100.0);
        }

      //-- 5. Alignment: directly from the fractal stack
      double cAlign = in.alignment;

      //-- weighted blend (Phase 6 will tune via SelfObservation)
      double composite = cOwn   * 0.25
                       + cChain * 0.20
                       + cComp  * 0.15
                       + cNarr  * 0.15
                       + cAlign * 0.25;
      composite = OmegaMath::Clamp(composite, 0.0, 100.0);

      //-- slow EMA (confidence shouldn't whip around)
      m_score = m_score + m_alpha * (composite - m_score);
     }

   double Score() const { return m_score; }
  };

#endif // __OMEGA_NARRATIVE_CONFIDENCE_MQH__
