//+------------------------------------------------------------------+
//|                                                    Convexity.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 0 — convexity primitive.                                 |
//|                                                                  |
//|   "Energy cannot travel infinitely in straight lines."           |
//|                                                                  |
//|   Convexity = the rate of change of acceleration. The derivative |
//|   of motion that reveals when a move is about to turn before     |
//|   the turn shows up in the high/low. CurvePhysics already        |
//|   computes the smoothed convexity (csm); this module adds the    |
//|   normalized `score` and the discrete shift events.              |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CONVEXITY_MQH__
#define __OMEGA_CONVEXITY_MQH__

#include "CurveState.mqh"

class ConvexityHelper
  {
public:
   //--- 0..100 score — how convex the move currently is
   static double Score(const CurveState &cs)
     {
      return MathMin(MathAbs(cs.physics.csm) / MathMax(cs.physics.atr * cs.physics.convM, 1e-10) * 50.0,
                     100.0);
     }

   //--- shift sign: +1 = bull convex shift, -1 = bear, 0 = none
   static int ShiftSign(const CurveState &cs)
     {
      if(cs.physics.bullConvShift) return 1;
      if(cs.physics.bearConvShift) return -1;
      return 0;
     }

   //--- maturity (0..100) — how late is the curve in its convex life?
   //    Reads CurveState.waveProgress as the geometric anchor.
   static double Maturity(const CurveState &cs)
     {
      return OmegaMath::Clamp(cs.waveProgress, 0.0, 100.0);
     }
  };

#endif // __OMEGA_CONVEXITY_MQH__
