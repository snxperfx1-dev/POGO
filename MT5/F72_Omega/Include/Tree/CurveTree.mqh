//+------------------------------------------------------------------+
//|                                                    CurveTree.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 4–8 — the recursive curve tree.                          |
//|                                                                  |
//|   Owns a fixed-capacity array of CurveNode. Drives the lifecycle |
//|   on each closed bar:                                            |
//|                                                                  |
//|     1. spawn root if no owner exists and chart curve has direction|
//|     2. spawn child on Phase-2 CHoCH against owner (if budget left)|
//|     3. update each alive node's energy from progress / decay     |
//|     4. detect TRANSFER / MERGE events                            |
//|     5. recompute ownership                                       |
//|     6. update ChainHealth                                        |
//|     7. rotate dead nodes out (cap = 32)                          |
//|                                                                  |
//|   Outputs (consumed by Curve.mqh / supporting fields):           |
//|     ownerIndex, ownerDir, ownerEnergy, ownerStability             |
//|     treeDepth, recursionBudget, treeAlive                        |
//|     chainHealth.Score(), chainHealth.Vitality()                  |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CURVE_TREE_MQH__
#define __OMEGA_CURVE_TREE_MQH__

#include "CurveNode.mqh"
#include "Ownership.mqh"
#include "Transfer.mqh"
#include "Merge.mqh"
#include "ChainHealth.mqh"
#include "../Logger.mqh"
#include "../Curve/CurveState.mqh"

#define OMEGA_TREE_CAPACITY    32
#define OMEGA_OWN_MIN_ENERGY   12.0

class OmegaCurveTree
  {
public:
   CurveNode         tree[OMEGA_TREE_CAPACITY];
   int               count;            // current number of nodes (alive + recently dead)
   long              nextNodeId;
   ChainHealth       chain;

   //--- last-update outputs
   int               ownerIndex;
   int               ownerDir;
   int               ownerDepth;
   double            ownerEnergy;
   double            ownerStability;
   double            ownerLife;        // proxy = ownerEnergy until Phase 4 wires real Life
   int               treeAlive;
   int               treeDepth;
   int               recursionBudget;

   //--- transfer / merge counters (for explainability)
   long              transfersCount;
   long              mergesCount;
   long              spawnsCount;
   long              decaysCount;

   //--- bookkeeping
   string            symbol;
   ENUM_TIMEFRAMES   chartTf;
   datetime          lastBarTime;
   long              barsProcessed;

private:
   //--- find first free slot (or -1 if full); when full we evict the
   //    oldest dead node to make room.
   int FindFreeSlot()
     {
      for(int i = 0; i < count; i++)
         if(tree[i].id == 0) return i;
      if(count < OMEGA_TREE_CAPACITY) return count++;
      //-- full: evict oldest dead node by deathTime asc
      int evict = -1;
      datetime oldest = D'2099.01.01';
      for(int i = 0; i < count; i++)
        {
         if(tree[i].alive) continue;
         if(tree[i].deathTime > 0 && tree[i].deathTime < oldest)
           {
            oldest = tree[i].deathTime;
            evict = i;
           }
        }
      if(evict >= 0)
        {
         tree[evict].Reset();
         return evict;
        }
      //-- absolutely full of alive nodes — evict lowest-energy alive
      double minE = 1e9;
      for(int i = 0; i < count; i++)
         if(tree[i].alive && tree[i].energy < minE) { minE = tree[i].energy; evict = i; }
      if(evict >= 0) { tree[evict].Reset(); return evict; }
      return -1;
     }

   int IndexOfId(long id) const
     {
      if(id <= 0) return -1;
      for(int i = 0; i < count; i++)
         if(tree[i].id == id) return i;
      return -1;
     }

public:
                     OmegaCurveTree()
     {
      count = 0;
      nextNodeId = 1;
      ownerIndex = -1; ownerDir = 0; ownerDepth = 999;
      ownerEnergy = 0; ownerStability = OMEGA_TRINITY_NEUTRAL; ownerLife = 0;
      treeAlive = 0; treeDepth = 0; recursionBudget = 1;
      transfersCount = mergesCount = spawnsCount = decaysCount = 0;
      symbol = ""; chartTf = PERIOD_CURRENT;
      lastBarTime = 0; barsProcessed = 0;
     }

   void Init(string sym, ENUM_TIMEFRAMES chart_tf)
     {
      symbol = sym;
      chartTf = chart_tf;
      OmegaLogger::LogInfo("TREE",
         StringFormat("Init %s tf=%d capacity=%d ownFloor=%.0f",
                      sym, (int)chart_tf, OMEGA_TREE_CAPACITY, OMEGA_OWN_MIN_ENERGY));
     }

   void Reset()
     {
      for(int i = 0; i < count; i++) tree[i].Reset();
      count = 0;
      nextNodeId = 1;
      chain.Reset();
      ownerIndex = -1; ownerDir = 0; ownerDepth = 999;
      ownerEnergy = 0; ownerStability = OMEGA_TRINITY_NEUTRAL; ownerLife = 0;
      treeAlive = 0; treeDepth = 0; recursionBudget = 1;
      transfersCount = mergesCount = spawnsCount = decaysCount = 0;
     }

   //--- Spawn a new root from the chart curve's wave context.
   //    Called when no living owner exists and the chart curve has dir.
   void SpawnRoot(const CurveState &cs)
     {
      int slot = FindFreeSlot();
      if(slot < 0) return;
      tree[slot].Reset();
      tree[slot].id          = nextNodeId++;
      tree[slot].parentId    = -1;
      tree[slot].dir         = cs.dir;
      tree[slot].origin      = (cs.dir == 1) ? cs.p4l : cs.p4h;
      tree[slot].extreme     = (cs.dir == 1) ? MathMax(cs.cycH, iHigh(symbol, chartTf, 1))
                                              : MathMin(cs.cycL, iLow(symbol, chartTf, 1));
      tree[slot].energy      = MathMax(40.0, MathMin(60.0 + cs.expScore * 0.4, 90.0));
      tree[slot].alive       = true;
      tree[slot].depth       = 0;
      tree[slot].bar         = (int)Bars(symbol, chartTf);
      tree[slot].comp        = cs.compIdx;
      tree[slot].mat         = cs.waveProgress;
      tree[slot].srcTf       = 0;
      tree[slot].forceAtBirth= tree[slot].energy;
      tree[slot].forcePeak   = tree[slot].energy;
      tree[slot].birthTime   = TimeCurrent();
      tree[slot].state       = tree[slot].EmergentState();
      spawnsCount++;
      OmegaLogger::LogInfo("TREE",
         StringFormat("ROOT spawn · %s · %s", symbol, tree[slot].Snapshot()));
     }

   //--- Spawn a child counter-curve from a CHoCH against the owner.
   //    Pre: owner exists, dir != newChildDir, recursion budget allows.
   void SpawnChild(int parentIdx, int newDir, const CurveState &cs)
     {
      if(parentIdx < 0 || parentIdx >= count) return;
      if(tree[parentIdx].depth + 1 > recursionBudget) return;
      int slot = FindFreeSlot();
      if(slot < 0) return;
      double bar1Close = iClose(symbol, chartTf, 1);
      tree[slot].Reset();
      tree[slot].id          = nextNodeId++;
      tree[slot].parentId    = tree[parentIdx].id;
      tree[slot].dir         = newDir;
      tree[slot].origin      = bar1Close;
      tree[slot].extreme     = bar1Close;
      tree[slot].energy      = MathMax(25.0, MathMin(50.0 + cs.expScore * 0.25, 70.0));
      tree[slot].alive       = true;
      tree[slot].depth       = tree[parentIdx].depth + 1;
      tree[slot].bar         = (int)Bars(symbol, chartTf);
      tree[slot].comp        = cs.compIdx;
      tree[slot].mat         = 0.0;
      tree[slot].srcTf       = 0;
      tree[slot].forceAtBirth= tree[slot].energy;
      tree[slot].forcePeak   = tree[slot].energy;
      tree[slot].birthTime   = TimeCurrent();
      tree[slot].state       = tree[slot].EmergentState();
      spawnsCount++;
      OmegaLogger::LogInfo("TREE",
         StringFormat("CHILD spawn · %s · parent=%I64d · %s",
                      symbol, tree[parentIdx].id, tree[slot].Snapshot()));
     }

   //--- Compute recursion budget (1..4) from compression tier.
   static int BudgetFromCompression(double compNow)
     {
      return (int)MathMax(1, MathMin(4, 1 + (int)MathRound(compNow / 33.0)));
     }

   //--- Walk the tree once on each closed bar.
   //    `cs` is the chart-TF CurveState (driver of spawn events).
   bool Update(CurveState &cs)
     {
      if(!cs.physics.ready) return false;
      datetime curBarT = cs.lastBarTime;
      if(curBarT == 0) return false;
      if(curBarT == lastBarTime) return false;
      lastBarTime = curBarT;
      barsProcessed++;

      double bar1Close = iClose(symbol, chartTf, 1);
      double bar1High  = iHigh(symbol, chartTf, 1);
      double bar1Low   = iLow(symbol, chartTf, 1);

      //--- 1. recursion budget (compression-derived)
      recursionBudget = BudgetFromCompression(cs.compIdx);

      //--- 2. find current owner
      OwnershipResult own = Ownership::Pick(tree, count, OMEGA_OWN_MIN_ENERGY);

      //--- 3. spawn root if none / spawn child on CHoCH against owner
      bool noOwner = (own.index < 0);
      if(noOwner && cs.dir != 0 && cs.p4h != 0.0 && cs.p4l != 0.0)
        {
         SpawnRoot(cs);
         own = Ownership::Pick(tree, count, OMEGA_OWN_MIN_ENERGY);
        }
      else if(own.index >= 0)
        {
         int ownIdx = own.index;
         int ownDir = tree[ownIdx].dir;
         //-- CHoCH against owner direction triggers child spawn
         if((ownDir == 1 && cs.bearCH) || (ownDir == -1 && cs.bullCH))
            SpawnChild(ownIdx, -ownDir, cs);
        }

      //--- 4. update each alive node's energy / extreme
      for(int i = 0; i < count; i++)
        {
         if(!tree[i].alive) continue;
         //-- Root (depth 0): track chart-TF cycle extreme so origin/extreme
         //   stay aligned with the wave engine. Children: track their own
         //   extension extreme.
         if(tree[i].depth == 0)
           {
            tree[i].dir     = cs.DirByOrigin();
            tree[i].origin  = cs.inv == 0.0 ? tree[i].origin : cs.inv;
            double e1 = (tree[i].dir == 1) ? ((cs.cycH == 0.0) ? bar1High : cs.cycH)
                                            : ((cs.cycL == 0.0) ? bar1Low  : cs.cycL);
            if(tree[i].dir == 1)  tree[i].extreme = MathMax(tree[i].extreme, e1);
            if(tree[i].dir == -1) tree[i].extreme = (tree[i].extreme == 0.0) ? e1 : MathMin(tree[i].extreme, e1);
           }
         else
           {
            if(tree[i].dir == 1)  tree[i].extreme = MathMax(tree[i].extreme, bar1High);
            if(tree[i].dir == -1) tree[i].extreme = (tree[i].extreme == 0.0) ? bar1Low : MathMin(tree[i].extreme, bar1Low);
           }

         bool prog = tree[i].Progressed(bar1High, bar1Low);
         if(prog) tree[i].energy = MathMin(100.0, tree[i].energy + 7.0);
         else     tree[i].energy = MathMax(0.0,   tree[i].energy - 2.0);
         if(tree[i].energy > tree[i].forcePeak) tree[i].forcePeak = tree[i].energy;
         tree[i].mat   = (tree[i].depth == 0) ? cs.waveProgress : tree[i].mat;
         tree[i].comp  = cs.compIdx;
         tree[i].state = tree[i].EmergentState();
        }

      //--- 5. detect death: energy <= 2 OR transfer break
      datetime now = TimeCurrent();
      for(int i = 0; i < count; i++)
        {
         if(!tree[i].alive) continue;
         //-- TRANSFER? — counter child has crossed parent origin
         if(tree[i].depth > 0)
           {
            int pIdx = IndexOfId(tree[i].parentId);
            if(pIdx >= 0 && Transfer::IsTransferEvent(tree, count, i, pIdx, bar1Close))
              {
               Transfer::Apply(tree, count, pIdx, now);
               transfersCount++;
               OmegaLogger::LogWarning("TREE",
                  StringFormat("TRANSFER · child #%I64d broke parent #%I64d · close=%.5f origin=%.5f",
                               tree[i].id, tree[pIdx].id, bar1Close, tree[pIdx].origin));
               chain.Sample(tree[pIdx].forceAtDeath);
              }
           }
         //-- DEATH BY DECAY? — and merge if applicable
         if(tree[i].energy <= 2.0)
           {
            ENUM_NODE_DEATH cause = NODE_DEATH_DECAY;
            int pIdx = IndexOfId(tree[i].parentId);
            if(tree[i].depth > 0 && pIdx >= 0
               && Merge::IsMergeEvent(tree, count, i, pIdx, bar1Close))
              {
               Merge::Apply(tree, count, i, pIdx, now);
               mergesCount++;
               OmegaLogger::LogInfo("TREE",
                  StringFormat("MERGE · child #%I64d -> parent #%I64d (campaign survived probe)",
                               tree[i].id, tree[pIdx].id));
               cause = NODE_DEATH_MERGED;
              }
            else
              {
               tree[i].alive       = false;
               tree[i].deathTime   = now;
               tree[i].deathCause  = cause;
               tree[i].forceAtDeath= tree[i].energy;
               decaysCount++;
              }
            chain.Sample(tree[i].forcePeak * 0.6); // sample at-death life proxy
           }
        }

      //--- 6. recompute ownership AFTER deaths
      own = Ownership::Pick(tree, count, OMEGA_OWN_MIN_ENERGY);
      ownerIndex     = own.index;
      ownerDir       = own.direction;
      ownerDepth     = own.depth;
      ownerEnergy    = own.energy;
      ownerStability = own.stability;
      ownerLife      = own.energy;       // Phase 4 will replace with real Life

      //--- 7. tree summary
      treeAlive = 0; treeDepth = 0;
      for(int i = 0; i < count; i++)
        {
         if(!tree[i].alive) continue;
         treeAlive++;
         if(tree[i].depth > treeDepth) treeDepth = tree[i].depth;
        }

      //--- 8. sample chain on the dominant owner (smooth signal)
      if(ownerIndex >= 0)
         chain.Sample(ownerEnergy);

      return true;
     }

   //--- Snapshot for heartbeat / explainability
   string Snapshot() const
     {
      return StringFormat(
         "owner=%d ownDir=%d ownE=%.0f ownStab=%.0f depth=%d/%d alive=%d trans=%I64d merge=%I64d decay=%I64d spawn=%I64d chain=%s(v=%.0f w=%.0f)",
         ownerIndex, ownerDir, ownerEnergy, ownerStability,
         treeDepth, recursionBudget, treeAlive,
         transfersCount, mergesCount, decaysCount, spawnsCount,
         ChainHealth::ScopeString(chain.Scope(ownerLife)),
         chain.Vitality(), chain.WholeChainLife());
     }
  };

#endif // __OMEGA_CURVE_TREE_MQH__
