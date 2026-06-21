//+------------------------------------------------------------------+
//|                                                         Meta.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 9 + 12 + 14 — meta orchestrator.                         |
//|                                                                  |
//|   Sits BELOW Story (which has already written life/stability/    |
//|   confidence to the trinity) and ABOVE Risk/Capital/Execution.   |
//|                                                                  |
//|   On each closed bar:                                            |
//|     1. SelfObservation.Sample(trinity)                           |
//|     2. Regime.Compute → state.supporting.regime                  |
//|     3. Probability.Compute → state.supporting.pContinuation/T/X  |
//|     4. SelfObservation.SelfTrust → blend INTO state.confidence   |
//|        so the trinity reflects engine self-trust                 |
//|                                                                  |
//|   This is where the engine TRACKS ITSELF.                        |
//+------------------------------------------------------------------+
#ifndef __OMEGA_META_MQH__
#define __OMEGA_META_MQH__

#include "Regime.mqh"
#include "Probability.mqh"
#include "SelfObservation.mqh"
#include "../Logger.mqh"
#include "../Memory.mqh"
#include "../Curve/Curve.mqh"
#include "../Narrative/Story.mqh"

class OmegaMeta
  {
public:
   //--- subcomponents
   SelfObservation  selfObs;
   ProbabilityCloud lastCloud;
   RegimeResult     lastRegime;

   //--- weight: how much SelfTrust pulls Confidence away from Story's value
   double           selfTrustBlend;

   //--- bookkeeping
   datetime         lastBarTime;
   long             barsProcessed;

                     OmegaMeta()
     {
      selfTrustBlend = 0.30;     // 30% blend by default
      lastBarTime = 0;
      barsProcessed = 0;
     }

   void Init(double blend = 0.30)
     {
      selfObs.Reset();
      selfTrustBlend = OmegaMath::Clamp(blend, 0.0, 1.0);
      OmegaLogger::LogInfo("META",
         StringFormat("Init · self-trust blend=%.0f%% · samples cap=%d",
                       selfTrustBlend * 100.0, OMEGA_SELFOBS_SAMPLES));
     }

   //--- Per closed bar, AFTER Story.Update has populated the trinity.
   bool Update(OmegaState &state, OmegaCurve &curve, const OmegaStory &story)
     {
      datetime t = curve.ChartTfState() != NULL ? curve.ChartTfState().lastBarTime : 0;
      if(t == 0 || t == lastBarTime) return false;
      lastBarTime = t;
      barsProcessed++;

      //--- 1. sample the trinity
      selfObs.Sample(state.life, state.stability, state.confidence);

      //--- 2. regime
      lastRegime = Regime::Compute(state, curve, story);
      state.supporting.regime = lastRegime.score;

      //--- 3. probability cloud
      lastCloud = Probability::Compute(state, curve, story);
      state.supporting.pContinuation = lastCloud.pContinuation;
      state.supporting.pTerminal     = lastCloud.pTerminal;
      state.supporting.pTransfer     = lastCloud.pTransfer;

      //--- 4. blend self-trust into confidence
      double selfTrust = selfObs.SelfTrust();
      state.confidence = OmegaMath::Clamp(
         state.confidence * (1.0 - selfTrustBlend) + selfTrust * selfTrustBlend,
         0.0, 100.0);

      //--- 5. recompute stability with regime now populated (Story used neutral)
      state.stability = OmegaMath::Clamp(
         state.supporting.alignment  * 0.40 +
         state.supporting.narrative  * 0.40 +
         state.supporting.regime     * 0.20,
         0.0, 100.0);

      return true;
     }

   //--- Hook for CampaignPositions to feed back outcomes
   void RegisterTradeOutcome(ENUM_OMEGA_DECISION dec, double pnl)
     {
      selfObs.RegisterOutcome(dec, pnl);
     }

   void RecordDecision(ENUM_OMEGA_DECISION dec)
     {
      selfObs.RecordDecision(dec);
     }

   string Snapshot() const
     {
      return StringFormat("regime=%s(%.0f) %s · meta[%s]",
                          lastRegime.tag, lastRegime.score,
                          Probability::CloudString(lastCloud),
                          selfObs.Snapshot());
     }
  };

#endif // __OMEGA_META_MQH__
