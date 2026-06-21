//+------------------------------------------------------------------+
//|                                                 CurvePhysics.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 0 → 4 — physics primitives.                              |
//|                                                                  |
//|   Direct MQL5 port of the Pine `f_phys` function: ATR, velocity, |
//|   acceleration, convexity, smoothed convexity, efficiency,       |
//|   displacement, plus the impulse / decay / convexity-shift /     |
//|   velocity-decay flags. Everything is computed on the LAST       |
//|   CLOSED bar (shift=1) for the symbol+timeframe instance owned   |
//|   by this object. New bar detection via iTime() change.          |
//|                                                                  |
//|   This is the smallest, fastest unit of perception. CurveState   |
//|   owns one CurvePhysics; the structure engine reads from it.     |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CURVE_PHYSICS_MQH__
#define __OMEGA_CURVE_PHYSICS_MQH__

#include "../Common.mqh"
#include "../Logger.mqh"

class CurvePhysics
  {
public:
   //--- inputs
   string             symbol;
   ENUM_TIMEFRAMES    tf;
   int                atrLen;
   int                effLen;
   double             effT;       // efficiency threshold
   double             dispT;      // displacement threshold
   double             convM;      // convexity multiplier (x atr)

   //--- last-closed-bar derived values
   double             atr;
   double             vel;        // ema(close-close[1], 3) at this bar
   double             velPrev;    // ema at previous bar
   double             acc;        // vel - velPrev
   double             accPrev;
   double             cvx;        // acc - accPrev
   double             csm;        // ema(cvx, 3)
   double             csmPrev;
   double             eff;        // efficiency 0..1
   double             disp;       // (high-low)/atr
   double             cth;        // atr * convM (convexity threshold)
   //--- flags
   bool               bullImpulse, bearImpulse;
   bool               bullDecay,   bearDecay;
   bool               bullConvShift, bearConvShift;
   bool               velDec70, velDec50;

   //--- bookkeeping
   datetime           lastBarTime;
   bool               ready;       // false until at least 2 bars processed
   long               barsProcessed;

private:
   int                m_handleATR;

public:
                     CurvePhysics()
     {
      symbol = "";
      tf = PERIOD_CURRENT;
      atrLen = 14; effLen = 10;
      effT = 0.65; dispT = 1.5; convM = 0.01;
      m_handleATR = INVALID_HANDLE;
      Reset();
     }

   void Reset()
     {
      atr = 0; vel = 0; velPrev = 0; acc = 0; accPrev = 0;
      cvx = 0; csm = 0; csmPrev = 0;
      eff = 0; disp = 0; cth = 0;
      bullImpulse = bearImpulse = false;
      bullDecay   = bearDecay   = false;
      bullConvShift = bearConvShift = false;
      velDec70 = velDec50 = false;
      lastBarTime = 0;
      ready = false;
      barsProcessed = 0;
     }

   bool Init(string sym, ENUM_TIMEFRAMES timeframe,
             int atrL = 14, int effL = 10,
             double effThresh = 0.65, double dispThresh = 1.5, double convMult = 0.01)
     {
      symbol = sym;
      tf = timeframe;
      atrLen = atrL; effLen = effL;
      effT = effThresh; dispT = dispThresh; convM = convMult;
      m_handleATR = iATR(symbol, tf, atrLen);
      if(m_handleATR == INVALID_HANDLE)
        {
         OmegaLogger::LogException("PHYSICS", GetLastError(),
            StringFormat("iATR failed sym=%s tf=%d", symbol, (int)tf));
         return false;
        }
      return true;
     }

   void Deinit()
     {
      if(m_handleATR != INVALID_HANDLE)
        {
         IndicatorRelease(m_handleATR);
         m_handleATR = INVALID_HANDLE;
        }
     }

   //--- Process the latest closed bar if it's new since last call.
   //    Returns true when a new bar was processed (caller may chain
   //    structure-engine updates only on those).
   bool Update()
     {
      datetime barT = iTime(symbol, tf, 1);
      if(barT == 0) return false;          // history not ready
      if(barT == lastBarTime) return false;  // no new closed bar

      //--- need at least effLen+2 bars of history
      int rates_total = Bars(symbol, tf);
      if(rates_total < effLen + 4) return false;

      //--- ATR
      double atrBuf[];
      if(CopyBuffer(m_handleATR, 0, 1, 1, atrBuf) <= 0) return false;
      double newAtr = atrBuf[0];
      if(newAtr <= 0) return false;

      //--- pull bar series
      double close1 = iClose(symbol, tf, 1);
      double close2 = iClose(symbol, tf, 2);
      double open1  = iOpen(symbol,  tf, 1);
      double high1  = iHigh(symbol,  tf, 1);
      double low1   = iLow(symbol,   tf, 1);
      if(close1 == 0 || close2 == 0) return false;

      //--- velocity = ema(diff, 3)
      double diff   = close1 - close2;
      double alphaV = 2.0 / (3.0 + 1.0);
      double newVelEma;
      if(barsProcessed == 0)
         newVelEma = diff;
      else
         newVelEma = alphaV * diff + (1.0 - alphaV) * vel;

      double newVelPrev = vel;
      double newVel     = newVelEma;
      double newAcc     = newVel - newVelPrev;
      double newAccPrev = acc;
      double newCvx     = newAcc - newAccPrev;

      //--- csm = ema(cvx, 3)
      double alphaC = 2.0 / (3.0 + 1.0);
      double newCsmPrev = csm;
      double newCsm;
      if(barsProcessed == 0)
         newCsm = newCvx;
      else
         newCsm = alphaC * newCvx + (1.0 - alphaC) * csm;

      //--- efficiency
      double newEff = 0.0;
      if(effLen > 1 && rates_total >= effLen + 2)
        {
         double mv = MathAbs(close1 - iClose(symbol, tf, 1 + effLen));
         double ps = 0.0;
         for(int i = 1; i <= effLen; i++)
            ps += MathAbs(iClose(symbol, tf, i) - iClose(symbol, tf, i + 1));
         newEff = (ps > 1e-10) ? (mv / ps) : 0.0;
        }

      double newDisp = (high1 - low1) / MathMax(newAtr, 1e-10);
      double newCth  = newAtr * convM;

      //--- commit
      atr      = newAtr;
      velPrev  = newVelPrev;
      vel      = newVel;
      accPrev  = newAccPrev;
      acc      = newAcc;
      cvx      = newCvx;
      csmPrev  = newCsmPrev;
      csm      = newCsm;
      eff      = newEff;
      disp     = newDisp;
      cth      = newCth;

      bullImpulse   = eff > effT && vel > velPrev && acc > 0 && close1 > open1 && disp > dispT;
      bearImpulse   = eff > effT && vel < velPrev && acc < 0 && close1 < open1 && disp > dispT;
      bullDecay     = MathAbs(acc) < MathAbs(accPrev) * 0.8 && vel > 0;
      bearDecay     = MathAbs(acc) < MathAbs(accPrev) * 0.8 && vel < 0;
      bullConvShift = csm >  cth && csmPrev <=  cth;
      bearConvShift = csm < -cth && csmPrev >= -cth;
      velDec70      = MathAbs(vel) < MathAbs(velPrev) * 0.7;
      velDec50      = MathAbs(vel) < MathAbs(velPrev) * 0.5;

      lastBarTime    = barT;
      barsProcessed += 1;
      ready          = (barsProcessed >= 2);
      return true;
     }
  };

#endif // __OMEGA_CURVE_PHYSICS_MQH__
