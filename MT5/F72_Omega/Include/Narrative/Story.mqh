//+------------------------------------------------------------------+
//|                                                        Story.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 3 → 14 — the Narrative orchestrator.                     |
//|                                                                  |
//|   Sits BELOW the Curve+Tree perception and ABOVE Risk/Capital.   |
//|   On each closed bar it:                                         |
//|                                                                  |
//|     1. Reads the chart-TF curve + tree state                     |
//|     2. Computes LifeScore from the canonical formula             |
//|     3. Updates the NarrativeTracker (lineage votes)              |
//|     4. Computes Alignment + cross-TF story                       |
//|     5. Updates ConfidenceTracker                                 |
//|     6. Writes life / stability / confidence DIRECTLY into        |
//|        OmegaState (Memory's DeriveTrinity becomes a clamp guard) |
//|     7. Emits a plain-English "story" string for the heartbeat    |
//|                                                                  |
//|   This is where the Trinity goes fully live. After Phase 4 the   |
//|   engine has continuous awareness of the life of the story.      |
//+------------------------------------------------------------------+
#ifndef __OMEGA_NARRATIVE_STORY_MQH__
#define __OMEGA_NARRATIVE_STORY_MQH__

#include "LifeScore.mqh"
#include "NarrativeScore.mqh"
#include "Alignment.mqh"
#include "Confidence.mqh"
#include "../Memory.mqh"
#include "../Curve/Curve.mqh"

class OmegaStory
  {
public:
   //--- subcomponents
   NarrativeTracker  narrative;
   ConfidenceTracker confidence;

   //--- last-update outputs (exposed for snapshot / explainability)
   double            lastLife;
   double            lastStability;
   double            lastConfidence;
   int               bias;             // -1 / 0 / +1
   int               alignedCount;
   string            crossTfStory;
   ENUM_LIFE_VERDICT lifeVerdict;
   double            retrX;
   bool              progressing;
   bool              recursionComplete;

   //--- bookkeeping
   string            symbol;
   long              barsProcessed;
   datetime          lastBarTime;

                     OmegaStory()
     {
      lastLife = lastStability = lastConfidence = OMEGA_TRINITY_NEUTRAL;
      bias = 0; alignedCount = 0;
      crossTfStory = "—";
      lifeVerdict = LIFE_DEAD;
      retrX = 50.0;
      progressing = false; recursionComplete = false;
      symbol = ""; barsProcessed = 0; lastBarTime = 0;
     }

   void Init(string sym)
     {
      symbol = sym;
      narrative.Reset();
      confidence.Reset();
      OmegaLogger::LogInfo("STORY",
         StringFormat("Init %s · LifeScore + NarrativeTracker + ConfidenceTracker", sym));
     }

   void Reset()
     {
      narrative.Reset();
      confidence.Reset();
      lastLife = lastStability = lastConfidence = OMEGA_TRINITY_NEUTRAL;
      bias = 0; alignedCount = 0;
      crossTfStory = "—";
      lifeVerdict = LIFE_DEAD;
      retrX = 50.0;
      progressing = false; recursionComplete = false;
      barsProcessed = 0; lastBarTime = 0;
     }

   //--- Main per-bar narrative update. Writes directly to OmegaState.
   bool Update(OmegaState &state, OmegaCurve &curve)
     {
      if(!curve.primed) return false;
      CurveState *chart = curve.ChartTfState();
      if(chart == NULL) return false;
      if(!chart.physics.ready) return false;
      datetime t = chart.lastBarTime;
      if(t == 0 || t == lastBarTime) return false;
      lastBarTime = t;
      barsProcessed++;

      //=== 1. resolve owner state ===================================
      int idx = curve.tree.ownerIndex;
      int ownerDir = (idx >= 0) ? curve.tree.tree[idx].dir     : 0;
      double ownerOrigin  = (idx >= 0) ? curve.tree.tree[idx].origin  : 0.0;
      double ownerExtreme = (idx >= 0) ? curve.tree.tree[idx].extreme : 0.0;
      double ownerEnergy  = (idx >= 0) ? curve.tree.tree[idx].energy  : 0.0;

      double bar1Close = iClose(symbol, chart.tf, 1);
      double bar1High  = iHigh(symbol,  chart.tf, 1);
      double bar1Low   = iLow(symbol,   chart.tf, 1);

      //=== 2. derived life inputs ===================================
      progressing = false;
      if(ownerDir == 1  && ownerExtreme > 0.0) progressing = (bar1High >= ownerExtreme);
      if(ownerDir == -1 && ownerExtreme > 0.0) progressing = (bar1Low  <= ownerExtreme);

      retrX = 50.0;
      if(ownerOrigin != 0.0 && ownerExtreme != 0.0 && ownerOrigin != ownerExtreme)
        {
         retrX = MathMin(100.0,
                  MathAbs(ownerExtreme - bar1Close) /
                  MathAbs(ownerExtreme - ownerOrigin) * 100.0);
        }

      recursionComplete = (curve.tree.recursionBudget > 0
                           && curve.tree.treeDepth >= curve.tree.recursionBudget);

      LifeInputs li;
      li.cpForce           = curve.gForce;
      li.residualEnergy    = ownerEnergy;
      li.cmpTighten        = curve.compress.Tightening(5);
      li.retrX             = retrX;
      li.progressing       = progressing;
      li.recursionComplete = recursionComplete;
      li.forceLeaking      = (curve.gForceState == FORCE_LEAKING);

      double life = LifeScore::Compute(li);
      lifeVerdict = LifeScore::Verdict(life);

      //=== 3. narrative tracker =====================================
      narrative.Update(ownerDir, ownerOrigin, bar1High, bar1Low, bar1Close, li.cmpTighten);
      double narrScore = narrative.Score();

      //=== 4. alignment =============================================
      bias = ownerDir;
      alignedCount = Alignment::CountAligned(curve, bias);
      double alignScore = Alignment::Score(alignedCount);
      crossTfStory = Alignment::Story(alignedCount, bias);

      //=== 5. stability (Layer 3 fold: alignment + narrative + regime) =====
      //   Phase 4: regime stays neutral (Phase 6 will populate).
      double regime = OMEGA_TRINITY_NEUTRAL;
      double stability = OmegaMath::Clamp(
         alignScore  * 0.40 +
         narrScore   * 0.40 +
         regime      * 0.20,
         0.0, 100.0);

      //=== 6. confidence ============================================
      ConfidenceInputs ci;
      ci.ownershipStability = curve.tree.ownerStability;
      ci.chainHealthScore   = curve.tree.chain.Score(life);
      ci.life               = life;
      ci.compression        = curve.gCompression;
      ci.compTighten        = li.cmpTighten;
      ci.alignment          = alignScore;
      ci.supVotes           = narrative.SupportVotes();
      ci.degVotes           = narrative.DegradeVotes();
      ci.primed             = state.primed;
      confidence.Update(ci);

      //=== 7. write into the trinity ================================
      state.life       = life;
      state.stability  = stability;
      state.confidence = confidence.Score();

      //--- supporting fields (alignment + narrative live now)
      state.supporting.alignment = alignScore;
      state.supporting.narrative = narrScore;

      //=== bookkeeping outputs ======================================
      lastLife       = life;
      lastStability  = stability;
      lastConfidence = state.confidence;
      return true;
     }

   //--- short snapshot for heartbeat
   string Snapshot() const
     {
      return StringFormat(
         "L=%.1f(%s) S=%.1f C=%.1f bias=%d align=%d/6 retrX=%.0f%% prog=%s budget=%s · %s · cross=\"%s\"",
         lastLife, LifeScore::VerdictString(lifeVerdict),
         lastStability, lastConfidence,
         bias, alignedCount, retrX,
         progressing ? "Y" : "N",
         recursionComplete ? "DONE" : "LEFT",
         narrative.Snapshot(), crossTfStory);
     }

   //--- one-line trader voice (extends Snapshot for richer logging)
   string Voice() const
     {
      string lifeStr = LifeScore::VerdictString(lifeVerdict);
      string biasStr = (bias == 1 ? "BULL" : bias == -1 ? "BEAR" : "NEUTRAL");
      return StringFormat("%s curve · %s · L=%.0f S=%.0f C=%.0f · %s",
                          biasStr, lifeStr, lastLife, lastStability, lastConfidence,
                          crossTfStory);
     }
  };

#endif // __OMEGA_NARRATIVE_STORY_MQH__
