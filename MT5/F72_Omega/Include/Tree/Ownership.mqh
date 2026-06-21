//+------------------------------------------------------------------+
//|                                                    Ownership.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 6 — Principle 8 ownership:                               |
//|   Ownership belongs to the SHALLOWEST curve that still holds     |
//|   energy. A child only takes over once the parent dissipates     |
//|   below the floor.                                               |
//|                                                                  |
//|   Inputs: array of CurveNode (whole tree)                        |
//|   Outputs: index of dominant owner, depth, direction, energy,    |
//|            and an "ownership stability" metric (0..100) used by  |
//|            the trinity supporting field.                         |
//+------------------------------------------------------------------+
#ifndef __OMEGA_OWNERSHIP_MQH__
#define __OMEGA_OWNERSHIP_MQH__

#include "CurveNode.mqh"

//=== Result struct =================================================
struct OwnershipResult
  {
   int       index;          // -1 if none
   int       depth;
   int       direction;
   double    energy;
   double    stability;      // 0..100

                     OwnershipResult()
     {
      index = -1; depth = 999; direction = 0;
      energy = 0; stability = OMEGA_TRINITY_NEUTRAL;
     }
  };

class Ownership
  {
public:
   //--- Pick the dominant owner. Threshold floor = ownMinE.
   //    Tie-breaker: deepest among shallow ties (shouldn't happen
   //    since we walk by depth ascending). Fallback: highest energy
   //    alive node if none crosses the floor.
   static OwnershipResult Pick(CurveNode &tree[], int count, double ownMinE = 12.0)
     {
      OwnershipResult r;

      //-- preferred: shallowest with energy >= floor; ties -> highest energy
      for(int i = 0; i < count; i++)
        {
         if(!tree[i].alive)               continue;
         if(tree[i].energy < ownMinE)     continue;
         if(tree[i].depth < r.depth ||
            (tree[i].depth == r.depth && tree[i].energy > r.energy))
           {
            r.index     = i;
            r.depth     = tree[i].depth;
            r.energy    = tree[i].energy;
            r.direction = tree[i].dir;
           }
        }

      //-- fallback: any alive, highest energy
      if(r.index < 0)
        {
         double best = -1.0;
         for(int i = 0; i < count; i++)
           {
            if(!tree[i].alive) continue;
            if(tree[i].energy > best)
              {
               best = tree[i].energy;
               r.index     = i;
               r.depth     = tree[i].depth;
               r.energy    = tree[i].energy;
               r.direction = tree[i].dir;
              }
           }
        }

      //-- stability: how far the dominant owner is above the floor,
      //   blended with the energy gap to second-best alive node.
      if(r.index >= 0)
        {
         double secondBest = 0.0;
         for(int i = 0; i < count; i++)
           {
            if(i == r.index || !tree[i].alive) continue;
            if(tree[i].energy > secondBest) secondBest = tree[i].energy;
           }
         double aboveFloor = OmegaMath::Clamp((r.energy - ownMinE) / (100.0 - ownMinE), 0.0, 1.0);
         double gap        = OmegaMath::Clamp((r.energy - secondBest) / 100.0, 0.0, 1.0);
         r.stability = OmegaMath::Clamp(aboveFloor * 60.0 + gap * 40.0, 0.0, 100.0);
        }
      else
        {
         r.stability = OMEGA_TRINITY_NEUTRAL;
        }

      return r;
     }
  };

#endif // __OMEGA_OWNERSHIP_MQH__
