//+------------------------------------------------------------------+
//|                                                        Curve.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 4 — multi-timeframe curve orchestrator.                  |
//|                                                                  |
//|   Holds six CurveState instances (M1, M3, M5, M15, H1, H4) and   |
//|   the compression tracker for the chart timeframe (the "owner    |
//|   curve" anchor in Phase 2; Phase 3 will pick the owner by       |
//|   energy from the curve tree).                                   |
//|                                                                  |
//|   Init() returns true once at least the chart-TF curve is fully  |
//|   ready (`ready=true`); from that moment forward the engine is   |
//|   PRIMED and every supporting field is populated, the trinity    |
//|   becomes live, and Risk gets to see real values.                |
//|                                                                  |
//|   Single source of truth for OmegaSupporting in Phase 2.         |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CURVE_MQH__
#define __OMEGA_CURVE_MQH__

#include "CurveState.mqh"
#include "Compression.mqh"
#include "Convexity.mqh"
#include "Force.mqh"
#include "../Memory.mqh"

class OmegaCurve
  {
public:
   //--- six TFs (Pine ladder, fixed for now; Phase 7 will adapt)
   CurveState         tfM1;
   CurveState         tfM3;
   CurveState         tfM5;
   CurveState         tfM15;
   CurveState         tfH1;
   CurveState         tfH4;

   //--- compression history (chart TF)
   CompressionTracker compress;

   //--- composite (the gCurve object)
   int                gDir;
   double             gForce;
   double             gCompression;
   double             gConvexity;
   double             gMaturity;
   ENUM_OMEGA_FORCE_STATE gForceState;
   string             gForceTrend;

   //--- bookkeeping
   string             symbol;
   ENUM_TIMEFRAMES    chartTf;
   bool               primed;
   long               updates;

                     OmegaCurve()
     {
      symbol = "";
      chartTf = PERIOD_CURRENT;
      gDir = 0; gForce = 0; gCompression = 0; gConvexity = 0; gMaturity = 0;
      gForceState = FORCE_NEUTRAL;
      gForceTrend = "STABLE";
      primed = false;
      updates = 0;
     }

   bool Init(string sym, ENUM_TIMEFRAMES chart_tf,
             int pivotLen = 5, int structLen = 10,
             double impulseMult = 1.5, double chochBufATR = 0.75,
             int atrLen = 14, int effLen = 10,
             double effThresh = 0.65, double dispThresh = 1.5, double convMult = 0.01)
     {
      symbol = sym;
      chartTf = chart_tf;
      bool ok = true;
      ok = ok && tfM1.Init (sym, PERIOD_M1,  pivotLen, structLen, impulseMult, chochBufATR, atrLen, effLen, effThresh, dispThresh, convMult);
      ok = ok && tfM3.Init (sym, PERIOD_M3,  pivotLen, structLen, impulseMult, chochBufATR, atrLen, effLen, effThresh, dispThresh, convMult);
      ok = ok && tfM5.Init (sym, PERIOD_M5,  pivotLen, structLen, impulseMult, chochBufATR, atrLen, effLen, effThresh, dispThresh, convMult);
      ok = ok && tfM15.Init(sym, PERIOD_M15, pivotLen, structLen, impulseMult, chochBufATR, atrLen, effLen, effThresh, dispThresh, convMult);
      ok = ok && tfH1.Init (sym, PERIOD_H1,  pivotLen, structLen, impulseMult, chochBufATR, atrLen, effLen, effThresh, dispThresh, convMult);
      ok = ok && tfH4.Init (sym, PERIOD_H4,  pivotLen, structLen, impulseMult, chochBufATR, atrLen, effLen, effThresh, dispThresh, convMult);
      compress.Reset();
      OmegaLogger::LogInfo("CURVE",
         StringFormat("Init %s · ladder=M1/M3/M5/M15/H1/H4 · ok=%s", sym, ok?"true":"false"));
      return ok;
     }

   void Deinit()
     {
      tfM1.Deinit();  tfM3.Deinit();  tfM5.Deinit();
      tfM15.Deinit(); tfH1.Deinit();  tfH4.Deinit();
     }

   //--- Pick the chart-TF state for the canonical compression / dir.
   CurveState* ChartTfState()
     {
      switch(chartTf)
        {
         case PERIOD_M1:  return GetPointer(tfM1);
         case PERIOD_M3:  return GetPointer(tfM3);
         case PERIOD_M5:  return GetPointer(tfM5);
         case PERIOD_M15: return GetPointer(tfM15);
         case PERIOD_H1:  return GetPointer(tfH1);
         case PERIOD_H4:  return GetPointer(tfH4);
        }
      //-- default to M5 if user is on an off-ladder TF
      return GetPointer(tfM5);
     }

   //--- Drive every TF to consume its latest closed bar.
   //    Returns true if at least one TF advanced this call.
   bool Update()
     {
      bool any = false;
      any = tfM1.Update()  || any;
      any = tfM3.Update()  || any;
      any = tfM5.Update()  || any;
      any = tfM15.Update() || any;
      any = tfH1.Update()  || any;
      any = tfH4.Update()  || any;
      if(!any) return false;

      CurveState *chart = ChartTfState();
      if(chart == NULL) return false;

      compress.Sample(chart);
      double tighten = compress.Tightening(5);

      gDir         = chart.DirByOrigin();
      gCompression = chart.compIdx;
      gConvexity   = ConvexityHelper::Score(chart);
      gMaturity    = ConvexityHelper::Maturity(chart);
      gForce       = ForceHelper::Score(gCompression, tighten, /*residual*/ 50.0, /*recursion*/ 0);
      gForceState  = ForceHelper::State(gForce);
      gForceTrend  = ForceHelper::TightenTrend(tighten);

      primed = chart.ready;
      updates += 1;
      return true;
     }

   //--- Fold curve outputs into the trinity's supporting fields.
   //    This is the contract Phase 1 set up — Phase 2 fulfils it for
   //    physics + structure. Phase 3 will overwrite ownershipStability
   //    / chainHealth / recursionDepth from the curve tree.
   void DeriveSupporting(OmegaSupporting &supp) const
     {
      supp.forceScore         = gForce;
      supp.compression        = gCompression;
      supp.convexity          = gConvexity;
      supp.ownershipStability = OMEGA_TRINITY_NEUTRAL; // Phase 3
      supp.chainHealth        = OMEGA_TRINITY_NEUTRAL; // Phase 3
      supp.recursionDepth     = 0;                    // Phase 3
      supp.recursionBudget    = 1;                    // Phase 3
      //-- alignment: how many of the 6 TFs share the chart's direction
      int sameDir = 0;
      if(gDir != 0)
        {
         if(tfM1.DirByOrigin()  == gDir) sameDir++;
         if(tfM3.DirByOrigin()  == gDir) sameDir++;
         if(tfM5.DirByOrigin()  == gDir) sameDir++;
         if(tfM15.DirByOrigin() == gDir) sameDir++;
         if(tfH1.DirByOrigin()  == gDir) sameDir++;
         if(tfH4.DirByOrigin()  == gDir) sameDir++;
        }
      supp.alignment    = (sameDir / 6.0) * 100.0;
      supp.narrative    = OMEGA_TRINITY_NEUTRAL; // Phase 4
      supp.regime       = OMEGA_TRINITY_NEUTRAL; // Phase 6
      supp.pContinuation= 0; supp.pTerminal = 0; supp.pTransfer = 0; // Phase 6
     }

   //--- short snapshot for heartbeat
   string Snapshot() const
     {
      return StringFormat(
         "dir=%d F=%.0f(%s/%s) C=%.0f X=%.0f mat=%.0f align=M1:%d M3:%d M5:%d M15:%d H1:%d H4:%d",
         gDir, gForce, ForceHelper::StateString(gForceState), gForceTrend,
         gCompression, gConvexity, gMaturity,
         tfM1.DirByOrigin(),  tfM3.DirByOrigin(),  tfM5.DirByOrigin(),
         tfM15.DirByOrigin(), tfH1.DirByOrigin(),  tfH4.DirByOrigin());
     }
  };

#endif // __OMEGA_CURVE_MQH__
