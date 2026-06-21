//+------------------------------------------------------------------+
//|                                                     Transfer.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 6/7 — ownership TRANSFER.                                |
//|                                                                  |
//|   "TRANSFERRED · new campaign" — a counter-direction child curve |
//|   has BROKEN the parent's protective structure and is now the    |
//|   dominant owner. The old campaign is dead; the trader's call is |
//|   to flip to the counter side.                                   |
//|                                                                  |
//|   Detection:                                                     |
//|     - candidate child has dir opposite to parent                 |
//|     - close has crossed the parent's ORIGIN (the protective      |
//|       extreme — beyond it, the parent's structure is invalidated)|
//|     - parent's energy is leaking (≤ 35 at the moment of break)   |
//|                                                                  |
//|   Transfer is a one-shot event; once detected we mark parent     |
//|   alive=false / deathCause=TRANSFERRED and bubble the campaign   |
//|   through CampaignDB.                                            |
//+------------------------------------------------------------------+
#ifndef __OMEGA_TRANSFER_MQH__
#define __OMEGA_TRANSFER_MQH__

#include "CurveNode.mqh"

class Transfer
  {
public:
   //--- Test whether `childIdx` represents a transfer break of `parentIdx`.
   //    `closeNow` is the latest closed-bar close of the chart TF.
   static bool IsTransferEvent(CurveNode &tree[], int count,
                                int childIdx, int parentIdx, double closeNow)
     {
      if(childIdx < 0 || childIdx >= count) return false;
      if(parentIdx < 0 || parentIdx >= count) return false;
      if(!tree[childIdx].alive)  return false;
      if(!tree[parentIdx].alive) return false;
      if(tree[childIdx].dir == 0 || tree[parentIdx].dir == 0) return false;
      if(tree[childIdx].dir == tree[parentIdx].dir) return false;       // child must be counter
      if(tree[parentIdx].energy > 35.0) return false;                   // parent must be leaking
      double parentOrigin = tree[parentIdx].origin;
      if(parentOrigin == 0.0) return false;
      //-- bull child against bear parent: close must rise ABOVE parent origin
      if(tree[childIdx].dir == 1  && closeNow > parentOrigin) return true;
      if(tree[childIdx].dir == -1 && closeNow < parentOrigin) return true;
      return false;
     }

   //--- Apply: mark parent as transferred. Returns true if it changed.
   static bool Apply(CurveNode &tree[], int count, int parentIdx, datetime now)
     {
      if(parentIdx < 0 || parentIdx >= count) return false;
      if(!tree[parentIdx].alive) return false;
      tree[parentIdx].alive       = false;
      tree[parentIdx].deathTime   = now;
      tree[parentIdx].deathCause  = NODE_DEATH_TRANSFERRED;
      tree[parentIdx].forceAtDeath= tree[parentIdx].energy;
      return true;
     }
  };

#endif // __OMEGA_TRANSFER_MQH__
