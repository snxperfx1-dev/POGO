//+------------------------------------------------------------------+
//|                                                   CurveState.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 0–7 — the f_se port. Single-timeframe structure engine.  |
//|   The SOLE lifecycle authority for one curve on one TF.          |
//|                                                                  |
//|   What it owns:                                                  |
//|     - confirmed pivot highs / lows (lookback pivot detection)    |
//|     - swing memory (curSH/curSL/prSH/prSL + lastP/prevP)          |
//|     - BOS / CHoCH detection                                      |
//|     - SPAWN engine: when a wave is BORN (impulse / flip)         |
//|     - wave context: dir, flip zone (ft/fb), point4, invalidation |
//|       target, cycle high/low                                     |
//|     - inducement state machine (bos1/bos2, indOrig/indExt/indBrk)|
//|     - convexity / expansion / absorption scores                  |
//|     - compression index (0..100, high = squeezed)                |
//|     - wave progress %                                            |
//|     - direction-by-origin (close vs invalidation)                |
//|                                                                  |
//|   Owns one CurvePhysics. Updates are driven on closed bars only. |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CURVE_STATE_MQH__
#define __OMEGA_CURVE_STATE_MQH__

#include "CurvePhysics.mqh"

class CurveState
  {
public:
   //--- physics
   CurvePhysics      physics;

   //--- structure inputs
   int               pivotLen;
   int               structLen;
   double            impMult;
   double            chBufATR;

   //--- swing memory
   double            curSH;
   double            curSL;
   double            prSH;
   double            prSL;
   double            lastPivotPrice;
   int               lastPivotDir;
   double            prevPivotPrice;
   int               prevPivotDir;

   //--- wave context (the structure engine's outputs)
   int               dir;          // -1, 0, +1
   double            ft;           // flip zone top
   double            fb;           // flip zone bot
   double            p4h;          // point 4 high
   double            p4l;          // point 4 low
   double            inv;          // invalidation
   double            tgt;          // wave target
   double            cycH;         // running cycle high
   double            cycL;         // running cycle low

   //--- per-bar event flags
   bool              bullBOS, bearBOS;
   bool              bullCH,  bearCH;
   bool              spawnedThisBar;
   bool              isReversal;

   //--- inducement
   bool              bos1, bos2;
   double            protSw, protSw2;
   double            indOrig, indExt;
   bool              indBrk;
   int               lastDirSeen;

   //--- composite scores (read by helpers)
   double            convScore;     // 0..100
   double            expScore;      // 0..100
   double            absScore;      // 0..100
   double            compIdx;       // 0..100 (compression)
   double            waveProgress;  // 0..100
   double            waveModelFit;  // 0..100

   //--- bookkeeping
   string            symbol;
   ENUM_TIMEFRAMES   tf;
   bool              ready;
   long              barsProcessed;
   datetime          lastBarTime;

                     CurveState()
     {
      pivotLen = 5;
      structLen = 10;
      impMult = 1.5;
      chBufATR = 0.75;
      Reset();
     }

   void Reset()
     {
      curSH = curSL = prSH = prSL = 0.0;
      lastPivotPrice = 0.0; lastPivotDir = 0;
      prevPivotPrice = 0.0; prevPivotDir = 0;
      dir = 0;
      ft = fb = p4h = p4l = inv = tgt = 0.0;
      cycH = cycL = 0.0;
      bullBOS = bearBOS = bullCH = bearCH = false;
      spawnedThisBar = false; isReversal = false;
      bos1 = bos2 = false; protSw = protSw2 = 0.0;
      indOrig = indExt = 0.0; indBrk = false;
      lastDirSeen = 0;
      convScore = expScore = absScore = 0.0;
      compIdx = waveProgress = waveModelFit = 0.0;
      ready = false;
      barsProcessed = 0;
      lastBarTime = 0;
     }

   bool Init(string sym, ENUM_TIMEFRAMES timeframe,
             int pvLen = 5, int stLen = 10,
             double impulseMult = 1.5, double chochBufATR = 0.75,
             int atrL = 14, int effL = 10,
             double effThresh = 0.65, double dispThresh = 1.5, double convMult = 0.01)
     {
      symbol    = sym;
      tf        = timeframe;
      pivotLen  = pvLen;
      structLen = stLen;
      impMult   = impulseMult;
      chBufATR  = chochBufATR;
      return physics.Init(sym, timeframe, atrL, effL, effThresh, dispThresh, convMult);
     }

   void Deinit() { physics.Deinit(); }

   //--- Detects whether the bar at `candidateShift` is a confirmed pivot
   //    high (highest within 2*pivotLen+1 window centred on it).
   bool DetectPivotHigh(double &outPrice)
     {
      int candidate = 1 + pivotLen;
      int total = Bars(symbol, tf);
      if(total < candidate + pivotLen + 1) return false;
      int hiShift = iHighest(symbol, tf, MODE_HIGH, 2 * pivotLen + 1, 1);
      if(hiShift != candidate) return false;
      outPrice = iHigh(symbol, tf, candidate);
      return outPrice > 0;
     }
   bool DetectPivotLow(double &outPrice)
     {
      int candidate = 1 + pivotLen;
      int total = Bars(symbol, tf);
      if(total < candidate + pivotLen + 1) return false;
      int loShift = iLowest(symbol, tf, MODE_LOW, 2 * pivotLen + 1, 1);
      if(loShift != candidate) return false;
      outPrice = iLow(symbol, tf, candidate);
      return outPrice > 0;
     }

   //--- Spawn a new wave context (called when impulse or flip detected).
   void Spawn(int newDir)
     {
      double hi = MathMax(lastPivotPrice, prevPivotPrice);
      double lo = MathMin(lastPivotPrice, prevPivotPrice);
      double obT = hi;
      double obB = lo;
      dir = newDir;
      ft  = obT;
      fb  = obB;
      p4h = obT;
      p4l = obB;
      double bar1Hi = iHigh(symbol, tf, 1);
      double bar1Lo = iLow(symbol, tf, 1);
      cycH = bar1Hi;
      cycL = bar1Lo;
      inv  = (newDir == 1) ? lo : hi;
      double rng = (prSH > 0 && prSL > 0) ? MathAbs(prSH - prSL) : physics.atr * 5.0;
      tgt = (newDir == 1) ? (obT + rng) : (obB - rng);
      spawnedThisBar = true;
      OmegaLogger::LogDebug("CURVE", StringFormat(
         "%s/%d · SPAWN dir=%d ft=%.5f fb=%.5f inv=%.5f tgt=%.5f",
         symbol, (int)tf, newDir, ft, fb, inv, tgt));
     }

   //--- Main per-bar update.
   bool Update()
     {
      spawnedThisBar = false;
      bullBOS = bearBOS = bullCH = bearCH = false;
      isReversal = false;

      //-- only advance the structure engine when physics advanced
      if(!physics.Update()) return false;

      double bar1Close = iClose(symbol, tf, 1);
      double bar1High  = iHigh(symbol, tf, 1);
      double bar1Low   = iLow(symbol, tf, 1);
      double atr       = physics.atr;
      if(atr <= 0) return false;

      //-- 1. PIVOT detection (confirmed pivots, lagged by pivotLen)
      double pH = 0.0, pL = 0.0;
      bool foundPH = DetectPivotHigh(pH);
      bool foundPL = DetectPivotLow(pL);
      if(foundPH)
        {
         prSH  = (curSH == 0.0) ? pH : curSH;
         curSH = pH;
        }
      if(foundPL)
        {
         prSL  = (curSL == 0.0) ? pL : curSL;
         curSL = pL;
        }

      //-- track last/prev pivot (for impulse / flip math)
      double eP = 0.0;
      int    eD = 0;
      if(foundPH)      { eP = pH; eD = 1; }
      else if(foundPL) { eP = pL; eD = -1; }
      if(eD != 0)
        {
         prevPivotPrice = lastPivotPrice;
         prevPivotDir   = lastPivotDir;
         lastPivotPrice = eP;
         lastPivotDir   = eD;
        }

      //-- 2. BOS / CHoCH against PREVIOUS swings
      if(prSH > 0)
        {
         if(bar1Close > prSH)                        bullBOS = true;
         if(bar1Close > prSH + atr * chBufATR)       bullCH  = true;
        }
      if(prSL > 0)
        {
         if(bar1Close < prSL)                        bearBOS = true;
         if(bar1Close < prSL - atr * chBufATR)       bearCH  = true;
        }

      //-- 3. impulse spawns
      bool eLong  = foundPH && prevPivotDir == -1 && (pH - prevPivotPrice) > atr * impMult;
      bool eShort = foundPL && prevPivotDir ==  1 && (prevPivotPrice - pL) > atr * impMult;
      bool flipUp = (dir == -1) && bullCH;
      bool flipDn = (dir ==  1) && bearCH;

      bool hasCtx = (dir != 0 && ft != 0.0);
      isReversal  = (eLong && dir == -1) || (eShort && dir == 1) || flipUp || flipDn;
      bool spawn  = (eLong || eShort || flipUp || flipDn) && (!hasCtx || isReversal);

      if(spawn)
        {
         int newDir = eLong ? 1 : eShort ? -1 : flipUp ? 1 : -1;
         Spawn(newDir);
        }

      //-- 4. extend cycle high / low while wave runs
      if(dir == 1 && !spawnedThisBar)  cycH = MathMax((cycH == 0.0) ? bar1High : cycH, bar1High);
      if(dir == -1 && !spawnedThisBar) cycL = MathMin((cycL == 0.0) ? bar1Low  : cycL, bar1Low);

      //-- 5. inducement state machine (reset on direction change)
      if(dir != lastDirSeen)
        {
         bos1 = false; bos2 = false;
         protSw = protSw2 = 0.0;
         indOrig = indExt = 0.0;
         indBrk = false;
         lastDirSeen = dir;
        }
      if(dir == 1 && foundPL)  { protSw2 = protSw; protSw = pL; }
      if(dir == -1 && foundPH) { protSw2 = protSw; protSw = pH; }

      bool oppBOS = false;
      if(dir == 1  && protSw > 0 && bar1Close < protSw) oppBOS = true;
      if(dir == -1 && protSw > 0 && bar1Close > protSw) oppBOS = true;

      if(!bos1 && oppBOS)
        {
         bos1 = true;
         indOrig = (dir == 1) ? cycH : cycL;
        }
      if(bos1 && !bos2 && oppBOS && protSw2 > 0 &&
         ((dir == 1 && bar1Close < protSw2) || (dir == -1 && bar1Close > protSw2)))
         bos2 = true;
      if(bos1 && dir == 1)
         indExt = (indExt == 0.0) ? bar1Close : MathMin(indExt, bar1Close);
      if(bos1 && dir == -1)
         indExt = (indExt == 0.0) ? bar1Close : MathMax(indExt, bar1Close);
      if(bos2 && indOrig > 0)
        {
         if(dir == 1  && bar1Close > indOrig) indBrk = true;
         if(dir == -1 && bar1Close < indOrig) indBrk = true;
        }

      //-- 6. composite scores
      convScore = MathMin(MathAbs(physics.csm) / MathMax(atr * physics.convM, 1e-10) * 50.0, 100.0);
      expScore  = MathMin(physics.eff / MathMax(physics.effT, 1e-10) * 50.0
                          + physics.disp / MathMax(physics.dispT, 1e-10) * 50.0, 100.0);
      absScore  = (physics.eff < physics.effT * 0.7
                   && MathAbs(physics.vel) < MathAbs(physics.velPrev) * 0.6)
                   ? (60.0 + convScore * 0.4) : (convScore * 0.3);
      //-- compression index: HIGH when displacement & efficiency are LOW
      double dN = MathMin(physics.disp / MathMax(physics.dispT, 1e-10), 1.0);
      double eN = MathMin(physics.eff  / MathMax(physics.effT,  1e-10), 1.0);
      compIdx = OmegaMath::Clamp((1.0 - dN) * 60.0 + (1.0 - eN) * 40.0, 0.0, 100.0);

      //-- 7. wave progress (geometry-anchored)
      if(p4h > 0 && p4l > 0 && ft > 0 && fb > 0)
        {
         double origin  = (dir == 1) ? p4l : p4h;
         double extreme = (dir == 1) ? ((cycH == 0.0) ? bar1High : cycH)
                                     : ((cycL == 0.0) ? bar1Low  : cycL);
         double fzMid   = (ft + fb) / 2.0;
         double totalMv = MathAbs(extreme - origin);
         double toFzMid = MathAbs(extreme - fzMid);
         double expProg = (totalMv > 1e-10) ? MathMin(MathAbs(bar1Close - origin) / totalMv * 60.0, 60.0) : 30.0;
         double retrMv  = MathAbs(bar1Close - extreme);
         double retrProg = (toFzMid > 1e-10) ? MathMin(retrMv / toFzMid * 40.0, 40.0) : 0.0;
         waveProgress = OmegaMath::Clamp(expProg + retrProg * MathMin(absScore / 40.0, 1.0), 0.0, 100.0);
        }
      else waveProgress = 30.0;

      //-- 8. model fit confidence — used by Phase 4 for stability
      double geomConsistency = 0.0;
      if(MathAbs((dir == 1 ? cycH : cycL) - inv) > atr * 2.0) geomConsistency += 30.0;
      if(MathAbs(ft - fb) < atr * 4.0)                        geomConsistency += 25.0;
      if(cycH > 0 || cycL > 0)                                geomConsistency += 20.0;
      if(dir != 0)                                            geomConsistency += 25.0;
      waveModelFit = OmegaMath::Clamp(geomConsistency, 0.0, 100.0);

      lastBarTime = physics.lastBarTime;
      barsProcessed += 1;
      ready = (barsProcessed >= structLen);
      return true;
     }

   //--- direction by origin (matches the displayed wave direction)
   int DirByOrigin() const
     {
      if(inv == 0.0) return dir;
      double bar1Close = iClose(symbol, tf, 1);
      if(bar1Close > inv) return 1;
      if(bar1Close < inv) return -1;
      return dir;
     }
  };

#endif // __OMEGA_CURVE_STATE_MQH__
