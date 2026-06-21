//+------------------------------------------------------------------+
//|                                                    CurveNode.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 4–8 — the atomic curve in the recursive tree.            |
//|                                                                  |
//|   A CurveNode is born from an EVENT, not from a timeframe:       |
//|   either the chart-TF wave engine spawns a fresh root (dir       |
//|   established, no living owner) OR a Phase-2 CHoCH against the   |
//|   current owner spawns a CHILD curve (same lifecycle, opposite   |
//|   orientation).                                                  |
//|                                                                  |
//|   Each node has:                                                 |
//|     id          — monotonic integer (set by CurveTree)           |
//|     parentId    — -1 for root, else id of parent                 |
//|     dir         — +1 long / -1 short                             |
//|     origin      — price where the curve was born                 |
//|     extreme     — best price the curve has reached so far        |
//|     energy      — 0..100, rises on progress, decays on stall     |
//|     alive       — false when energy <= 2 OR ownership released   |
//|     depth       — 0 = root, 1 = first child, etc.                |
//|     state       — emergent phase string (Principle 1 / 14)       |
//|     bar         — bar index at birth                             |
//|     comp        — compression at birth                           |
//|     mat         — maturity (waveProgress %) at birth             |
//|     srcTf       — 0=chart, 5=H1, 6=H4 (where the curve lives)    |
//|     forceAtBirth, forcePeak, forceAtDeath                        |
//|     birthTime, deathTime                                         |
//|     deathCause  — taxonomy (transfer / merge / decay / terminal) |
//|                                                                  |
//|   The state string is computed by f_nodeState() (below) — phases |
//|   EMERGE from the curve, not the legacy machine. Recursion       |
//|   depth > 0 means the node lives in the Transition family.       |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CURVE_NODE_MQH__
#define __OMEGA_CURVE_NODE_MQH__

#include "../Common.mqh"
#include "../CampaignDB.mqh"

//=== Node death taxonomy (mirrors campaign death cause) ============
enum ENUM_NODE_DEATH
  {
   NODE_ALIVE                   = 0,
   NODE_DEATH_DECAY             = 1,
   NODE_DEATH_TRANSFERRED       = 2,
   NODE_DEATH_MERGED            = 3,
   NODE_DEATH_TERMINAL_INDUCTION= 4,
   NODE_DEATH_REGIME_SHIFT      = 5
  };

//=== The node ======================================================
struct CurveNode
  {
   long             id;
   long             parentId;
   int              dir;
   double           origin;
   double           extreme;
   double           energy;
   bool             alive;
   int              depth;
   string           state;
   int              bar;
   double           comp;
   double           mat;
   int              srcTf;
   double           forceAtBirth;
   double           forcePeak;
   double           forceAtDeath;
   datetime         birthTime;
   datetime         deathTime;
   ENUM_NODE_DEATH  deathCause;
   long             campaignId;     // optional FK into CampaignDB

                     CurveNode() { Reset(); }

   void Reset()
     {
      id = 0; parentId = -1; dir = 0;
      origin = 0; extreme = 0; energy = 0;
      alive = false; depth = 0; state = "";
      bar = 0; comp = 0; mat = 0; srcTf = 0;
      forceAtBirth = forcePeak = forceAtDeath = 0;
      birthTime = 0; deathTime = 0;
      deathCause = NODE_ALIVE;
      campaignId = 0;
     }

   //--- Phase the curve OWNS — emergent from energy / depth / comp / mat
   string EmergentState() const
     {
      if(depth > 0)
        {
         if(energy >= 70.0) return "Transition · recursive expansion";
         if(energy >= 40.0) return "Transition · recursive induction";
         return "Transition · recursive liquidation";
        }
      if(mat < 12.0) return "Point 4 Origin";
      if(energy >= 78.0 && mat >= 70.0)
         return (dir == 1 ? "New High" : (dir == -1 ? "New Low" : "Climax"));
      if(mat < 35.0)        return "Expansion";
      if(mat < 55.0)        return "Expansion Pre-Convexity";
      if(energy >= 55.0)    return "Expansion Induction";
      if(energy >= 35.0)    return "Expansion Liquidity";
      if(comp >= 60.0)      return "Retracement Pre-Convexity";
      if(energy >= 18.0)    return "Retracement Induction";
      return "Retracement";
     }

   //--- progress test on the latest bar — feeds energy update
   bool Progressed(double barHigh, double barLow) const
     {
      if(!alive) return false;
      if(dir == 1)  return barHigh > extreme;
      if(dir == -1) return barLow  < extreme;
      return false;
     }

   //--- short snapshot for logs
   string Snapshot() const
     {
      return StringFormat("id=%I64d p=%I64d dir=%d depth=%d e=%.0f mat=%.0f comp=%.0f %s alive=%s",
                          id, parentId, dir, depth, energy, mat, comp, state, alive?"Y":"N");
     }
  };

#endif // __OMEGA_CURVE_NODE_MQH__
