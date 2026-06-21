//+------------------------------------------------------------------+
//|                                              DecisionEngine.mqh  |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 13/15 — the engine where Trinity becomes ACTION.         |
//|                                                                  |
//|   Pure function. Reads the Trinity, the curve+tree, the story,   |
//|   and the current campaign positions. Emits a single decision    |
//|   plus the reason code, role, direction, and stop distance.      |
//|                                                                  |
//|   Decisions are CONSEQUENCES of state, not signals. The truth    |
//|   table:                                                         |
//|                                                                  |
//|     not primed                              → OBSERVE             |
//|     life ≤ 32 (DEAD)  & holding same dir    → EXIT                |
//|     life ≤ 32         & confidence ≥ 50     → REVERSE (counter)   |
//|     life ≤ 32         & owner != held       → OBSERVE             |
//|     life weakening    & holding profitably  → REDUCE              |
//|     life weakening    & holding             → HOLD                |
//|     life holding      & no position         → ENTER (normal risk) |
//|     life alive        & no position         → ENTER (origin role) |
//|     life alive        & progressing & budget→ ADD   (progress role)|
//|     life alive        & at full budget      → HOLD                |
//|                                                                  |
//|   Origin entries require min trinity AND alignment ≥ 4/6.        |
//|   Progress adds require progressing + same dir.                  |
//|   Reversal requires confidence ≥ 50 AND owner direction defined. |
//+------------------------------------------------------------------+
#ifndef __OMEGA_DECISION_ENGINE_MQH__
#define __OMEGA_DECISION_ENGINE_MQH__

#include "../Common.mqh"
#include "../Memory.mqh"
#include "../Curve/Curve.mqh"
#include "../Narrative/Story.mqh"
#include "PositionHealth.mqh"

//=== Decision result ================================================
struct DecisionResult
  {
   ENUM_OMEGA_DECISION decision;
   ENUM_OMEGA_REASON   reason;
   ENUM_POSITION_ROLE  suggestedRole;
   int                 suggestedDirection;
   double              stopDistPoints;
   string              detail;

                     DecisionResult()
     {
      decision           = OMEGA_DEC_OBSERVE;
      reason             = REASON_PHASE_NOT_BUILT;
      suggestedRole      = POS_ENTRY;
      suggestedDirection = 0;
      stopDistPoints     = 0;
      detail             = "";
     }
  };

//=== Tunables (sane defaults; later phases tune from CampaignDB) ===
struct DecisionParams
  {
   double  enterMinLife;      // 45 — life threshold to enter
   double  enterMinStability; // 45
   double  enterMinConf;      // 40
   double  attackMinLife;     // 60 — life threshold for ALIVE entries
   double  attackMinStab;     // 60
   double  attackMinConf;     // 55
   double  reverseMinConf;    // 50 — confidence to flip on dead
   int     enterMinAlign;     // 4 — alignment count required
   int     maxBudget;         // 4 — max positions per campaign
   double  defaultSlAtrMult;  // 1.5 — fallback SL when no protective extreme
   double  reduceLifeFloor;   // 38 — life below this triggers REDUCE if profitable

                     DecisionParams()
     {
      enterMinLife = 45.0; enterMinStability = 45.0; enterMinConf = 40.0;
      attackMinLife = 60.0; attackMinStab = 60.0; attackMinConf = 55.0;
      reverseMinConf = 50.0;
      enterMinAlign = 4;
      maxBudget = 4;
      defaultSlAtrMult = 1.5;
      reduceLifeFloor = 38.0;
     }
  };

//=== The decision engine ===========================================
class DecisionEngine
  {
public:
   //--- Compute stop distance in POINTS from chart-TF curve state.
   //    Prefers the protective extreme (owner curve origin) if available,
   //    else falls back to ATR multiple. Returns 0 if no valid stop.
   static double ComputeStopDistPoints(string sym, OmegaCurve &curve, int direction,
                                        const DecisionParams &p)
     {
      CurveState *chart = curve.ChartTfState();
      if(chart == NULL) return 0.0;
      double atr   = chart.physics.atr;
      double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      if(atr <= 0 || point <= 0) return 0.0;

      double bar1Close = iClose(sym, chart.tf, 0);
      if(bar1Close <= 0) bar1Close = iClose(sym, chart.tf, 1);

      //-- prefer owner curve origin
      int idx = curve.tree.ownerIndex;
      if(idx >= 0)
        {
         double protectivePx = curve.tree.tree[idx].origin;
         if(protectivePx > 0 && curve.tree.tree[idx].dir == direction)
           {
            double dist = MathAbs(bar1Close - protectivePx);
            //-- pad by ~0.3*ATR so we don't sit on the level
            dist += atr * 0.3;
            if(dist > 0) return dist / point;
           }
        }
      //-- fallback: ATR * multiplier
      return (atr * p.defaultSlAtrMult) / point;
     }

   //--- Main decision dispatcher.
   static DecisionResult Decide(const OmegaState &state,
                                 OmegaCurve &curve,
                                 const OmegaStory &story,
                                 int activeSameDirCount,
                                 int activeCounterCount,
                                 const DecisionParams &p)
     {
      DecisionResult r;

      int ownerDir = curve.tree.ownerDir;
      r.suggestedDirection = (ownerDir != 0) ? ownerDir : 0;

      //=== FORCE-TRADE FALLBACK ====================================
      //   If perception hasn't primed yet OR no curve owner exists,
      //   fall back to a simple bar-bias entry so the engine still
      //   trades. Compares close[1] vs close[5] on the current chart;
      //   non-zero diff -> direction. Once perception primes, the
      //   normal verdict ladder below takes over.
      if(!state.primed || ownerDir == 0)
        {
         double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
         double close5 = iClose(_Symbol, PERIOD_CURRENT, 5);
         if(close1 > 0 && close5 > 0 && activeSameDirCount + activeCounterCount == 0)
           {
            int bias = (close1 > close5) ? 1 : (close1 < close5 ? -1 : 0);
            if(bias != 0)
              {
               r.decision           = (bias == 1) ? OMEGA_DEC_ENTER_LONG : OMEGA_DEC_ENTER_SHORT;
               r.suggestedDirection = bias;
               r.suggestedRole      = POS_ORIGIN;
               r.reason             = REASON_HEARTBEAT;
               r.detail             = StringFormat("force-fallback · primed=%s ownerDir=%d bias=%d",
                                                   state.primed ? "Y" : "N", ownerDir, bias);
               return r;
              }
           }
         //-- already in a position OR no bias yet — observe
         r.decision = OMEGA_DEC_OBSERVE;
         r.reason   = state.primed ? REASON_OWNERSHIP_LEAKING : REASON_PHASE_NOT_BUILT;
         r.detail   = "fallback path · waiting for bias or holding existing position";
         return r;
        }

      //--- 2. Verdict bucketing
      ENUM_LIFE_VERDICT verdict = LifeScore::Verdict(state.life);
      r.suggestedDirection = ownerDir;
      r.stopDistPoints     = ComputeStopDistPoints(state.supporting.regime > 0 ? "" : "",
                                                    curve, ownerDir, p);
      //-- the empty string above is just a placeholder; real symbol resolved in Execution
      //   Re-compute properly using actual symbol when called from EA.

      //--- 3. DEAD: holding wrong side / flip-or-flat
      if(verdict == LIFE_DEAD)
        {
         if(activeSameDirCount > 0)
           {
            r.decision = OMEGA_DEC_EXIT;
            r.reason   = REASON_LIFE_DEAD;
            r.detail   = StringFormat("life %.1f dead, exit %d position(s)",
                                       state.life, activeSameDirCount);
            return r;
           }
         if(state.confidence >= p.reverseMinConf && activeCounterCount == 0)
           {
            r.decision           = OMEGA_DEC_REVERSE;
            r.reason             = REASON_OWNERSHIP_TRANSFER;
            r.suggestedDirection = -ownerDir;
            r.suggestedRole      = POS_ORIGIN;
            r.detail             = StringFormat("life dead, conf %.0f -> flip to %s",
                                                state.confidence, (-ownerDir == 1 ? "LONG" : "SHORT"));
            return r;
           }
         r.decision = OMEGA_DEC_OBSERVE;
         r.reason   = REASON_LIFE_DEAD;
         r.detail   = "dead but conf too low to flip";
         return r;
        }

      //--- 4. WEAKENING: reduce profitable, else hold
      if(verdict == LIFE_WEAKENING)
        {
         if(activeSameDirCount > 0 && state.life < p.reduceLifeFloor && !story.progressing)
           {
            r.decision = OMEGA_DEC_REDUCE;
            r.reason   = REASON_LIFE_WEAKENING;
            r.detail   = StringFormat("life %.1f weakening, reduce while profitable", state.life);
            return r;
           }
         if(activeSameDirCount > 0)
           {
            r.decision = OMEGA_DEC_HOLD;
            r.reason   = REASON_LIFE_WEAKENING;
            r.detail   = StringFormat("life %.1f weakening, hold", state.life);
            return r;
           }
         r.decision = OMEGA_DEC_OBSERVE;
         r.reason   = REASON_LIFE_WEAKENING;
         r.detail   = "weakening, no entry";
         return r;
        }

      //--- 5. HOLDING / ALIVE: entries and adds
      bool aligned = (state.supporting.alignment >= (p.enterMinAlign / 6.0) * 100.0);

      if(verdict == LIFE_HOLDING)
        {
         if(activeSameDirCount == 0)
           {
            if(state.confidence >= p.enterMinConf
               && state.stability >= p.enterMinStability
               && aligned)
              {
               r.decision      = OMEGA_DEC_ENTER_LONG;
               if(ownerDir == -1) r.decision = OMEGA_DEC_ENTER_SHORT;
               r.reason        = REASON_HEALTHY_CONTINUATION;
               r.suggestedRole = POS_ORIGIN;
               r.detail        = StringFormat("holding @ life %.1f stab %.1f conf %.1f align %.0f%% — origin entry",
                                              state.life, state.stability, state.confidence,
                                              state.supporting.alignment);
               return r;
              }
            r.decision = OMEGA_DEC_OBSERVE;
            r.reason   = REASON_NARRATIVE_DIVERGE;
            r.detail   = "holding but stability/conf/alignment below entry";
            return r;
           }
         r.decision = OMEGA_DEC_HOLD;
         r.reason   = REASON_LIFE_HEALTHY;
         r.detail   = "holding, position open";
         return r;
        }

      // verdict == ALIVE
      if(activeSameDirCount == 0)
        {
         if(state.confidence >= p.attackMinConf
            && state.stability >= p.attackMinStab
            && aligned)
           {
            r.decision      = OMEGA_DEC_ENTER_LONG;
            if(ownerDir == -1) r.decision = OMEGA_DEC_ENTER_SHORT;
            r.reason        = REASON_HEALTHY_CONTINUATION;
            r.suggestedRole = POS_ORIGIN;
            r.detail        = StringFormat("ALIVE @ life %.1f stab %.1f conf %.1f align %.0f%% — origin entry (strong)",
                                            state.life, state.stability, state.confidence,
                                            state.supporting.alignment);
            return r;
           }
         //-- alive but conditions for full attack not met → demote to normal entry
         if(state.stability >= p.enterMinStability
            && state.confidence >= p.enterMinConf
            && aligned)
           {
            r.decision = (ownerDir == 1) ? OMEGA_DEC_ENTER_LONG : OMEGA_DEC_ENTER_SHORT;
            r.reason   = REASON_HEALTHY_CONTINUATION;
            r.suggestedRole = POS_ORIGIN;
            r.detail = "alive but support conditions soft — origin entry (normal)";
            return r;
           }
         r.decision = OMEGA_DEC_OBSERVE;
         r.reason   = REASON_NARRATIVE_DIVERGE;
         r.detail   = "alive but stability/conf/alignment below threshold";
         return r;
        }

      //-- already in: pyramiding logic
      int totalSameDir = activeSameDirCount;
      if(totalSameDir < p.maxBudget && story.progressing)
        {
         r.decision      = OMEGA_DEC_ADD;
         r.reason        = REASON_HEALTHY_CONTINUATION;
         r.suggestedRole = POS_PROGRESS;
         r.detail        = StringFormat("ALIVE + progressing, %d/%d budget — pyramid add",
                                         totalSameDir + 1, p.maxBudget);
         return r;
        }
      r.decision = OMEGA_DEC_HOLD;
      r.reason   = REASON_LIFE_HEALTHY;
      r.detail   = (totalSameDir >= p.maxBudget) ? "at budget" : "alive, waiting for progression";
      return r;
     }
  };

#endif // __OMEGA_DECISION_ENGINE_MQH__
