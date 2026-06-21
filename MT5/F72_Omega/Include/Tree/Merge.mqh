//+------------------------------------------------------------------+
//|                                                        Merge.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 6/7 — child→parent MERGE.                                |
//|                                                                  |
//|   "MERGED → parent (B → A)" — a counter-direction child curve    |
//|   FAILED to break the parent's structure and DIED while still    |
//|   inside the parent's range. The parent's campaign continues —   |
//|   the child was a recursive dissipation event, not a handoff.    |
//|                                                                  |
//|   Detection (called when a child node is about to die from       |
//|   energy decay):                                                 |
//|     - child has dir opposite to parent                           |
//|     - child died WITHOUT breaking parent origin                  |
//|     - parent is still alive at the moment of child death         |
//|                                                                  |
//|   On merge: child's deathCause = MERGED, parent.energy gets a    |
//|   small REINFORCEMENT (+5, capped 100) — the campaign survived a |
//|   probe and is healthier for it.                                 |
//+------------------------------------------------------------------+
#ifndef __OMEGA_MERGE_MQH__
#define __OMEGA_MERGE_MQH__

#include "CurveNode.mqh"

class Merge
  {
public:
   //--- Test whether `childIdx` should merge back into `parentIdx`.
   //    Called at the moment a child's energy <= 2.
   static bool IsMergeEvent(CurveNode &tree[], int count,
                             int childIdx, int parentIdx, double closeNow)
     {
      if(childIdx < 0 || childIdx >= count) return false;
      if(parentIdx < 0 || parentIdx >= count) return false;
      if(!tree[parentIdx].alive) return false;
      if(tree[childIdx].dir == tree[parentIdx].dir) return false;
      double parentOrigin = tree[parentIdx].origin;
      if(parentOrigin == 0.0) return false;
      //-- child died WITHOUT crossing parent origin (parent's structure intact)
      if(tree[parentIdx].dir == 1  && closeNow > parentOrigin) return true;
      if(tree[parentIdx].dir == -1 && closeNow < parentOrigin) return true;
      return false;
     }

   //--- Apply the merge: child becomes MERGED, parent gets reinforcement.
   //    Returns true if it changed state.
   static bool Apply(CurveNode &tree[], int count,
                      int childIdx, int parentIdx, datetime now)
     {
      if(childIdx < 0 || childIdx >= count) return false;
      if(parentIdx < 0 || parentIdx >= count) return false;
      tree[childIdx].alive        = false;
      tree[childIdx].deathTime    = now;
      tree[childIdx].deathCause   = NODE_DEATH_MERGED;
      tree[childIdx].forceAtDeath = tree[childIdx].energy;
      //-- reinforcement: campaign survived a probe
      tree[parentIdx].energy   = OmegaMath::Clamp(tree[parentIdx].energy + 5.0, 0.0, 100.0);
      if(tree[parentIdx].energy > tree[parentIdx].forcePeak)
         tree[parentIdx].forcePeak = tree[parentIdx].energy;
      return true;
     }
  };

#endif // __OMEGA_MERGE_MQH__
