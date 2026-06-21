//+------------------------------------------------------------------+
//|                                                    Alignment.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 4 — Fractal Consciousness · cross-TF agreement.          |
//|                                                                  |
//|   Reads each timeframe's direction-by-origin from the multi-TF   |
//|   curve ladder and emits a coherent alignment score plus a       |
//|   plain-English Cross-TF story label that mirrors what the Pine  |
//|   indicator's MTF Curve Map shows.                               |
//+------------------------------------------------------------------+
#ifndef __OMEGA_NARRATIVE_ALIGNMENT_MQH__
#define __OMEGA_NARRATIVE_ALIGNMENT_MQH__

#include "../Curve/Curve.mqh"

class Alignment
  {
public:
   //--- count of TFs sharing the reference dir (0..6)
   static int CountAligned(const OmegaCurve &curve, int refDir)
     {
      if(refDir == 0) return 0;
      int n = 0;
      if(curve.tfM1.DirByOrigin()  == refDir) n++;
      if(curve.tfM3.DirByOrigin()  == refDir) n++;
      if(curve.tfM5.DirByOrigin()  == refDir) n++;
      if(curve.tfM15.DirByOrigin() == refDir) n++;
      if(curve.tfH1.DirByOrigin()  == refDir) n++;
      if(curve.tfH4.DirByOrigin()  == refDir) n++;
      return n;
     }

   //--- 0..100 — fractal stack agreement
   static double Score(int alignedCount) { return (alignedCount / 6.0) * 100.0; }

   //--- HTF agreement (H1 + H4)
   static int CountHTFAligned(const OmegaCurve &curve, int refDir)
     {
      if(refDir == 0) return 0;
      int n = 0;
      if(curve.tfH1.DirByOrigin() == refDir) n++;
      if(curve.tfH4.DirByOrigin() == refDir) n++;
      return n;
     }

   //--- Cross-TF story (mirrors the Pine MTF map labels)
   static string Story(int alignedCount, int refDir)
     {
      if(refDir == 0)            return "no dominant owner";
      if(alignedCount >= 5)      return "all TFs aligned → strong continuation";
      if(alignedCount == 4)      return "HTFs lead · LTFs following";
      if(alignedCount <= 2)      return "LTFs counter HTF → pullback / transition";
      return "mixed → rotation";
     }

   //--- Per-TF dir snapshot for explainability
   static string TfRow(const OmegaCurve &curve)
     {
      return StringFormat("M1:%d M3:%d M5:%d M15:%d H1:%d H4:%d",
                          curve.tfM1.DirByOrigin(),  curve.tfM3.DirByOrigin(),
                          curve.tfM5.DirByOrigin(),  curve.tfM15.DirByOrigin(),
                          curve.tfH1.DirByOrigin(),  curve.tfH4.DirByOrigin());
     }
  };

#endif // __OMEGA_NARRATIVE_ALIGNMENT_MQH__
