//+------------------------------------------------------------------+
//|                                            ParticipantEngine.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 13 — Fibonacci participant zones (0.618 / 0.70 / 0.786). |
//|                                                                  |
//|   "Everything leaves footprints — not because indicators work,   |
//|    because participants work."                                   |
//|                                                                  |
//|   The owner curve's leg (origin → extreme) defines three         |
//|   participant retracement levels. Each level is a zone that gets |
//|   touched / reacts / gets violated. The engine tracks them all:  |
//|                                                                  |
//|     0.618  — Fibonacci participants (textbook entry crowd)       |
//|     0.70   — interference (between Fib and 0.786)                |
//|     0.786  — heavy (deep retracement; ICT / aggressive swing)    |
//|                                                                  |
//|   When the owner curve flips direction, the old zones expire and |
//|   three new ones are constructed on the new leg.                 |
//|                                                                  |
//|   Outputs ParticipantState:                                      |
//|     activeCount       — zones currently alive                    |
//|     stability         — composite defence score 0..100           |
//|     reactionRate      — fraction of touches that became reactions|
//|     deepestActive     — deepest zone still active (0.618 / .70 / |
//|                         .786 / NONE) — informs decision engine   |
//|     manipulationFlag  — set when 0.70 violated AND 0.786 reacted |
//|                         (classic "stop hunt then continuation")  |
//+------------------------------------------------------------------+
#ifndef __OMEGA_PARTICIPANT_ENGINE_MQH__
#define __OMEGA_PARTICIPANT_ENGINE_MQH__

#include "ParticipantZone.mqh"
#include "../Logger.mqh"
#include "../Curve/Curve.mqh"

#define OMEGA_PART_ZONE_AGE_MAX 200

class ParticipantEngine
  {
private:
   //--- the three Fibonacci zones for the current owner leg
   ParticipantZone  m_fib618;
   ParticipantZone  m_fib70;
   ParticipantZone  m_fib786;

   //--- last leg context (so we know when to re-spawn)
   int              m_lastOwnerDir;
   double           m_lastLegOrigin;
   double           m_lastLegExtreme;
   long             m_legSpawns;

   //--- composite state
   double           m_stability;       // 0..100
   double           m_reactionRate;    // 0..1
   ENUM_ZONE_TYPE   m_deepestActive;
   bool             m_manipulationFlag;

   //--- bookkeeping
   string           m_symbol;
   datetime         m_lastBarTime;

   //--- spawn the three zones from a fresh leg
   void SpawnZones(int dir, double origin, double extreme, double atr)
     {
      double leg = MathAbs(extreme - origin);
      if(leg < atr * 1.5) return;   // leg too small to bother

      double px618 = (dir == 1) ? extreme - leg * 0.618 : extreme + leg * 0.618;
      double px70  = (dir == 1) ? extreme - leg * 0.70  : extreme + leg * 0.70;
      double px786 = (dir == 1) ? extreme - leg * 0.786 : extreme + leg * 0.786;
      double tol = atr * 0.25;

      m_fib618.Init(ZONE_TYPE_FIB_618, dir, px618, tol);
      m_fib70 .Init(ZONE_TYPE_FIB_70 , dir, px70 , tol);
      m_fib786.Init(ZONE_TYPE_FIB_786, dir, px786, tol);
      m_legSpawns++;
      OmegaLogger::LogInfo("PART",
         StringFormat("ZONES spawn · dir=%d leg=%.5f · 618=%.5f 70=%.5f 786=%.5f tol=%.5f",
                       dir, leg, px618, px70, px786, tol));
     }

   //--- evaluate composite stability + manipulation flag
   void Recompute()
     {
      int active   = 0;
      int touches  = 0;
      int reacts   = 0;
      int violates = 0;
      double scoreSum = 0.0;
      //-- accumulate from all three zones (no pointers — MQL5 forbids
      //   pointers to struct types).
      touches  += m_fib618.touchCount    + m_fib70.touchCount    + m_fib786.touchCount;
      reacts   += m_fib618.reactionCount + m_fib70.reactionCount + m_fib786.reactionCount;
      violates += m_fib618.violationCount+ m_fib70.violationCount+ m_fib786.violationCount;
      if(m_fib618.active) { active++; scoreSum += m_fib618.DefenceScore(); }
      if(m_fib70 .active) { active++; scoreSum += m_fib70 .DefenceScore(); }
      if(m_fib786.active) { active++; scoreSum += m_fib786.DefenceScore(); }
      m_stability    = (active > 0) ? (scoreSum / active) : OMEGA_TRINITY_NEUTRAL;
      m_reactionRate = (touches > 0) ? ((double)reacts / touches) : 0.0;

      //--- deepest active zone
      m_deepestActive = ZONE_TYPE_NONE;
      if(m_fib618.active) m_deepestActive = ZONE_TYPE_FIB_618;
      if(m_fib70 .active) m_deepestActive = ZONE_TYPE_FIB_70;
      if(m_fib786.active) m_deepestActive = ZONE_TYPE_FIB_786;

      //--- manipulation: 0.70 was VIOLATED and 0.786 then REACTED
      m_manipulationFlag = (m_fib70.state == ZONE_VIOLATED) &&
                            (m_fib786.state == ZONE_REACTED);
     }

public:
                     ParticipantEngine()
     {
      Reset();
      m_symbol = "";
     }

   void Reset()
     {
      m_fib618.Reset(); m_fib70.Reset(); m_fib786.Reset();
      m_lastOwnerDir   = 0;
      m_lastLegOrigin  = 0; m_lastLegExtreme = 0;
      m_legSpawns      = 0;
      m_stability      = OMEGA_TRINITY_NEUTRAL;
      m_reactionRate   = 0;
      m_deepestActive  = ZONE_TYPE_NONE;
      m_manipulationFlag = false;
      m_lastBarTime = 0;
     }

   void Init(string sym)
     {
      Reset();
      m_symbol = sym;
      OmegaLogger::LogInfo("PART", StringFormat("Init %s", sym));
     }

   //--- per closed bar
   bool Update(OmegaCurve &curve)
     {
      CurveState *chart = curve.ChartTfState();
      if(chart == NULL || !chart.physics.ready) return false;
      datetime t = chart.lastBarTime;
      if(t == 0 || t == m_lastBarTime) return false;
      m_lastBarTime = t;

      double atr = chart.physics.atr;
      if(atr <= 0) return false;

      //--- resolve leg from owner
      int idx = curve.tree.ownerIndex;
      int    ownerDir     = (idx >= 0) ? curve.tree.tree[idx].dir     : 0;
      double ownerOrigin  = (idx >= 0) ? curve.tree.tree[idx].origin  : 0.0;
      double ownerExtreme = (idx >= 0) ? curve.tree.tree[idx].extreme : 0.0;

      //--- re-spawn when direction changes OR when the leg has materially shifted
      bool dirChanged   = (ownerDir != m_lastOwnerDir);
      bool legShifted   = (MathAbs(ownerExtreme - m_lastLegExtreme) > atr * 2.0)
                       || (MathAbs(ownerOrigin  - m_lastLegOrigin)  > atr * 2.0);
      if(ownerDir != 0 && (dirChanged || (legShifted && m_legSpawns == 0)))
        {
         SpawnZones(ownerDir, ownerOrigin, ownerExtreme, atr);
         m_lastOwnerDir   = ownerDir;
         m_lastLegOrigin  = ownerOrigin;
         m_lastLegExtreme = ownerExtreme;
        }

      //--- update each active zone with the just-closed bar
      double bar1H = iHigh(m_symbol,  chart.tf, 1);
      double bar1L = iLow(m_symbol,   chart.tf, 1);
      double bar1C = iClose(m_symbol, chart.tf, 1);
      m_fib618.Update(bar1H, bar1L, bar1C, atr);
      m_fib70 .Update(bar1H, bar1L, bar1C, atr);
      m_fib786.Update(bar1H, bar1L, bar1C, atr);
      m_fib618.ExpireIfOld(OMEGA_PART_ZONE_AGE_MAX);
      m_fib70 .ExpireIfOld(OMEGA_PART_ZONE_AGE_MAX);
      m_fib786.ExpireIfOld(OMEGA_PART_ZONE_AGE_MAX);

      Recompute();
      return true;
     }

   //--- accessors
   double Stability()         const { return m_stability; }
   double ReactionRate()      const { return m_reactionRate; }
   int    ActiveCount()       const
     {
      int n = 0;
      if(m_fib618.active) n++;
      if(m_fib70 .active) n++;
      if(m_fib786.active) n++;
      return n;
     }
   ENUM_ZONE_TYPE DeepestActive() const { return m_deepestActive; }
   bool   ManipulationFlag()  const { return m_manipulationFlag; }
   long   SpawnCount()        const { return m_legSpawns; }

   //--- price queries (for DecisionEngine to use as protective levels)
   double PriceFor(ENUM_ZONE_TYPE t) const
     {
      switch(t)
        {
         case ZONE_TYPE_FIB_618:  return m_fib618.active ? m_fib618.price : 0.0;
         case ZONE_TYPE_FIB_70:   return m_fib70 .active ? m_fib70 .price : 0.0;
         case ZONE_TYPE_FIB_786:  return m_fib786.active ? m_fib786.price : 0.0;
        }
      return 0.0;
     }

   string DeepestString() const
     {
      switch(m_deepestActive)
        {
         case ZONE_TYPE_FIB_618: return "0.618";
         case ZONE_TYPE_FIB_70:  return "0.70";
         case ZONE_TYPE_FIB_786: return "0.786";
        }
      return "none";
     }

   string Snapshot() const
     {
      return StringFormat("part[stab=%.0f rr=%.0f%% deepest=%s active=%d spawns=%I64d %s] · %s · %s · %s",
                          m_stability, m_reactionRate * 100.0, DeepestString(),
                          ActiveCount(), m_legSpawns,
                          m_manipulationFlag ? "MANIP" : "—",
                          m_fib618.Snapshot(),
                          m_fib70 .Snapshot(),
                          m_fib786.Snapshot());
     }
  };

#endif // __OMEGA_PARTICIPANT_ENGINE_MQH__
