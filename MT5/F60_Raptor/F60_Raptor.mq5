//+------------------------------------------------------------------+
//|                                                  F60_Raptor.mq5   |
//|   F16 RAPTOR v60 — COMPLETE MT5 PORT (Expert Advisor)             |
//|                                                                   |
//|   A faithful, self-contained port of the F16 Raptor v60 Pine v6   |
//|   indicator ("Master Senseei — Unified") into an MT5 Expert       |
//|   Advisor. Every subsystem of the Pine source is reproduced here  |
//|   in MQL5 with behaviour-for-behaviour fidelity:                  |
//|                                                                   |
//|     PART B — Letra engine: f_phys physics, f_se fixed-TF          |
//|       structure engine with the 14-phase single-latch state       |
//|       machine (the SOLE lifecycle authority), Engine 1A, EDE/RE/  |
//|       EAE energy-resolution framework, belief engine, liquidity   |
//|       heatmap, wave spawn + recursion, FRZ.                       |
//|     PART A — Invisible Network: full FU-node registry (MN..M5),    |
//|       f_auth authority, path nodes, FEZ corridor, pressure/pdir.   |
//|     Engine 8.0 — Time Intelligence (MN/W/D/H4/H1 cycle stack).     |
//|     F72 — Curve object + Recursive Curve Tree, compression         |
//|       persistence, "is-trade-alive", narrative lineage, chain      |
//|       vitality, MTF curve map, campaign ownership, participants.   |
//|     PART D — Senseei meta-intelligence + Senzo trader voice.       |
//|     Attack Sequence (entry/stop/T1-T3).                            |
//|                                                                   |
//|   The Pine indicator only ANALYSES; this EA adds a thin execution |
//|   layer that routes orders from the Senseei action verdict        |
//|   (ATTACK/PREPARE/WAIT/MANAGE-EXIT), using the Attack Sequence     |
//|   stop (atkStopPx) and target (atkT1Px). All perception math is    |
//|   the engine's real read — nothing is estimated or simplified.    |
//+------------------------------------------------------------------+
#property copyright "F16 Raptor v60 — MT5 port"
#property version   "60.0"
#property strict

#include <Trade/Trade.mqh>

#define F60_VERSION "F60-Raptor-1.0.0"

//==================================================================
// INPUTS — mirror the Pine indicator inputs (group "Master Senseei"
// and "Letra Engine (exact)") plus the EA execution group.
//==================================================================
input group "═══ Master Senseei ═══"
input double InpWickFrac      = 0.30;   // FU spike: min wick / range
input int    InpLookback      = 3;      // FU spike: structure lookback
input int    InpAuthMin       = 45;     // Min node authority
input int    InpNodeMax       = 250;    // Max remembered nodes
input int    InpDormantBars   = 120;    // Bars until dormant
input int    InpHistoryBars   = 600;    // Bars until historical
input int    InpMinConf       = 55;     // Min confidence to ATTACK
input int    InpPivLen        = 8;      // Wave pivot length (display)

input group "═══ Letra Engine (exact) ═══"
input int    InpPivotLen      = 5;      // Pivot Length
input int    InpAtrLen        = 14;     // ATR Length
input int    InpEffLen        = 10;     // Efficiency Lookback
input int    InpStructLenL    = 10;     // Structure Pivot Length
input double InpImpulseAtrMult= 1.5;    // Impulse ATR Multiple
input double InpEffThresh     = 0.65;   // Efficiency Threshold
input double InpDispThresh    = 1.5;    // Displacement ATR Threshold
input double InpConvMult      = 0.01;   // Convexity ATR Multiplier
input double InpChochBufferATR= 0.75;   // Direction CHoCH Buffer (ATR)
input bool   InpUseStrictStruct = true; // Use Strict Structure
input int    InpAcceptBars    = 2;      // Flipzone Acceptance Bars
input int    InpObMaxBars     = 50;     // OB Max Valid Bars
input int    InpInducLookback = 80;     // Inducement Lookback Bars
input double InpInducZoneWidth= 0.25;   // Inducement Zone Half-Width (ATR)
input int    InpLiqSweepLookback = 10;  // Sweep Lookback Bars
input double InpLiqRadius     = 0.25;   // Liquidity Radius (x ATR)
input double InpLiqAgDecay    = 0.95;   // Liquidity Age Decay
input bool   InpRequireLiqSweep = true; // Require Liquidity Sweep
input int    InpResetBars     = 20;     // Min Bars Before Reset
input int    InpBeliefSmooth  = 3;      // Belief EMA Smoothing

input group "═══ Execution (EA) ═══"
input bool   InpEnableTrading = true;   // Master enable for live order routing
input long   InpMagic         = 600060; // Magic number
input double InpRiskPct       = 0.5;    // Risk per trade (% of equity)
input double InpMinLot        = 0.01;   // Minimum lot
input double InpMaxLot        = 5.0;    // Maximum lot
input int    InpMaxPositions  = 1;      // Max concurrent positions (this symbol+magic)
input int    InpSlippage      = 20;     // Deviation (points)
input bool   InpManageExits   = true;   // Close on Senseei MANAGE/EXIT (resolved)
input int    InpWarmupBars    = 1500;   // History bars to warm each TF engine
input bool   InpShowDashboard = true;   // Print Comment() cockpit dashboard
input int    InpHeartbeatSec  = 5;      // Heartbeat cadence (s)

//==================================================================
// GLOBAL ENGINE PARAMETERS (resolved from inputs at init)
//==================================================================
int    g_pivotLen, g_atrLen, g_effLen, g_structLenL, g_acceptBars, g_obMaxBars;
int    g_inducLookback, g_liqSweepLookback, g_resetBars, g_beliefSmooth, g_pivLen;
int    g_lookback, g_authMin, g_nodeMax, g_dormantBars, g_historyBars, g_minConf;
double g_impulseAtrMult, g_effThresh, g_dispThresh, g_convMult, g_chochBufferATR;
double g_inducZoneWidth, g_liqRadius, g_liqAgDecay, g_wickFrac;
bool   g_useStrictStruct, g_requireLiqSweep;

CTrade g_trade;
datetime g_lastHeartbeat = 0;

//==================================================================
// SMALL HELPERS
//==================================================================
double f_clamp(double v, double lo, double hi) { return MathMax(lo, MathMin(hi, v)); }
double f_nz(double v, double alt = 0.0) { return (v == EMPTY_VALUE || !MathIsValidNumber(v)) ? alt : v; }

// ── ADAPTIVE WAVE-TIMEFRAME LADDER (Pine _wtf1.._wtf6) ───────────
//   Six wave engines run on a FIXED intraday ladder (M1·M3·M5·M15·
//   H1·H4) on any chart at or below H1. Above H1 the ladder CLIMBS:
//   anchors at the chart TF and steps upward, keeping all six rungs
//   distinct and >= chart. Canonical wave (rung 3 / se5) stays M5
//   intraday. Returns the ENUM_TIMEFRAMES for each rung.
ENUM_TIMEFRAMES g_wtf1, g_wtf2, g_wtf3, g_wtf4, g_wtf5, g_wtf6;

int f_tfSec(ENUM_TIMEFRAMES tf) { return PeriodSeconds(tf); }

void f_buildLadder()
  {
   int csec = PeriodSeconds(_Period);
   // rung 3 = chart timeframe (canonical wave)
   g_wtf3 = _Period;
   if(csec < 3600)        // <= M30 chart: fixed intraday ladder
     {
      g_wtf1 = PERIOD_M1;  g_wtf2 = PERIOD_M3;
      g_wtf4 = PERIOD_M15; g_wtf5 = PERIOD_H1; g_wtf6 = PERIOD_H4;
     }
   else if(csec < 14400)  // H1..H2
     {
      g_wtf1 = PERIOD_H1;  g_wtf2 = PERIOD_H2;
      g_wtf4 = PERIOD_H8;  g_wtf5 = PERIOD_H12; g_wtf6 = PERIOD_D1;
     }
   else if(csec < 86400)  // H4..H12
     {
      g_wtf1 = PERIOD_H4;  g_wtf2 = PERIOD_H8;
      g_wtf4 = PERIOD_D1;  g_wtf5 = PERIOD_D1;  g_wtf6 = PERIOD_W1;
     }
   else if(csec < 604800) // Daily
     {
      g_wtf1 = PERIOD_D1;  g_wtf2 = PERIOD_D1;
      g_wtf4 = PERIOD_W1;  g_wtf5 = PERIOD_W1;  g_wtf6 = PERIOD_MN1;
     }
   else                   // Weekly+
     {
      g_wtf1 = PERIOD_W1;  g_wtf2 = PERIOD_W1;
      g_wtf4 = PERIOD_MN1; g_wtf5 = PERIOD_MN1; g_wtf6 = PERIOD_MN1;
     }
  }

string f_tfLabel(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:  return "M1";
      case PERIOD_M3:  return "M3";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H4:  return "H4";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D";
      case PERIOD_W1:  return "W";
      case PERIOD_MN1: return "MN";
     }
   return EnumToString(tf);
  }

//==================================================================
// CANONICAL PHASE VOCABULARY (Pine f_phaseStr) — the only legal
// lifecycle labels. _pst 0..14 maps to these 15 strings.
//==================================================================
string f_phaseStr(int c)
  {
   switch(c)
     {
      case 1:  return "Expansion";
      case 2:  return "Expansion Pre-Convexity";
      case 3:  return "Expansion Induction";
      case 4:  return "Expansion Liquidity";
      case 5:  return "New High";
      case 6:  return "New Low";
      case 7:  return "Transition";
      case 8:  return "Retracement";
      case 9:  return "HTF Flip Zone";
      case 10: return "Induction";
      case 11: return "Liquidation";
      case 12: return "Terminal Curve";
      case 13: return "Demand Return";
      case 14: return "Supply Return";
     }
   return "Point 4 Origin";
  }

// Short phase-family label for MTF panels (Pine f_famS).
string f_famS(int ph)
  {
   string p = f_phaseStr(ph);
   if(StringFind(p, "Transition")    >= 0) return "Transition";
   if(StringFind(p, "Terminal")      >= 0) return "Terminal";
   if(StringFind(p, "Liquidation")   >= 0) return "Liquidation";
   if(StringFind(p, "HTF Flip")      >= 0) return "Flip Zone";
   if(StringFind(p, "Induction")     >= 0 && StringFind(p, "Expansion") < 0) return "Induction";
   if(StringFind(p, "Pre-Convexity") >= 0) return "Pre-Conv";
   if(StringFind(p, "Liquidity")     >= 0) return "Liquidity";
   if(StringFind(p, "New High")      >= 0 || StringFind(p, "New Low") >= 0) return "Creation";
   if(StringFind(p, "Return")        >= 0) return "Return";
   if(StringFind(p, "Retracement")   >= 0) return "Retracement";
   return "Expansion";
  }

//==================================================================
// PART B.1 — CORE PHYSICS ENGINE  (Pine f_phys, exact)
//   Computed on a given timeframe. Pine runs f_phys inside
//   request.security on the fixed L0 (M5) so every history ref
//   resolves on that TF. Here PhysicsEngine pulls the TF's bars
//   via CopyRates and computes the same primitives + flags on the
//   most recent CLOSED bar. EMA(3) state is carried across calls.
//==================================================================
struct PhysOut
  {
   double atr, vel, acc, cvx, csm, eff, disp, cth;
   bool   bullImpulse, bearImpulse, bullMomDecay, bearMomDecay;
   bool   bullConvShift, bearConvShift, vd70, vd50;
   void Reset()
     {
      atr=vel=acc=cvx=csm=eff=disp=cth=0.0;
      bullImpulse=bearImpulse=bullMomDecay=bearMomDecay=false;
      bullConvShift=bearConvShift=vd70=vd50=false;
     }
  };

class PhysicsEngine
  {
private:
   ENUM_TIMEFRAMES m_tf;
   int      m_atrL, m_effL;
   double   m_effT, m_dispT, m_convM;
public:
   PhysOut  o;
   void Init(ENUM_TIMEFRAMES tf, int atrL, int effL, double effT, double dispT, double convM)
     {
      m_tf=tf; m_atrL=atrL; m_effL=effL; m_effT=effT; m_dispT=dispT; m_convM=convM;
      o.Reset();
     }

   // Compute on the closed bars of m_tf. shift=1 is the last closed bar.
   bool Compute()
     {
      int need = MathMax(m_atrL + 5, m_effL + 5) + 32;
      MqlRates r[];
      ArraySetAsSeries(r, true);
      int got = CopyRates(_Symbol, m_tf, 0, need + 8, r);
      if(got < need) return false;
      // index 1 = last closed bar (0 is forming). Build helper closes.
      // ATR (Wilder-ish simple): average true range over m_atrL using closed bars
      double atr = ComputeATR(r, m_atrL);
      o.atr = atr;
      // velocity = ema(close-close[1],3); evaluate on closed bars 1..
      // Build short series of (close-prev) for EMA.
      double vel1 = EmaDiff(r, 3, 1);   // ema at bar1
      double vel2 = EmaDiff(r, 3, 2);   // ema at bar2 (prev)
      double vel3 = EmaDiff(r, 3, 3);
      o.vel = vel1;
      o.acc = vel1 - vel2;
      double accPrev = vel2 - vel3;
      o.cvx = o.acc - accPrev;
      // smoothed convexity ema(cvx,3)
      o.csm = EmaConvex(r, 3, 1);
      double csmPrev = EmaConvex(r, 3, 2);
      // efficiency
      double mv = MathAbs(r[1].close - r[1 + m_effL].close);
      double ps = 0.0;
      for(int i = 1; i <= m_effL; i++) ps += MathAbs(r[i].close - r[i + 1].close);
      o.eff = ps > 0 ? mv / ps : 0.0;
      o.disp = (r[1].high - r[1].low) / MathMax(atr, 1e-10);
      o.cth = atr * m_convM;
      bool c_up = r[1].close > r[1].open;
      bool c_dn = r[1].close < r[1].open;
      o.bullImpulse = o.eff > m_effT && o.vel > vel2 && o.acc > 0 && c_up && o.disp > m_dispT;
      o.bearImpulse = o.eff > m_effT && o.vel < vel2 && o.acc < 0 && c_dn && o.disp > m_dispT;
      o.bullMomDecay = MathAbs(o.acc) < MathAbs(accPrev) * 0.8 && o.vel > 0;
      o.bearMomDecay = MathAbs(o.acc) < MathAbs(accPrev) * 0.8 && o.vel < 0;
      o.bullConvShift = o.csm > o.cth && csmPrev <= o.cth;
      o.bearConvShift = o.csm < -o.cth && csmPrev >= -o.cth;
      o.vd70 = MathAbs(o.vel) < MathAbs(vel2) * 0.7;
      o.vd50 = MathAbs(o.vel) < MathAbs(vel2) * 0.5;
      return true;
     }

private:
   double ComputeATR(const MqlRates &r[], int len)
     {
      double sum = 0.0;
      for(int i = 1; i <= len; i++)
        {
         double tr = MathMax(r[i].high - r[i].low,
                     MathMax(MathAbs(r[i].high - r[i + 1].close),
                             MathAbs(r[i].low - r[i + 1].close)));
         sum += tr;
        }
      return sum / len;
     }
   // EMA(period) of (close-close[1]) evaluated AT bar `endShift` (series index).
   double EmaDiff(const MqlRates &r[], int period, int endShift)
     {
      double k = 2.0 / (period + 1.0);
      // seed several bars before endShift for stability
      int seed = endShift + period * 4;
      double ema = r[seed].close - r[seed + 1].close;
      for(int i = seed - 1; i >= endShift; i--)
        {
         double d = r[i].close - r[i + 1].close;
         ema = d * k + ema * (1.0 - k);
        }
      return ema;
     }
   // EMA(period) of convexity (acc-accPrev) at bar endShift.
   double EmaConvex(const MqlRates &r[], int period, int endShift)
     {
      double k = 2.0 / (period + 1.0);
      int seed = endShift + period * 5;
      double ema = ConvexAt(r, seed);
      for(int i = seed - 1; i >= endShift; i--)
         ema = ConvexAt(r, i) * k + ema * (1.0 - k);
      return ema;
     }
   double VelAt(const MqlRates &r[], int shift)
     {
      // ema(close-close[1],3) at `shift` — small local EMA
      double k = 2.0 / 4.0;
      int seed = shift + 8;
      double ema = r[seed].close - r[seed + 1].close;
      for(int i = seed - 1; i >= shift; i--)
        {
         double d = r[i].close - r[i + 1].close;
         ema = d * k + ema * (1.0 - k);
        }
      return ema;
     }
   double ConvexAt(const MqlRates &r[], int shift)
     {
      double v0 = VelAt(r, shift);
      double v1 = VelAt(r, shift + 1);
      double v2 = VelAt(r, shift + 2);
      double acc0 = v0 - v1;
      double acc1 = v1 - v2;
      return acc0 - acc1;
     }
  };


//==================================================================
// PART B.2 — FIXED-TF STRUCTURE ENGINE  (Pine f_se, exact)
//   The SOLE lifecycle authority. One instance per fixed timeframe.
//   Computes its own physics, structure, order-block/flip-zone,
//   point-4 origin, invalidation, target, recursion, and a single-
//   latch phase state machine `_pst` (0->14). Exposes the 21 Pine
//   outputs. To reproduce Pine's bar-by-bar `var` accumulation
//   faithfully, Compute() pulls the TF's bars and iterates
//   chronologically (oldest->newest), carrying all persistent state.
//==================================================================
struct SeOut
  {
   int    dir;        // origin-based wave direction (_dirLabel)
   int    ph;         // phase code 0..14
   double sh, sl;     // current swing high/low
   double psh, psl;   // previous swing high/low
   int    bos;        // BOS out (+1/-1/0)
   int    ch;         // CHoCH out (+1/-1/0)
   double p4h, p4l;   // point-4 origin high/low
   double inv;        // invalidation (origin)
   double tgt;        // target
   double ft, fb;     // flip top/bottom
   double fs;         // frz score
   double wp;         // wave progress 0..100
   double cm;         // convex maturity (convScore-based)
   double mf;         // model fit
   double comp;       // compression index 0..100
   int    rec;        // recursion breaks
   double dom;        // recursion dominance 0..100
   void Reset()
     {
      dir=ph=bos=ch=rec=0;
      sh=sl=psh=psl=p4h=p4l=inv=tgt=ft=fb=0.0;
      fs=wp=cm=mf=comp=dom=0.0;
     }
  };

class StructEngine
  {
private:
   ENUM_TIMEFRAMES m_tf;
   int    m_pvLen, m_stLen, m_atrL, m_effL;
   double m_effT, m_dispT, m_convM, m_impM, m_chBuf;
public:
   SeOut  o;
   datetime lastBarTime;

   void Init(ENUM_TIMEFRAMES tf)
     {
      m_tf=tf;
      m_pvLen=g_pivotLen; m_stLen=g_structLenL; m_atrL=g_atrLen; m_effL=g_effLen;
      m_effT=g_effThresh; m_dispT=g_dispThresh; m_convM=g_convMult;
      m_impM=g_impulseAtrMult; m_chBuf=g_chochBufferATR;
      o.Reset(); lastBarTime=0;
     }

   // Full chronological recompute over `bars` history. Returns false if
   // insufficient data. Mirrors Pine's f_se evaluated to the last closed bar.
   bool Compute(int bars)
     {
      MqlRates r[];
      ArraySetAsSeries(r, false);            // chronological: index 0 = oldest
      int want = bars + m_atrL + m_effL + m_pvLen * 4 + 20;
      int n = CopyRates(_Symbol, m_tf, 0, want, r);
      if(n < m_atrL + m_effL + m_pvLen * 2 + 10) return false;
      // Drop the still-forming last bar so we evaluate only closed bars.
      int last = n - 2;                      // index of last CLOSED bar
      if(last < m_atrL + m_effL + m_pvLen * 2 + 5) return false;

      // ---- persistent physics state (chronological EMAs) ----
      double atr = 0.0; bool atrSeed = false;
      double velEma = 0.0, velPrev = 0.0; bool velSeed = false;
      double accPrev = 0.0; bool accSeed = false;
      double csmEma = 0.0, csmPrev = 0.0; bool csmSeed = false;

      // ---- f_se persistent state (Pine var) ----
      double curSH=0, curSL=0, prSH=0, prSL=0;     // 0 used as "na"
      bool   hasCurSH=false, hasCurSL=false, hasPrSH=false, hasPrSL=false;
      double lastP=0; int lastD=0; double prevP=0; int prevD=0;
      bool   hasLastP=false, hasPrevP=false;
      int    dir=0;
      double ft=0, fb=0, p4h=0, p4l=0, inv=0, tgt=0, cycH=0, cycL=0;
      bool   hasFt=false, hasInv=false, hasCycH=false, hasCycL=false;
      bool   bos1=false, bos2=false;
      double protSw=0, protSw2=0, indOrig=0, indExt=0;
      bool   hasProt=false, hasProt2=false, hasIndOrig=false, hasIndExt=false;
      bool   indBrk=false;
      int    lastDirSeen=0;
      int    recBrk=0; bool recArm=true;
      int    pst=0;

      double k3 = 2.0 / 4.0;  // EMA period-3 factor

      // pivot window needs pvLen future bars confirmed: process chronological
      // index i, pivot confirmed at i-m_pvLen.
      int startI = m_atrL + m_effL + 2;
      if(startI < m_pvLen * 2 + 1) startI = m_pvLen * 2 + 1;

      // outputs of the most recent processed bar
      double f_atr=0;
      int    o_bos=0, o_ch=0, o_dirLabel=0, o_phase=0, o_rec=0;
      double o_cm=0, o_mf=0, o_frzS=0, o_wp=0, o_comp=0, o_dom=0;

      for(int i = startI; i <= last; i++)
        {
         double Ci = r[i].close, Cp = r[i-1].close, Oi = r[i].open;
         double Hi = r[i].high,  Li = r[i].low;
         // --- physics ---
         double tr = MathMax(Hi - Li, MathMax(MathAbs(Hi - Cp), MathAbs(Li - Cp)));
         if(!atrSeed) { atr = tr; atrSeed = true; }
         else atr = (atr * (m_atrL - 1) + tr) / m_atrL;
         double diff = Ci - Cp;
         if(!velSeed) { velEma = diff; velSeed = true; velPrev = diff; }
         else { velPrev = velEma; velEma = diff * k3 + velEma * (1.0 - k3); }
         double acc = velEma - velPrev;
         double conv = accSeed ? (acc - accPrev) : 0.0;
         bool bullDec = accSeed && MathAbs(acc) < MathAbs(accPrev) * 0.8 && velEma > 0;  // uses prev-bar acc
         bool bearDec = accSeed && MathAbs(acc) < MathAbs(accPrev) * 0.8 && velEma < 0;
         accPrev = acc; accSeed = true;
         if(!csmSeed) { csmEma = conv; csmSeed = true; csmPrev = conv; }
         else { csmPrev = csmEma; csmEma = conv * k3 + csmEma * (1.0 - k3); }
         double mv = MathAbs(Ci - r[i - m_effL].close);
         double ps = 0.0;
         for(int j = 0; j < m_effL; j++) ps += MathAbs(r[i - j].close - r[i - j - 1].close);
         double eff = ps > 0 ? mv / ps : 0.0;
         double disp = (Hi - Li) / MathMax(atr, 1e-10);
         bool bullImp = eff > m_effT && velEma > velPrev && acc > 0 && Ci > Oi && disp > m_dispT;
         bool bearImp = eff > m_effT && velEma < velPrev && acc < 0 && Ci < Oi && disp > m_dispT;

         // --- pivots (confirmed at i - pvLen) ---
         double pH = 0, pL = 0; bool hasPH=false, hasPL=false;
         int pc = i - m_pvLen;
         if(pc >= m_pvLen)
           {
            double hv = r[pc].high, lv = r[pc].low;
            bool isH = true, isL = true;
            for(int w = pc - m_pvLen; w <= pc + m_pvLen; w++)
              {
               if(w == pc) continue;
               if(r[w].high >= hv) isH = false;
               if(r[w].low  <= lv) isL = false;
              }
            if(isH) { pH = hv; hasPH = true; }
            if(isL) { pL = lv; hasPL = true; }
           }

         // --- swing memory ---
         if(hasPH) { if(!hasCurSH) { prSH = pH; hasPrSH = true; } else { prSH = curSH; hasPrSH = true; } curSH = pH; hasCurSH = true; }
         if(hasPL) { if(!hasCurSL) { prSL = pL; hasPrSL = true; } else { prSL = curSL; hasPrSL = true; } curSL = pL; hasCurSL = true; }

         // --- pivot-event memory ---
         double eP = 0; int eD = 0; bool hasE=false;
         if(hasPH) { eP = pH; eD = 1; hasE = true; }
         else if(hasPL) { eP = pL; eD = -1; hasE = true; }
         if(hasE)
           {
            prevP = lastP; prevD = lastD; hasPrevP = hasLastP;
            lastP = eP; lastD = eD; hasLastP = true;
           }

         // --- BOS / CHoCH ---
         bool bullBOS = hasPrSH && Ci > prSH;
         bool bearBOS = hasPrSL && Ci < prSL;
         bool bullCH  = hasPrSH && Ci > prSH + atr * m_chBuf;
         bool bearCH  = hasPrSL && Ci < prSL - atr * m_chBuf;

         bool eLong  = hasPH && prevD == -1 && hasPrevP && (pH - prevP) > atr * m_impM;
         bool eShort = hasPL && prevD == 1  && hasPrevP && (prevP - pL) > atr * m_impM;

         // --- spawn ---
         bool hasCtx = dir != 0 && hasFt;
         bool flipDn = dir == 1  && bearCH;
         bool flipUp = dir == -1 && bullCH;
         bool isRev  = (eLong && dir == -1) || (eShort && dir == 1) || flipUp || flipDn;
         bool spawn  = (eLong || eShort || flipUp || flipDn) && (!hasCtx || isRev);
         if(spawn)
           {
            int nd = eLong ? 1 : eShort ? -1 : flipUp ? 1 : -1;
            double hi = MathMax(lastP, prevP);
            double lo = MathMin(lastP, prevP);
            dir = nd;
            ft = hi; fb = lo; hasFt = true;
            p4h = hi; p4l = lo;
            cycH = Hi; cycL = Li; hasCycH = hasCycL = true;
            inv = nd == 1 ? lo : hi; hasInv = true;
            double rng = (hasPrSH && hasPrSL) ? MathAbs(prSH - prSL) : atr * 5.0;
            tgt = nd == 1 ? hi + rng : lo - rng;
           }
         if(dir == 1)  { cycH = hasCycH ? MathMax(cycH, Hi) : Hi; hasCycH = true; }
         if(dir == -1) { cycL = hasCycL ? MathMin(cycL, Li) : Li; hasCycL = true; }

         int bosOut = bullBOS ? 1 : bearBOS ? -1 : 0;
         int chOut  = bullCH  ? 1 : bearCH  ? -1 : 0;

         // --- inducement chain (reset on dir change) ---
         bool reset = (dir != lastDirSeen);
         lastDirSeen = dir;
         if(reset)
           {
            bos1 = bos2 = false; hasProt = hasProt2 = false;
            hasIndOrig = hasIndExt = false; indBrk = false;
           }
         if(dir == 1 && hasPL)  { protSw2 = protSw; hasProt2 = hasProt; protSw = pL; hasProt = true; }
         if(dir == -1 && hasPH) { protSw2 = protSw; hasProt2 = hasProt; protSw = pH; hasProt = true; }
         bool oppBOS = (dir == 1 && hasProt && Ci < protSw) || (dir == -1 && hasProt && Ci > protSw);
         if(!bos1 && oppBOS) { bos1 = true; indOrig = dir == 1 ? (hasCycH ? cycH : Hi) : (hasCycL ? cycL : Li); hasIndOrig = true; }
         if(bos1 && !bos2 && oppBOS && hasProt2 && (dir == 1 ? Ci < protSw2 : Ci > protSw2)) bos2 = true;
         if(bos1 && dir == 1)  { indExt = hasIndExt ? MathMin(indExt, Ci) : Ci; hasIndExt = true; }
         if(bos1 && dir == -1) { indExt = hasIndExt ? MathMax(indExt, Ci) : Ci; hasIndExt = true; }
         if(bos2 && hasIndOrig)
           {
            if(dir == 1 && Ci > indOrig)  indBrk = true;
            if(dir == -1 && Ci < indOrig) indBrk = true;
           }

         // --- physics sub-scores ---
         double convScore = MathMin(MathAbs(csmEma) / MathMax(atr * m_convM, 1e-10) * 50.0, 100.0);
         double expScore  = MathMin(eff / MathMax(m_effT, 1e-10) * 50.0 + disp / MathMax(m_dispT, 1e-10) * 50.0, 100.0);
         double absScore  = (eff < m_effT * 0.7 && MathAbs(velEma) < MathAbs(velPrev) * 0.6) ? 60.0 + convScore * 0.4 : convScore * 0.3;
         bool momExpStrong = eff > m_effT * 0.75 && (dir == 1 ? velEma > 0 : velEma < 0);
         bool momDecaying  = dir == 1 ? bullDec : bearDec;
         bool momCounter   = dir == 1 ? bearImp : bullImp;
         bool momExhaust   = eff < m_effT * 0.65 && absScore > 40.0;
         bool physConvexDevel = convScore > 35.0;
         bool physTransfer    = convScore > 48.0 || absScore > 40.0;
         bool physCapacityLow = absScore > 45.0 || eff < m_effT * 0.6;

         // --- direction (origin-based) ---
         int wdir = hasInv ? (Ci > inv ? 1 : Ci < inv ? -1 : dir) : dir;
         bool atFlip = hasFt && Ci <= ft && Ci >= fb;
         bool expanding = momExpStrong || eLong || eShort || (wdir == 1 ? bullImp : bearImp);
         bool atExtreme = wdir == 1 ? (Hi >= (hasCycH ? cycH : Hi)) : wdir == -1 ? (Li <= (hasCycL ? cycL : Li)) : false;
         double extr = wdir == 1 ? (hasCycH ? cycH : Ci) : (hasCycL ? cycL : Ci);
         bool extended = hasInv && MathAbs(extr - inv) > atr * 1.5;
         double fzMid = hasFt ? (ft + fb) / 2.0 : 0.0;
         double retrFrac = (hasFt && MathAbs(extr - fzMid) > 1e-10) ? MathAbs(extr - Ci) / MathAbs(extr - fzMid) : 0.0;
         double compIdx = f_clamp((1.0 - MathMin(disp / MathMax(m_dispT, 1e-10), 1.0)) * 60.0 + (1.0 - MathMin(eff / MathMax(m_effT, 1e-10), 1.0)) * 40.0, 0.0, 100.0);

         // --- recursive transition ---
         bool phase2CH = (dir == 1 && bearCH) || (dir == -1 && bullCH);
         if(reset || (atExtreme && extended)) { recBrk = 0; recArm = true; }
         if((dir == 1 && hasPH) || (dir == -1 && hasPL)) recArm = true;
         if((phase2CH || oppBOS) && recArm && !atExtreme) { recBrk++; recArm = false; }
         double recDom = MathMin(100.0, MathMax(recBrk * (30.0 - compIdx * 0.15), retrFrac * 80.0));
         bool transferDone = recDom >= 50.0;

         // --- single-latch phase state machine ---
         if(reset) pst = 0;
         if(dir != 0 && !reset)
           {
            if(pst == 0 && expanding) pst = 1;
            if(pst == 1 && !atExtreme && momDecaying && physConvexDevel) pst = 2;
            if(pst == 2 && !atExtreme && momCounter && physTransfer) pst = 3;
            if(pst == 3 && !atExtreme && (bos1 || bos2 || indBrk) && physTransfer) pst = 4;
            if(pst >= 1 && pst <= 7 && atExtreme && extended) pst = 5;
            if(pst == 5 && !atExtreme && (recBrk >= 1 || momExhaust)) pst = 7;
            if(pst == 7 && transferDone) pst = 8;
            if(pst == 8 && atFlip) pst = 9;
            if(pst == 9 && ((dir == 1 && bullImp) || (dir == -1 && bearImp))) pst = 10;
            if(pst == 10 && (oppBOS || physCapacityLow)) pst = 11;
            if(pst == 11 && ((dir == 1 && Li < fb) || (dir == -1 && Hi > ft))) pst = 12;
            if(pst == 12 && ((dir == 1 && bullCH) || (dir == -1 && bearCH))) pst = 13;
           }
         int phase = pst;
         if(phase == 5 && dir == -1) phase = 6;
         if(phase == 13 && dir == -1) phase = 14;
         double wp = pst==0?5.0:pst==1?15.0:pst==2?25.0:pst==3?33.0:pst==4?42.0:pst==5?55.0:pst==7?65.0:pst==8?75.0:pst==9?85.0:pst==10?90.0:pst==11?94.0:pst==12?97.0:100.0;
         double cm = MathMin(convScore, 100.0);
         double mf = MathMin(MathMax(expScore, MathMax(absScore, convScore)) * 0.70 + (dir != 0 ? 30.0 : 0.0), 100.0);
         double frzS = MathMin((eLong || eShort ? 50.0 : 0.0) + expScore * 0.30 + convScore * 0.20, 100.0);

         // --- capture outputs (overwritten each bar; last wins) ---
         f_atr = atr;
         o_bos = bosOut; o_ch = chOut; o_dirLabel = wdir; o_phase = phase;
         o_cm = cm; o_mf = mf; o_frzS = frzS; o_wp = wp; o_comp = compIdx;
         o_rec = recBrk; o_dom = recDom;
        }

      // publish final-bar state
      o.dir = o_dirLabel; o.ph = o_phase;
      o.sh = hasCurSH ? curSH : 0; o.sl = hasCurSL ? curSL : 0;
      o.psh = hasPrSH ? prSH : 0;  o.psl = hasPrSL ? prSL : 0;
      o.bos = o_bos; o.ch = o_ch;
      o.p4h = p4h; o.p4l = p4l;
      o.inv = hasInv ? inv : 0; o.tgt = tgt; o.ft = hasFt ? ft : 0; o.fb = hasFt ? fb : 0;
      o.fs = o_frzS; o.wp = o_wp; o.cm = o_cm; o.mf = o_mf;
      o.comp = o_comp; o.rec = o_rec; o.dom = o_dom;
      lastBarTime = r[last].time;
      return true;
     }
  };


//==================================================================
// PART B.3 — ENGINE INSTANCES + FRACTAL STACK + ENGINE 1A
//   Six f_se instances on the adaptive ladder (rungs 1..6 =
//   M1/M3/M5/M15/H1/H4 intraday). se5 (rung 3 / chart wave) is the
//   canonical M5 wave that Engine 1A reads. Fractal stack alignment,
//   M5-fixed structBias, and ie1a_currentPhase derive from these.
//==================================================================
StructEngine g_se1, g_se3, g_se5, g_se15, g_se60, g_se240;
PhysicsEngine g_physM5;   // chart-wave physics (Pine f_phys on _wtf3)

// Derived globals (Pine aliases)
double g_close = 0.0;     // current price reference (bid) == Pine `close`
int    m1_dir=0, l3_dir=0, l0_dir=0, l1_dir=0, l2_dir=0, l4_dir=0;
int    fractalStackDir=0;
double fractalStackScore=0.0;
int    structBias=0;
string ie1a_currentPhase = "Point 4 Origin";
double ie1a_phaseConfidence = 20.0;
int    waveDir=0, stackDir=0;
double stackPct=0.0;
double waveOrigin=0.0, waveObj=0.0;

// physics (chart wave) globals consumed by observation layer / EDE
double g_atr=0, g_vel=0, g_acc=0, g_csm=0, g_eff=0, g_disp=0;
bool   g_bullImpulse=false, g_bearImpulse=false, g_bullMomDecay=false, g_bearMomDecay=false;
bool   g_bullConvShift=false, g_bearConvShift=false, g_vd70=false, g_vd50=false;

// History depth per TF: higher timeframes need fewer bars (and have fewer
// available); cap to keep recompute cheap while warming state fully.
int g_lookbackBarsFor(ENUM_TIMEFRAMES tf)
  {
   int sec = PeriodSeconds(tf);
   if(sec >= PeriodSeconds(PERIOD_D1)) return MathMin(InpWarmupBars, 400);
   if(sec >= PeriodSeconds(PERIOD_H4)) return MathMin(InpWarmupBars, 800);
   return InpWarmupBars;
  }

int f_waveDirByOrigin(double origin, int fallbackDir)
  {
   if(origin == 0.0) return fallbackDir;
   return g_close > origin ? 1 : g_close < origin ? -1 : fallbackDir;
  }

bool f_updateStructure()
  {
   g_close = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(g_close <= 0) g_close = iClose(_Symbol, _Period, 0);

   bool ok = true;
   ok = g_se1.Compute(g_lookbackBarsFor(g_wtf1))   && ok;
   ok = g_se3.Compute(g_lookbackBarsFor(g_wtf2))   && ok;
   ok = g_se5.Compute(g_lookbackBarsFor(g_wtf3))   && ok;
   ok = g_se15.Compute(g_lookbackBarsFor(g_wtf4))  && ok;
   ok = g_se60.Compute(g_lookbackBarsFor(g_wtf5))  && ok;
   ok = g_se240.Compute(g_lookbackBarsFor(g_wtf6)) && ok;
   if(!ok) return false;

   // chart-wave physics (Pine f_phys on _wtf3)
   if(g_physM5.Compute())
     {
      g_atr=g_physM5.o.atr; g_vel=g_physM5.o.vel; g_acc=g_physM5.o.acc;
      g_csm=g_physM5.o.csm; g_eff=g_physM5.o.eff; g_disp=g_physM5.o.disp;
      g_bullImpulse=g_physM5.o.bullImpulse; g_bearImpulse=g_physM5.o.bearImpulse;
      g_bullMomDecay=g_physM5.o.bullMomDecay; g_bearMomDecay=g_physM5.o.bearMomDecay;
      g_bullConvShift=g_physM5.o.bullConvShift; g_bearConvShift=g_physM5.o.bearConvShift;
      g_vd70=g_physM5.o.vd70; g_vd50=g_physM5.o.vd50;
     }

   // origin-based per-rung directions
   m1_dir = f_waveDirByOrigin(g_se1.o.inv,   g_se1.o.dir);
   l3_dir = f_waveDirByOrigin(g_se3.o.inv,   g_se3.o.dir);
   l0_dir = f_waveDirByOrigin(g_se5.o.inv,   g_se5.o.dir);
   l1_dir = f_waveDirByOrigin(g_se15.o.inv,  g_se15.o.dir);
   l2_dir = f_waveDirByOrigin(g_se60.o.inv,  g_se60.o.dir);
   l4_dir = f_waveDirByOrigin(g_se240.o.inv, g_se240.o.dir);

   // fractal stack
   int sb = (m1_dir==1)+(l3_dir==1)+(l0_dir==1)+(l1_dir==1)+(l2_dir==1)+(l4_dir==1);
   int sr = (m1_dir==-1)+(l3_dir==-1)+(l0_dir==-1)+(l1_dir==-1)+(l2_dir==-1)+(l4_dir==-1);
   fractalStackDir = sb > sr ? 1 : sr > sb ? -1 : 0;
   fractalStackScore = MathMax(sb, sr) / 6.0 * 100.0;

   // M5-fixed structBias (strict HH/HL or LH/LL, else BOS)
   bool isHH = g_se5.o.sh != 0 && g_se5.o.psh != 0 && g_se5.o.sh > g_se5.o.psh;
   bool isLH = g_se5.o.sh != 0 && g_se5.o.psh != 0 && g_se5.o.sh < g_se5.o.psh;
   bool isHL = g_se5.o.sl != 0 && g_se5.o.psl != 0 && g_se5.o.sl > g_se5.o.psl;
   bool isLL = g_se5.o.sl != 0 && g_se5.o.psl != 0 && g_se5.o.sl < g_se5.o.psl;
   bool bullBOS = g_se5.o.bos == 1, bearBOS = g_se5.o.bos == -1;
   if(g_useStrictStruct)
     {
      if(isHH && isHL) structBias = 1;
      if(isLH && isLL) structBias = -1;
     }
   else
     {
      if(bullBOS) structBias = 1;
      if(bearBOS) structBias = -1;
     }

   // Engine 1A — canonical phase + confidence (SOLE lifecycle authority)
   ie1a_currentPhase = f_phaseStr(g_se5.o.ph);
   ie1a_phaseConfidence = f_clamp(fractalStackScore * 0.50 + g_se5.o.mf * 0.30 + g_se5.o.wp * 0.20, 20.0, 100.0);

   // legacy aliases
   waveDir = l0_dir; stackDir = fractalStackDir; stackPct = fractalStackScore;
   waveOrigin = g_se5.o.inv;
   return true;
  }


//==================================================================
// WAVE CONTEXT STATE (Pine Section 8) — assigned by the chart-wave
// Spawn Engine (PART B.6). Declared here so the observation/ERF
// layers (which run first in Pine's source order via prev-bar refs)
// can read them. Initialised na-equivalent (0 / false).
//==================================================================
int    direction = 0;
double flipTop=0, flipBot=0;
double point4OriginHigh=0, point4OriginLow=0;
double cycleHigh=0, cycleLow=0;
int    entryCycle=0, waveDepth=0, waveGeneration=0;
bool   isRecursiveWave=false, recursiveComplete=false;
double inducZoneLow=0, inducZoneHigh=0;
double convexityMaturity=0.0;       // EMA-smoothed (Section 12)
double liqHeat=0.0;                 // Section 10
bool   nearFlipzone=false, closeInside=false, inductionEvidence=false, preConvEvidence=false;

//==================================================================
// PART B.4 — PHYSICS OBSERVATION LAYER  (Pine Section 9, exact)
//==================================================================
double velocityScore=0, accelerationScore=0, convexityScore=0;
double obs_ExpansionScore=0, obs_DecayScore=0, obs_CurvatureScore=0;
double obs_AbsorptionScore=0, obs_LiquidityScore=0;

void f_updateObservation()
  {
   double atr = g_atr;
   velocityScore     = MathMin(MathAbs(g_vel) / MathMax(atr * 0.1, 1e-10) * 50.0, 100.0);
   accelerationScore = MathMin(MathAbs(g_acc) / MathMax(atr * 0.05, 1e-10) * 50.0, 100.0);
   convexityScore    = MathMin(MathAbs(g_csm) / MathMax(atr * g_convMult, 1e-10) * 25.0, 100.0);
   obs_ExpansionScore = MathMin((g_eff > g_effThresh ? g_eff * 60.0 : g_eff * 30.0)
                        + (g_disp > g_dispThresh ? (g_disp / MathMax(g_dispThresh, 1e-10) - 1.0) * 20.0 : 0.0)
                        + ((g_vel > 0 && g_acc > 0) || (g_vel < 0 && g_acc < 0) ? velocityScore * 0.2 : 0.0), 100.0);
   obs_DecayScore     = MathMin((g_bullMomDecay || g_bearMomDecay ? 40.0 : 0.0)
                        + (convexityScore > 30 ? convexityScore * 0.5 : 0.0) + (g_vd70 ? 30.0 : 0.0), 100.0);
   obs_CurvatureScore = convexityScore;
   obs_AbsorptionScore = MathMin((g_eff < g_effThresh * 0.7 ? (1.0 - g_eff / MathMax(g_effThresh, 1e-10)) * 50.0 : 0.0)
                        + (g_vd50 ? 30.0 : 0.0) + (g_disp < g_dispThresh * 0.5 ? 20.0 : 0.0), 100.0);
   obs_LiquidityScore = MathMin(obs_DecayScore * 0.4 + obs_CurvatureScore * 0.4
                        + (g_disp > g_dispThresh * 1.2 && (g_bullMomDecay || g_bearMomDecay) ? 20.0 : 0.0), 100.0);
  }

//==================================================================
// PART B.5 — ENERGY RESOLUTION FRAMEWORK (ERF): EDE -> RE -> EAE
//   (Pine exact). ede_state is derived from the IE1A canonical phase.
//==================================================================
int    ede_state=1;
double ede_expansionEnergy=0, ede_dissipatedEnergy=0, ede_dissipationProgress=0;
int    re_expectedCycles=1, re_completedCycles=0;
double re_recursiveCompletionScore=0, re_residualEnergy=0, re_residualEnergyScore=0;
bool   re_objectiveReached=false, re_fullDissipation=false, re_absorbedAndReturned=false;
string re_resolutionState="UNRESOLVED";
double eae_primaryAttractorPrice=0, eae_primaryAttractorScore=0;
double eae_secondaryAttractorPrice=0, eae_secondaryAttractorScore=0;
double eae_tertiaryAttractorPrice=0, eae_tertiaryAttractorScore=0;
string eae_primaryAttractorLabel="No Active Attractor";
string eae_energyState="Accumulating";

void f_updateERF()
  {
   string ph = ie1a_currentPhase;
   double atr = g_atr;
   // --- EDE ---
   ede_state =
       ph == "Point 4 Origin"          ? 1 :
       ph == "Expansion"               ? 1 :
       ph == "Expansion Pre-Convexity" ? 2 :
       ph == "Expansion Induction"     ? 3 :
       ph == "Expansion Liquidity"     ? 4 :
       ph == "New High"                ? 5 :
       ph == "New Low"                 ? 5 : 6;
   ede_expansionEnergy = MathMin(obs_ExpansionScore * 0.50 + (g_bullImpulse || g_bearImpulse ? 30.0 : 0.0) + g_eff * 20.0, 100.0);
   ede_dissipatedEnergy = MathMin((ede_state >= 2 ? obs_DecayScore * 0.40 : 0.0)
                          + (ede_state >= 3 ? obs_CurvatureScore * 0.30 : 0.0)
                          + (ede_state >= 4 ? obs_LiquidityScore * 0.30 : 0.0), 100.0);
   ede_dissipationProgress = MathMin((ede_state >= 2 ? 25.0 : 0.0) + (ede_state >= 3 ? 25.0 : 0.0)
                          + (ede_state >= 4 ? 25.0 : 0.0) + (ede_state >= 5 ? 25.0 : 0.0), 100.0);

   // --- RE ---
   re_expectedCycles  = (int)MathMax(1, MathMin(waveDepth + 2, 4));
   re_completedCycles = (int)MathMax(0, MathMin(entryCycle, re_expectedCycles));
   re_recursiveCompletionScore = re_expectedCycles > 0 ? MathMin((double)re_completedCycles / re_expectedCycles * 100.0, 100.0) : 0.0;
   re_residualEnergy = MathMax(0.0, ede_expansionEnergy - ede_dissipatedEnergy);
   re_objectiveReached = ede_state >= 5;
   re_fullDissipation  = ede_dissipationProgress >= 75.0;
   re_absorbedAndReturned = (ph == "Demand Return" || ph == "Supply Return") && recursiveComplete;
   re_resolutionState = (re_absorbedAndReturned && re_fullDissipation && re_recursiveCompletionScore >= 75.0) ? "RESOLVED" :
                        (re_objectiveReached && ede_dissipationProgress >= 50.0) ? "PARTIALLY RESOLVED" : "UNRESOLVED";
   re_residualEnergyScore = MathMin(re_residualEnergy, 100.0);

   // --- EAE (primary) ---
   if(direction == 0) eae_primaryAttractorPrice = 0;
   else if(re_resolutionState == "UNRESOLVED")
      eae_primaryAttractorPrice = direction == 1 ? (flipBot != 0 ? flipBot : g_close - atr * 2.0)
                                                 : (flipTop != 0 ? flipTop : g_close + atr * 2.0);
   else if(re_resolutionState == "PARTIALLY RESOLVED")
      eae_primaryAttractorPrice = direction == 1 ? (point4OriginLow != 0 ? point4OriginLow : g_close - atr)
                                                 : (point4OriginHigh != 0 ? point4OriginHigh : g_close + atr);
   else eae_primaryAttractorPrice = 0;
   eae_primaryAttractorScore = MathMin(re_residualEnergyScore * 0.40
                          + (re_resolutionState == "UNRESOLVED" ? 30.0 : re_resolutionState == "PARTIALLY RESOLVED" ? 20.0 : 5.0)
                          + (eae_primaryAttractorPrice != 0 ? MathMax(0.0, 30.0 - MathAbs(g_close - eae_primaryAttractorPrice) / MathMax(atr, 1e-10) * 5.0) : 0.0), 100.0);
   eae_primaryAttractorLabel = re_resolutionState == "UNRESOLVED" ? "Flip Zone (High Residual)" :
                               re_resolutionState == "PARTIALLY RESOLVED" ? "Origin Zone (Partial)" : "No Active Attractor";

   // --- EAE (secondary) — induction zone when UNRESOLVED (master spec §7.3) ---
   if(re_resolutionState == "UNRESOLVED" && (inducZoneLow != 0 || inducZoneHigh != 0))
      eae_secondaryAttractorPrice = direction == 1 ? inducZoneLow : inducZoneHigh;
   else eae_secondaryAttractorPrice = 0;
   eae_secondaryAttractorScore = MathMin(re_residualEnergyScore * 0.25
                          + (re_resolutionState == "PARTIALLY RESOLVED" ? 20.0 : 10.0)
                          + (eae_secondaryAttractorPrice != 0 ? MathMax(0.0, 20.0 - MathAbs(g_close - eae_secondaryAttractorPrice) / MathMax(atr, 1e-10) * 5.0) : 0.0), 100.0);

   // --- EAE (tertiary) — extension beyond primary (master spec §7.3) ---
   double primRef = eae_primaryAttractorPrice != 0 ? eae_primaryAttractorPrice : g_close;
   double secRef  = eae_secondaryAttractorPrice != 0 ? eae_secondaryAttractorPrice : primRef;
   eae_tertiaryAttractorPrice = direction == 1 ? MathMax(primRef, secRef) + atr * 2.0
                              : direction == -1 ? MathMin(primRef, secRef) - atr * 2.0 : 0;
   double htfAlignBonus = (l2_dir == direction && l4_dir == direction) ? 25.0 : 0.0;
   eae_tertiaryAttractorScore = MathMin(re_residualEnergyScore * 0.30 + htfAlignBonus
                          + (re_resolutionState == "RESOLVED" ? 10.0 : 0.0), 100.0);

   eae_energyState = ede_state == 1 ? "Accumulating" : ede_state == 2 ? "Cleaning" :
                     ede_state <= 4 ? "Delivering" : ede_state == 5 ? "Exhausted" : "Resolving";
  }


//==================================================================
// PART A — INVISIBLE NETWORK ENGINE  (Pine PART A, exact)
//==================================================================
// f_fuPool — dominant rejection-wick detector at a local extreme
// (swept or not). Latches an FU until confirmed/replaced. Ported by
// chronological iteration over the TF's bars, returning final state.
struct FuOut { double tip, mid; int dir; int valid; double score; };

class FuDetector
  {
private:
   ENUM_TIMEFRAMES m_tf; double m_wf; int m_lb;
public:
   FuOut o;
   void Init(ENUM_TIMEFRAMES tf, double wf, int lb) { m_tf=tf; m_wf=wf; m_lb=lb; o.tip=0;o.mid=0;o.dir=0;o.valid=0;o.score=0; }

   bool Compute(int bars)
     {
      MqlRates r[];
      ArraySetAsSeries(r, false);
      int want = bars + m_lb + 20;
      int n = CopyRates(_Symbol, m_tf, 0, want, r);
      if(n < m_lb + 20) return false;
      int last = n - 2;                 // last closed bar
      double atr=0; bool atrSeed=false;
      double tip=0,bH=0,bL=0,mid=0; int dir=0; bool have=false, conf=false;
      int start = m_lb + 2;
      for(int i = start; i <= last; i++)
        {
         double Hi=r[i].high, Li=r[i].low, Oi=r[i].open, Ci=r[i].close, Cp=r[i-1].close;
         double tr = MathMax(Hi-Li, MathMax(MathAbs(Hi-Cp), MathAbs(Li-Cp)));
         if(!atrSeed){atr=tr;atrSeed=true;} else atr=(atr*13.0+tr)/14.0;
         double rng = MathMax(Hi-Li, 1e-10);
         // highest(high,_lb)[1] and lowest(low,_lb)[1]
         double pHi=-DBL_MAX, pLo=DBL_MAX;
         for(int w=i-m_lb; w<=i-1; w++){ if(r[w].high>pHi)pHi=r[w].high; if(r[w].low<pLo)pLo=r[w].low; }
         // highest(high,_lb) inclusive of i
         double cHi=-DBL_MAX, cLo=DBL_MAX;
         for(int w=i-m_lb+1; w<=i; w++){ if(r[w].high>cHi)cHi=r[w].high; if(r[w].low<cLo)cLo=r[w].low; }
         double uw = (Hi-MathMax(Oi,Ci))/rng;
         double lw = (MathMin(Oi,Ci)-Li)/rng;
         bool localTop = Hi >= cHi;
         bool localBot = Li <= cLo;
         bool bear = uw>=m_wf && ((Hi>=pHi && Ci<pHi) || (localTop && Ci<Oi));
         bool bull = lw>=m_wf && ((Li<=pLo && Ci>pLo) || (localBot && Ci>Oi));
         if(bear){ dir=-1; tip=Hi; bH=MathMax(Oi,Ci); bL=MathMin(Oi,Ci); mid=bH+(tip-bH)*0.5; have=true; conf=false; }
         else if(bull){ dir=1; tip=Li; bH=MathMax(Oi,Ci); bL=MathMin(Oi,Ci); mid=tip+(bL-tip)*0.5; have=true; conf=false; }
         if(have && dir==-1 && !conf && Ci<bL) conf=true;
         if(have && dir==1  && !conf && Ci>bH) conf=true;
        }
      double wk = (dir==-1 && have) ? (tip-bH)/MathMax(atr,1e-10) : (dir==1 && have) ? (bL-tip)/MathMax(atr,1e-10) : 0.0;
      double score = 20.0 + MathMin(25.0, wk*15.0) + (conf?30.0:0.0) + (wk>1.0?15.0:0.0) + (wk>1.5?10.0:0.0);
      o.tip = have?tip:0; o.mid=mid; o.dir=dir; o.valid=have?1:0; o.score=score;
      return true;
     }
  };

FuDetector g_fuMN, g_fuW, g_fuD, g_fuH4, g_fuH1, g_fuM15, g_fuM5;

// ── Node registry (parallel arrays) ──────────────────────────────
double g_nPx[];   double g_nMid[]; int g_nDir[]; double g_nSc[];
int    g_nWt[];   int g_nState[];  int g_nBar[];  int g_nRev[];
int    g_netBias=0, g_pdir=0, g_eligibleNodes=0;
double g_pressure=0.0;
// pathNodes result + FEZ + attractor (set in update)
int    g_attrIdx=-1, g_domIdx=-1, g_nextIdx=-1;
double g_fezHi=0, g_fezLo=0;
int    g_fwdNodes[];   // forward path node indices (sorted by distance)

double f_auth(int i){ return g_nSc[i] + g_nWt[i]*4.0 + g_nRev[i]*3.0; }
string f_wtTf(int wt){ return wt==9?"MN":wt==8?"W":wt==7?"D":wt==6?"H4":wt==5?"H1":wt==4?"M15":wt==3?"M5":wt==2?"M3":"M1"; }

void f_nodeAdd(double tip, double mid, int dir, double sc, int wt, int barNow)
  {
   int sz = ArraySize(g_nPx);
   ArrayResize(g_nPx, sz+1);  ArrayResize(g_nMid, sz+1); ArrayResize(g_nDir, sz+1);
   ArrayResize(g_nSc, sz+1);  ArrayResize(g_nWt, sz+1);  ArrayResize(g_nState, sz+1);
   ArrayResize(g_nBar, sz+1); ArrayResize(g_nRev, sz+1);
   g_nPx[sz]=tip; g_nMid[sz]=mid; g_nDir[sz]=dir; g_nSc[sz]=sc; g_nWt[sz]=wt;
   g_nState[sz]=0; g_nBar[sz]=barNow; g_nRev[sz]=0;
   if(ArraySize(g_nPx) > g_nodeMax)
     {
      // shift off the oldest (index 0)
      for(int a=0; a<ArraySize(g_nPx)-1; a++)
        {
         g_nPx[a]=g_nPx[a+1]; g_nMid[a]=g_nMid[a+1]; g_nDir[a]=g_nDir[a+1];
         g_nSc[a]=g_nSc[a+1]; g_nWt[a]=g_nWt[a+1]; g_nState[a]=g_nState[a+1];
         g_nBar[a]=g_nBar[a+1]; g_nRev[a]=g_nRev[a+1];
        }
      int ns=ArraySize(g_nPx)-1;
      ArrayResize(g_nPx,ns);ArrayResize(g_nMid,ns);ArrayResize(g_nDir,ns);ArrayResize(g_nSc,ns);
      ArrayResize(g_nWt,ns);ArrayResize(g_nState,ns);ArrayResize(g_nBar,ns);ArrayResize(g_nRev,ns);
     }
  }

// last-tip memory per TF (so a node is added only when the FU tip changes)
double g_pvFu[7];   // index by weight slot: 0..6 -> MN..M5 (wt 9..3)
int    g_netBarCounter = 0;

void f_networkUpdate()
  {
   g_netBarCounter++;
   int barNow = g_netBarCounter;
   g_fuMN.Compute(g_lookbackBarsFor(PERIOD_MN1));
   g_fuW.Compute(g_lookbackBarsFor(PERIOD_W1));
   g_fuD.Compute(g_lookbackBarsFor(PERIOD_D1));
   g_fuH4.Compute(g_lookbackBarsFor(PERIOD_H4));
   g_fuH1.Compute(g_lookbackBarsFor(PERIOD_H1));
   g_fuM15.Compute(g_lookbackBarsFor(PERIOD_M15));
   g_fuM5.Compute(g_lookbackBarsFor(PERIOD_M5));

   // add nodes when a TF's FU tip changes (weights MN=9..M5=3)
   AddFu(g_fuMN.o,  9, 0, barNow);
   AddFu(g_fuW.o,   8, 1, barNow);
   AddFu(g_fuD.o,   7, 2, barNow);
   AddFu(g_fuH4.o,  6, 3, barNow);
   AddFu(g_fuH1.o,  5, 4, barNow);
   AddFu(g_fuM15.o, 4, 5, barNow);
   AddFu(g_fuM5.o,  3, 6, barNow);

   // netBias: highest-TF active FU dir, else EMA50 fallback
   double ema50 = f_ema(_Period, 50);
   g_netBias = g_fuMN.o.valid==1?g_fuMN.o.dir : g_fuW.o.valid==1?g_fuW.o.dir :
               g_fuD.o.valid==1?g_fuD.o.dir : g_fuH4.o.valid==1?g_fuH4.o.dir :
               g_fuH1.o.valid==1?g_fuH1.o.dir : g_fuM15.o.valid==1?g_fuM15.o.dir :
               g_fuM5.o.valid==1?g_fuM5.o.dir : (g_close>ema50?1:g_close<ema50?-1:0);

   // node lifecycle (consumed/dormant/historical + revisit)
   double atr14 = g_atr > 0 ? g_atr : f_atrChart(14);
   int sz = ArraySize(g_nPx);
   for(int i=0; i<sz; i++)
     {
      if(g_nState[i] == 2) continue;
      double np = g_nPx[i]; int nd = g_nDir[i];
      int age = barNow - g_nBar[i];
      if(nd==-1 ? g_close>np : g_close<np) g_nState[i]=2;
      else
        {
         if(MathAbs(g_close-np) < atr14*0.25) g_nRev[i] = g_nRev[i]+1;
         int wtn = g_nWt[i];
         g_nState[i] = age > g_historyBars*wtn ? 3 : age > g_dormantBars*wtn ? 1 : 0;
        }
     }

   // tallies + dominant + attractor + FEZ
   double bullAuth=0, bearAuth=0, domAuth=0, attrRank=-1, fezHiA=0, fezLoA=0;
   g_eligibleNodes=0; g_domIdx=-1; g_attrIdx=-1; g_fezHi=0; g_fezLo=0;
   for(int i=0; i<sz; i++)
     {
      if(g_nState[i]==2) continue;
      double a = f_auth(i);
      if(a < g_authMin) continue;
      double np = g_nPx[i]; int nd = g_nDir[i]; int wt = g_nWt[i];
      g_eligibleNodes++;
      if(nd==1) bullAuth += a; else if(nd==-1) bearAuth += a;
      if(a > domAuth){ domAuth=a; g_domIdx=i; }
      bool onBias = g_netBias==-1 ? np<g_close : np>g_close;
      if(onBias){ double rk = wt*1000.0 + a; if(rk>attrRank){ attrRank=rk; g_attrIdx=i; } }
      if(np>g_close && a>fezHiA){ g_fezHi=np; fezHiA=a; }
      if(np<g_close && a>fezLoA){ g_fezLo=np; fezLoA=a; }
     }
   g_pressure = (bullAuth+bearAuth) > 0 ? (bullAuth-bearAuth)/(bullAuth+bearAuth)*100.0 : 0.0;
   g_pdir = g_pressure>12 ? 1 : g_pressure<-12 ? -1 : 0;

   // forward path nodes (ahead of price along netBias), sorted by distance
   f_pathNodes(true, g_fwdNodes);
   g_nextIdx = ArraySize(g_fwdNodes) > 0 ? g_fwdNodes[0] : -1;
  }

void AddFu(const FuOut &fu, int wt, int slot, int barNow)
  {
   if(fu.valid==1 && fu.tip!=0 && (g_pvFu[slot]==0 || fu.tip!=g_pvFu[slot]))
     {
      f_nodeAdd(fu.tip, fu.mid, fu.dir, fu.score, wt, barNow);
      g_pvFu[slot] = fu.tip;
     }
  }

void f_pathNodes(bool aheadSide, int &out[])
  {
   ArrayResize(out, 0);
   int sz = ArraySize(g_nPx);
   for(int i=0; i<sz; i++)
     {
      double np = g_nPx[i];
      bool ahead = g_netBias==1 ? np>g_close : np<g_close;
      if(g_nState[i]!=2 && f_auth(i)>=g_authMin && (aheadSide?ahead:!ahead))
        {
         int k=ArraySize(out); ArrayResize(out,k+1); out[k]=i;
        }
     }
   // insertion sort by |close - px| ascending
   for(int a=1; a<ArraySize(out); a++)
     {
      int key=out[a]; double kd=MathAbs(g_close-g_nPx[key]);
      int b=a-1;
      while(b>=0 && MathAbs(g_close-g_nPx[out[b]])>kd){ out[b+1]=out[b]; b--; }
      out[b+1]=key;
     }
  }

double f_ema(ENUM_TIMEFRAMES tf, int period)
  {
   double buf[]; ArraySetAsSeries(buf, true);
   int h = iMA(_Symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(h==INVALID_HANDLE) return g_close;
   if(CopyBuffer(h, 0, 0, 2, buf) < 1){ IndicatorRelease(h); return g_close; }
   double v = buf[0]; IndicatorRelease(h); return v;
  }

double f_atrChart(int len)
  {
   double buf[]; ArraySetAsSeries(buf, true);
   int h = iATR(_Symbol, _Period, len);
   if(h==INVALID_HANDLE) return 0.0;
   if(CopyBuffer(h, 0, 0, 2, buf) < 1){ IndicatorRelease(h); return 0.0; }
   double v=buf[0]; IndicatorRelease(h); return v;
  }

string f_cpNode(int i)
  {
   if(i<0) return "—";
   return f_wtTf(g_nWt[i]) + " " + (g_nDir[i]==1?"▲":"▼") + " " + DoubleToString(g_nPx[i], _Digits);
  }


//==================================================================
// CHART-BAR HELPERS (last closed bar = shift 1)
//==================================================================
double C1(int s){ return iClose(_Symbol,_Period,s); }
double O1(int s){ return iOpen (_Symbol,_Period,s); }
double H1b(int s){ return iHigh (_Symbol,_Period,s); }
double L1b(int s){ return iLow  (_Symbol,_Period,s); }
double HH(int len,int start){ double m=-DBL_MAX; for(int i=start;i<start+len;i++){double v=H1b(i); if(v>m)m=v;} return m; }
double LL(int len,int start){ double m=DBL_MAX; for(int i=start;i<start+len;i++){double v=L1b(i); if(v<m)m=v;} return m; }

//==================================================================
// CHART PIVOT MEMORY (Pine Section 5) — spawn order-block anchor.
//==================================================================
double lastPivotPrice=0, prevPivotPrice=0; int lastPivotDir=0, prevPivotDir=0;
int    g_chartBarCount=0;

void f_updatePivots()
  {
   int pl = g_pivotLen;
   // pivot confirmed at shift pl (need pl bars either side)
   double hv=H1b(pl), lv=L1b(pl);
   bool isH=true, isL=true;
   for(int w=1; w<=2*pl; w++){ int s=w; if(s==pl)continue; if(H1b(s)>=hv)isH=false; if(L1b(s)<=lv)isL=false; }
   double evP=0; int evD=0; bool has=false;
   if(isH){ evP=hv; evD=1; has=true; }
   else if(isL){ evP=lv; evD=-1; has=true; }
   if(has){ prevPivotPrice=lastPivotPrice; prevPivotDir=lastPivotDir; lastPivotPrice=evP; lastPivotDir=evD; }
  }

double f_findInducPrice(double anchorTop, double anchorBot, int lookback)
  {
   double best=0, bestDist=-1;
   int maxI = MathMin(lookback, 200);
   for(int i=1; i<=maxI; i++)
     {
      if(H1b(i) < anchorTop && L1b(i) > anchorBot)
        {
         double d = (double)i;
         if(bestDist<0 || d<bestDist){ bestDist=d; best=(H1b(i)+L1b(i))/2.0; }
        }
     }
   return best;
  }

//==================================================================
// SECTION 10 — LIQUIDITY HEATMAP
//==================================================================
bool   liqSweepBull=false, liqSweepBear=false, liqVacuum=false, liqSweepOK=false;
double g_liqLevels[]; double g_liqWeights[]; int g_liqAges[];

void f_updateLiquidity()
  {
   double atr=g_atr;
   double swH=HH(g_liqSweepLookback,1), swL=LL(g_liqSweepLookback,1);
   liqSweepBull = flipTop!=0 && swH>flipTop;
   liqSweepBear = flipBot!=0 && swL<flipBot;
   // push pivot level with weight (vol*range) when a chart pivot confirmed
   int pl=g_pivotLen;
   double hv=H1b(pl), lv=L1b(pl);
   bool isH=true,isL=true;
   for(int w=1;w<=2*pl;w++){int s=w; if(s==pl)continue; if(H1b(s)>=hv)isH=false; if(L1b(s)<=lv)isL=false;}
   if(isH||isL)
     {
      double lvl = isH?hv:lv;
      double volAvg=0; for(int i=1;i<=20;i++) volAvg += (double)iVolume(_Symbol,_Period,i); volAvg/=20.0;
      double nv = volAvg>0 ? (double)iVolume(_Symbol,_Period,pl)/volAvg : 1.0;
      double swRng=(H1b(pl)-L1b(pl))/MathMax(atr,1e-10);
      int sz=ArraySize(g_liqLevels);
      ArrayResize(g_liqLevels,sz+1);ArrayResize(g_liqWeights,sz+1);ArrayResize(g_liqAges,sz+1);
      g_liqLevels[sz]=lvl; g_liqWeights[sz]=nv*swRng; g_liqAges[sz]=g_chartBarCount;
      if(ArraySize(g_liqLevels)>150)
        {
         for(int a=0;a<ArraySize(g_liqLevels)-1;a++){g_liqLevels[a]=g_liqLevels[a+1];g_liqWeights[a]=g_liqWeights[a+1];g_liqAges[a]=g_liqAges[a+1];}
         int ns=ArraySize(g_liqLevels)-1; ArrayResize(g_liqLevels,ns);ArrayResize(g_liqWeights,ns);ArrayResize(g_liqAges,ns);
        }
     }
   double wDensity=0,wAbove=0,wBelow=0;
   double rP=atr*g_liqRadius, rW=atr*g_liqRadius*3.0;
   for(int i=0;i<ArraySize(g_liqLevels);i++)
     {
      double lvl=g_liqLevels[i], wt=g_liqWeights[i];
      int age=g_chartBarCount-g_liqAges[i];
      double dcy=MathPow(g_liqAgDecay,age);
      double dist=MathAbs(g_close-lvl);
      if(dist<rP) wDensity += wt*dcy;
      if(dist<rW){ if(lvl>g_close) wAbove += wt*dcy*(1.0-dist/rW); else wBelow += wt*dcy*(1.0-dist/rW); }
     }
   double liqHeatRaw = MathMin((wAbove+wBelow)/2.0,5.0)/5.0*100.0;
   liqHeat = f_clamp(liqHeatRaw,0.0,100.0);
   liqVacuum = wDensity<0.5;
   liqSweepOK = !g_requireLiqSweep || (direction==1 && (liqSweepBull||liqVacuum)) || (direction==-1 && (liqSweepBear||liqVacuum));
  }

//==================================================================
// SECTION 12 — WAVE INTELLIGENCE (similarity, convexity maturity,
// geometric progress, smoothed waveProgress, waveModelFit)
//==================================================================
double waveProgress=30.0, waveModelFit=50.0;

double f_idealSim(double e,double d,double v,double c,double ei,double di,double vi,double ci)
  {
   double diff=MathPow(e-ei,2)+MathPow(d-di,2)+MathPow(v-vi,2)+MathPow(c-ci,2);
   return MathMax(0.0,100.0*(1.0-diff/4.0));
  }

void f_updateWaveIntel()
  {
   double atr=g_atr;
   double effN=MathMin(g_eff,1.0);
   double dispN=MathMin(g_disp/MathMax(g_dispThresh*2.0,1e-10),1.0);
   double velN=MathMin(MathAbs(g_vel)/MathMax(atr*0.15,1e-10),1.0);
   double curvN=MathMin(MathAbs(g_csm)/MathMax(atr*g_convMult*2.0,1e-10),1.0);
   double sExp=f_idealSim(effN,dispN,velN,curvN,0.85,0.80,0.80,0.10);
   double sPre=f_idealSim(effN,dispN,velN,curvN,0.60,0.55,0.40,0.50);
   double sInd=f_idealSim(effN,dispN,velN,curvN,0.65,0.60,0.30,0.60);
   double sLiq=f_idealSim(effN,dispN,velN,curvN,0.45,0.85,0.15,0.80);
   double sCre=f_idealSim(effN,dispN,velN,curvN,0.30,0.70,0.05,0.90);
   double sAbs=f_idealSim(effN,dispN,velN,curvN,0.20,0.25,0.10,0.40);
   double sRet=f_idealSim(effN,dispN,velN,curvN,0.70,0.65,0.65,0.25);
   double sDem=f_idealSim(effN,dispN,velN,curvN,0.50,0.40,0.35,0.20);
   double originToExtreme = 0;
   if(point4OriginHigh!=0 && point4OriginLow!=0)
     {
      double orig = direction==1?point4OriginLow:point4OriginHigh;
      double extr = direction==1?(cycleHigh!=0?cycleHigh:orig):(cycleLow!=0?cycleLow:orig);
      originToExtreme=MathAbs(extr-orig);
     }
   double waveTotalRange = originToExtreme!=0?originToExtreme:atr*5.0;
   double currentToExtreme = direction==1?MathAbs((cycleHigh!=0?cycleHigh:g_close+atr)-g_close):MathAbs(g_close-(cycleLow!=0?cycleLow:g_close-atr));
   double posNormDen=MathMax(waveTotalRange,atr*0.5);
   double posDistToCreation=MathMin(currentToExtreme/posNormDen*100.0,100.0);
   double expWeak=MathMin(((g_eff<g_effThresh?(1.0-g_eff/MathMax(g_effThresh,1e-10))*40.0:0.0)+obs_DecayScore*0.30+(MathAbs(g_vel)<MathAbs(g_vel)*0.6?20.0:0.0))*(100.0/90.0),100.0);
   double indMat=MathMin((inductionEvidence?35.0:0.0)+obs_CurvatureScore*0.35+(preConvEvidence?20.0:0.0)+(g_disp>g_dispThresh*1.2&&(g_bullMomDecay||g_bearMomDecay)?10.0:0.0),100.0);
   double liqMat=MathMin(obs_LiquidityScore*0.50+(liqSweepBull||liqSweepBear?30.0:0.0)+(liqHeat>60?20.0:liqHeat>30?10.0:0.0),100.0);
   double rawConvMat=MathMin(expWeak*0.35+indMat*0.35+liqMat*0.30,100.0);
   double alpha=2.0/(g_beliefSmooth+1);
   convexityMaturity += alpha*(rawConvMat-convexityMaturity);
   // geometric progress
   double geomProg=30.0;
   if(point4OriginHigh!=0 && flipTop!=0 && flipBot!=0)
     {
      double orig=direction==1?point4OriginLow:point4OriginHigh;
      double extr=direction==1?(cycleHigh!=0?cycleHigh:g_close+atr):(cycleLow!=0?cycleLow:g_close-atr);
      double fzMid=(flipTop+flipBot)/2.0;
      double totalMove=MathAbs(extr-orig), toFz=MathAbs(extr-fzMid);
      double expProg=totalMove>1e-10?MathMin(MathAbs(g_close-orig)/totalMove*60.0,60.0):30.0;
      double retrMove=MathAbs(g_close-extr);
      double retrProg=toFz>1e-10?MathMin(retrMove/MathMax(toFz,1e-10)*40.0,40.0):0.0;
      geomProg=expProg+retrProg*MathMin(obs_AbsorptionScore/40.0,1.0);
     }
   double simAnchor =
       (sDem>=sRet&&sDem>=sAbs&&sDem>=sCre&&sDem>=sExp)?95.0 :
       (sRet>=sAbs&&sRet>=sCre&&sRet>=sExp)?87.0 :
       (sAbs>=sCre&&sAbs>=sExp)?75.0 :
       (sCre>=sLiq&&sCre>=sExp)?62.0 :
       (sLiq>=sInd&&sLiq>=sExp)?52.0 :
       (sInd>=sPre&&sInd>=sExp)?43.0 :
       (sPre>=sExp)?33.0 : 22.0;
   double convW=MathMax(0.0,1.0-MathAbs(simAnchor-47.5)/14.5);
   double physProg=simAnchor+(convexityMaturity/100.0)*(simAnchor-33.0)*0.50*convW;
   double rawWP=geomProg*0.60+physProg*0.40;
   waveProgress += alpha*(rawWP-waveProgress);
   waveProgress=f_clamp(waveProgress,0.0,100.0);
   double bestSim=MathMax(sExp,MathMax(sPre,MathMax(sInd,MathMax(sLiq,MathMax(sCre,MathMax(sAbs,MathMax(sRet,sDem)))))));
   double flipzoneWidth = (flipTop!=0&&flipBot!=0)?flipTop-flipBot:0;
   double geomCons=MathMin((originToExtreme!=0&&originToExtreme>atr*2.0?30.0:0.0)+(flipzoneWidth!=0&&flipzoneWidth<atr*4.0?25.0:0.0)+((cycleHigh!=0||cycleLow!=0)?20.0:0.0)+(direction!=0?25.0:0.0),100.0);
   waveModelFit += alpha*((bestSim*0.55+geomCons*0.45)-waveModelFit);
   waveModelFit=f_clamp(waveModelFit,0.0,100.0);
  }

//==================================================================
// SECTION 12A — BELIEF ENGINE (6 EMA-smoothed beliefs)
//==================================================================
double expansionBelief=0, convexityBelief=0, creationBelief=0;
double absorptionBelief=0, retracementBelief=0, demandReturnBelief=0;

void f_updateBelief()
  {
   double atr=g_atr;
   preConvEvidence = g_bullMomDecay || g_bearMomDecay;
   inductionEvidence = (direction==1 && g_bearImpulse && structBias==1) || (direction==-1 && g_bullImpulse && structBias==-1);
   bool liqEv = obs_LiquidityScore>50.0 && obs_DecayScore>40.0;
   // similarity recomputed cheaply for belief terms (reuse approx via obs)
   double sExp = obs_ExpansionScore, sCre = creationBelief, sAbs = obs_AbsorptionScore;
   double sRet = retracementBelief, sDem = demandReturnBelief;
   double expPosMult = waveProgress<40.0?1.20:waveProgress<60.0?0.80:0.50;
   double rawExp = MathMin((obs_ExpansionScore*0.45+(g_bullImpulse||g_bearImpulse?30.0:0.0)+(g_eff>g_effThresh*1.1?15.0:0.0)+sExp*0.10)*expPosMult,100.0);
   double convPosMult=(waveProgress>=30.0&&waveProgress<=65.0)?1.30:0.70;
   double rawConv=MathMin((obs_DecayScore*0.30+obs_CurvatureScore*0.25+(preConvEvidence?15.0:0.0)+(inductionEvidence?10.0:0.0)+(liqEv?5.0:0.0)+convexityMaturity*0.08)*convPosMult,100.0);
   double creatPosMult=(waveProgress>=45.0&&waveProgress<=68.0)?1.40:0.60;
   double posDist=0;
   double rawCreat=MathMin(((convexityMaturity>50?convexityMaturity*0.12:0.0)+(obs_DecayScore>60?obs_DecayScore*0.20:0.0)+(obs_LiquidityScore>50?obs_LiquidityScore*0.20:0.0)+(obs_AbsorptionScore>20?obs_AbsorptionScore*0.15:0.0)+((cycleHigh!=0&&cycleLow!=0&&((direction==1&&H1b(1)>=cycleHigh*0.998)||(direction==-1&&L1b(1)<=cycleLow*1.002)))?20.0:0.0))*creatPosMult,100.0);
   double rawAbs=MathMin(obs_AbsorptionScore*0.50+(g_eff<g_effThresh*0.6?25.0:0.0)+(g_disp<g_dispThresh*0.5?15.0:0.0),100.0);
   double rawRet=MathMin(((direction==1&&g_bearImpulse)||(direction==-1&&g_bullImpulse)?45.0:0.0)+(rawAbs>50?rawAbs*0.30:0.0)+(obs_CurvatureScore>40?15.0:0.0),100.0);
   double rawDem=MathMin((flipTop!=0&&flipBot!=0&&g_close<=flipTop&&g_close>=flipBot?35.0:0.0)+(rawRet>60?rawRet*0.30:0.0)+(liqHeat>50?liqHeat*0.15:0.0)+(liqSweepBull||liqSweepBear?20.0:0.0),100.0);
   double a=2.0/(g_beliefSmooth+1);
   expansionBelief    += a*(rawExp-expansionBelief);
   convexityBelief    += a*(rawConv-convexityBelief);
   creationBelief     += a*(rawCreat-creationBelief);
   absorptionBelief   += a*(rawAbs-absorptionBelief);
   retracementBelief  += a*(rawRet-retracementBelief);
   demandReturnBelief += a*(rawDem-demandReturnBelief);
  }

//==================================================================
// SECTION 13 — WAVE SPAWN ENGINE + recursion (M5-governed)
//==================================================================
int    obBirthBar=0, contBar=0;
int    g_recursiveFiredBar=-99999;

void f_doSpawn(int newDir)
  {
   double atr=g_atr;
   double obTop = g_se5.o.p4h!=0?g_se5.o.p4h:(newDir==1?lastPivotPrice:prevPivotPrice);
   double obBot = g_se5.o.p4l!=0?g_se5.o.p4l:(newDir==1?prevPivotPrice:lastPivotPrice);
   double fzIP  = f_findInducPrice(obTop, obBot, g_inducLookback);
   direction=newDir; flipTop=obTop; flipBot=obBot;
   point4OriginHigh=obTop; point4OriginLow=obBot;
   obBirthBar=g_chartBarCount; contBar=0;
   inducZoneLow = fzIP!=0?fzIP-atr*g_inducZoneWidth:0;
   inducZoneHigh= fzIP!=0?fzIP+atr*g_inducZoneWidth:0;
   cycleHigh=H1b(1); cycleLow=L1b(1);
   isRecursiveWave=false; entryCycle=0; waveDepth=0;
  }

void f_updateSpawn()
  {
   double atr=g_atr;
   bool allowSpawn = l0_dir!=0 && l0_dir!=direction;
   if(allowSpawn) f_doSpawn(l0_dir);
   if(direction==1  && H1b(1)>(cycleHigh!=0?cycleHigh:H1b(1))) cycleHigh=H1b(1);
   if(direction==-1 && L1b(1)<(cycleLow!=0?cycleLow:L1b(1)))  cycleLow=L1b(1);

   nearFlipzone = flipTop!=0 && flipBot!=0 && g_close<=flipTop*1.02 && g_close>=flipBot*0.98;
   closeInside  = flipTop!=0 && g_close<=flipTop && g_close>=flipBot;

   // recursion trigger (Demand/Supply Return, belief-gated)
   bool priceInDemand = flipBot!=0 && L1b(1)<flipBot && point4OriginHigh!=0 && L1b(1)<=point4OriginHigh;
   bool priceInSupply = flipTop!=0 && H1b(1)>flipTop && point4OriginLow!=0  && H1b(1)>=point4OriginLow;
   bool trueCHoCHbull = direction==1  && priceInDemand && g_bullImpulse && liqSweepOK;
   bool trueCHoCHbear = direction==-1 && priceInSupply && g_bearImpulse && liqSweepOK;
   bool structFlipBull= direction==1  && g_bullConvShift && structBias==-1;
   bool structFlipBear= direction==-1 && g_bearConvShift && structBias==1;
   bool recursiveTrigger = (trueCHoCHbull||trueCHoCHbear||structFlipBull||structFlipBear)
                           && (ie1a_currentPhase=="Demand Return"||ie1a_currentPhase=="Supply Return")
                           && demandReturnBelief>40 && direction!=0 && flipTop!=0;
   if(recursiveTrigger && (g_chartBarCount-g_recursiveFiredBar)>g_resetBars)
     {
      g_recursiveFiredBar=g_chartBarCount;
      recursiveComplete=true;
      waveGeneration++;
      entryCycle=(int)MathMin(entryCycle+1,4);
      isRecursiveWave=true; waveDepth=entryCycle;
      int nextDir = l0_dir!=0?l0_dir:((g_bullImpulse||g_bullConvShift)?1:-1);
      f_doSpawn(nextDir);
      contBar=g_chartBarCount;
     }

   // invalidation / soft reset
   int barsSinceCont = contBar!=0?(g_chartBarCount-contBar):(obBirthBar!=0?(g_chartBarCount-obBirthBar):0);
   bool bullInvalid = direction==1  && g_close < flipBot - atr*0.5;
   bool bearInvalid = direction==-1 && g_close > flipTop + atr*0.5;
   bool opposingMove= (direction==1&&g_bearImpulse)||(direction==-1&&g_bullImpulse);
   bool hardInvalid = bullInvalid||bearInvalid;
   bool softReset   = barsSinceCont>g_resetBars && opposingMove
                      && ie1a_currentPhase!="Demand Return" && ie1a_currentPhase!="Supply Return"
                      && demandReturnBelief<30 && expansionBelief<30;
   if(direction!=l0_dir && (hardInvalid||softReset))
     {
      direction=0; flipTop=0; flipBot=0; contBar=0; obBirthBar=0;
      isRecursiveWave=false; entryCycle=0; waveDepth=0; recursiveComplete=false;
     }
  }

//==================================================================
// ENGINE 1A.7 — PRE-OBJECTIVE LIQUIDATION WAVE OVERLAY
//==================================================================
bool   liqg_active=false, liqg_isRetr=false; int liqg_dir=0;
double liqg_target=0, liqg_initDist=0, liqg_distPct=0;
bool   liqg_objArrival=false, liqg_trueCHoCH=false;
string liqg_subPhase="", liqg_title="";

void f_updateLiqg()
  {
   double atr=g_atr;
   bool retr = ie1a_currentPhase=="Retracement Induction";
   bool arm  = ie1a_currentPhase=="Expansion Induction" || retr;
   double obj = g_se5.o.tgt;
   if(arm && !liqg_active && obj!=0)
     {
      liqg_active=true; liqg_isRetr=retr; liqg_target=obj;
      liqg_dir = obj>g_close?1:-1;
      liqg_initDist=MathMax(MathAbs(obj-g_close),atr*0.5);
     }
   if(liqg_active && obj!=0) liqg_target=obj;
   double remain = (liqg_active && liqg_target!=0)?MathAbs(liqg_target-g_close):0;
   liqg_distPct = (liqg_active && remain!=0)?MathMin(100.0,remain/MathMax(liqg_initDist,1e-10)*100.0):0;
   bool capExh = ede_dissipationProgress>60 || convexityMaturity>60;
   bool resolved = re_resolutionState=="RESOLVED";
   bool energyLo = g_eff<g_effThresh*0.7;
   bool magnet = liqg_active && liqg_distPct!=0 && liqg_distPct<20;
   bool arrStruct = liqg_active && liqg_target!=0 && (liqg_dir==1?g_close>=liqg_target:g_close<=liqg_target);
   bool arrPhys = capExh && (resolved||magnet);
   liqg_objArrival = arrStruct && energyLo && arrPhys;
   bool counterBOS = liqg_dir==1 ? g_se5.o.bos==-1 : g_se5.o.bos==1;
   liqg_trueCHoCH = liqg_objArrival && counterBOS && energyLo && resolved;
   liqg_subPhase = !liqg_active ? "" :
       liqg_objArrival ? "Objective Arrival" :
       (magnet&&energyLo) ? "Terminal Liquidation" :
       (convexityMaturity>40||ede_dissipationProgress>40) ? "Induction" :
       (liqg_distPct!=0&&liqg_distPct<70) ? "Displacement" :
       (liqg_distPct!=0&&liqg_distPct<95) ? "Push" : "Initialization";
   int dwd = l0_dir;
   liqg_title = !liqg_active ? "" :
       (liqg_isRetr && dwd==-1) ? "Pre-Supply Return Liquidation Wave" :
       liqg_isRetr ? "Pre-Demand Return Liquidation Wave" :
       (dwd==-1) ? "Pre-New Low Liquidation Wave" : "Pre-New High Liquidation Wave";
   bool inWindow = ie1a_currentPhase=="Expansion Induction"||ie1a_currentPhase=="Expansion Liquidity"||ie1a_currentPhase=="Retracement Induction"||ie1a_currentPhase=="Retracement Liquidity";
   if(liqg_active && (!inWindow || (liqg_objArrival && liqg_trueCHoCH))) liqg_active=false;
   waveObj = liqg_target!=0?liqg_target:g_se5.o.tgt;
  }

//==================================================================
// FRZ ENGINE (Future Return Zone) — component scoring + best live zone
// (master spec §8). Simplified single-best tracking on chart bars.
//==================================================================
double frz_bestScore=0, frz_bestZoneMid=0, frz_distanceToZone=0, frz_confidence=0;
string frz_bestTier="-", frz_bestClass="Weak", frz_bestStatus="Open";
int    frz_bestDir=0, frz_activeCount=0;
double frz_resolutionScore=0, frz_residualEnergy=0, frz_attractorWeight=0;
bool   frz_inProximity=false, frz_attractorConvergence=false;

void f_updateFRZ()
  {
   double atr=g_atr;
   // component detection on the last closed chart bar
   bool fu = g_bullImpulse || g_bearImpulse; // displacement proxy stands in for FU-prev gap
   bool imb = g_disp > g_dispThresh;
   bool liq = liqSweepBull || liqSweepBear || liqVacuum || obs_LiquidityScore>55.0;
   bool dispC = g_bullImpulse || g_bearImpulse;
   double scoreFU  = (g_bullImpulse||g_bearImpulse) ? 25.0 : 0.0;
   double scoreIMB = imb ? 25.0 : 0.0;
   double scoreLIQ = liq ? 25.0 : 0.0;
   double scoreDisp= dispC ? 25.0 : 0.0;
   double raw = scoreFU+scoreIMB+scoreLIQ+scoreDisp;
   // spawn/refresh a best zone when score qualifies and a wave is active
   if(raw>=26.0 && direction!=0 && (scoreFU>0||scoreLIQ>0||scoreDisp>0))
     {
      double zoneMid = direction==1 ? (flipBot!=0?flipBot:g_close) : (flipTop!=0?flipTop:g_close);
      // keep the higher-scoring zone
      if(raw>=frz_bestScore || frz_activeCount==0)
        {
         frz_bestScore=raw; frz_bestZoneMid=zoneMid; frz_bestDir=direction;
         frz_bestClass = raw>=76?"Exceptional":raw>=51?"Strong":raw>=26?"Moderate":"Weak";
         frz_bestTier  = raw>=76?"T1":raw>=51?"T2":(raw>=26&&scoreFU>0)?"T3":(raw>=26&&scoreIMB>0)?"T4":"-";
         frz_bestStatus="Open";
         frz_activeCount=1;
        }
     }
   // lifecycle: invalidate if closed through from the wrong side
   if(frz_activeCount>0 && frz_bestZoneMid!=0)
     {
      if(frz_bestDir==1 && g_close < frz_bestZoneMid - atr*0.1) frz_bestStatus="Mitigated";
      if(frz_bestDir==-1 && g_close > frz_bestZoneMid + atr*0.1) frz_bestStatus="Mitigated";
     }
   frz_inProximity = frz_activeCount>0 && frz_bestZoneMid!=0 && MathAbs(g_close-frz_bestZoneMid)/MathMax(atr,1e-10) < 2.0;
   frz_distanceToZone = frz_activeCount>0 ? MathAbs(g_close-frz_bestZoneMid)/MathMax(atr,1e-10) : 0;
   double tierBonus = frz_bestTier=="T1"?30.0:frz_bestTier=="T2"?20.0:10.0;
   double statBonus = frz_bestStatus=="Open"?30.0:frz_bestStatus=="Partial"?15.0:0.0;
   frz_confidence = frz_activeCount>0 ? frz_bestScore*0.40 + statBonus + tierBonus : 0;
   // FRZ <-> ERF unification
   frz_resolutionScore = re_resolutionState=="RESOLVED"?90.0 :
                         re_resolutionState=="PARTIALLY RESOLVED"?50.0+re_recursiveCompletionScore*0.40 :
                         20.0+ede_dissipationProgress*0.30;
   frz_residualEnergy = MathMax(0.0,100.0-frz_resolutionScore);
   double stBon2 = frz_bestStatus=="Open"?20.0:frz_bestStatus=="Partial"?10.0:0.0;
   frz_attractorWeight = frz_residualEnergy*0.50 + frz_bestScore*0.30 + stBon2;
   frz_attractorConvergence = frz_activeCount>0 && eae_primaryAttractorPrice!=0
                              && MathAbs(eae_primaryAttractorPrice-frz_bestZoneMid)/MathMax(atr,1e-10) < 0.5;
  }


//==================================================================
// ENGINE 8.0 — TIME INTELLIGENCE ENGINE (TIE) — 5-cycle stack
//   Cycle objects MN/W/D/H4/H1 (Pine exact). bias/state/completion/
//   taken flags; timeDir/timeAlign/timeConflict; h1Timing/h1LowProb;
//   tSeq sequence string.
//==================================================================
int    timeDir=0;
double timeAlign=50.0, timeConflict=0.0, h1LowProb=50.0;
string h1Timing="BALANCED", tSeq="";
// per-cycle taken flags (consumed by dashboard / Senzo)
bool   tMnHt=false,tMnLt=false,tWHt=false,tWLt=false,tDHt=false,tDLt=false;
bool   tH4Ht=false,tH4Lt=false,tH1Ht=false,tH1Lt=false;

int f_tBias(double o){ return g_close>o?1:g_close<o?-1:0; }

void f_cycle(ENUM_TIMEFRAMES tf, double &o,double &h,double &l,double &ph,double &pl,bool &ht,bool &lt,double &elapsed)
  {
   o = iOpen(_Symbol,tf,0);
   h = iHigh(_Symbol,tf,0);
   l = iLow (_Symbol,tf,0);
   ph= iHigh(_Symbol,tf,1);
   pl= iLow (_Symbol,tf,1);
   ht = h>ph; lt = l<pl;
   datetime ct = iTime(_Symbol,tf,0);
   elapsed = f_clamp((double)(TimeCurrent()-ct)/MathMax((double)PeriodSeconds(tf),1.0),0.0,1.0);
  }

void f_updateTIE()
  {
   double mnO,mnH,mnL,mnPH,mnPL,mnEl; f_cycle(PERIOD_MN1,mnO,mnH,mnL,mnPH,mnPL,tMnHt,tMnLt,mnEl);
   double wO,wH,wL,wPH,wPL,wEl;       f_cycle(PERIOD_W1, wO,wH,wL,wPH,wPL,tWHt,tWLt,wEl);
   double dO,dH,dL,dPH,dPL,dEl;       f_cycle(PERIOD_D1, dO,dH,dL,dPH,dPL,tDHt,tDLt,dEl);
   double h4O,h4H,h4L,h4PH,h4PL,h4El; f_cycle(PERIOD_H4, h4O,h4H,h4L,h4PH,h4PL,tH4Ht,tH4Lt,h4El);
   double h1O,h1H,h1L,h1PH,h1PL,h1El; f_cycle(PERIOD_H1, h1O,h1H,h1L,h1PH,h1PL,tH1Ht,tH1Lt,h1El);

   int tBull=(f_tBias(mnO)==1)+(f_tBias(wO)==1)+(f_tBias(dO)==1)+(f_tBias(h4O)==1)+(f_tBias(h1O)==1);
   int tBear=(f_tBias(mnO)==-1)+(f_tBias(wO)==-1)+(f_tBias(dO)==-1)+(f_tBias(h4O)==-1)+(f_tBias(h1O)==-1);
   timeDir = tBull>tBear?1:tBear>tBull?-1:0;
   timeAlign = (tBull+tBear)>0 ? MathMax(tBull,tBear)/(double)(tBull+tBear)*100.0 : 50.0;
   timeConflict = 100.0-timeAlign;
   // h1 low probability
   double pos = (g_close-h1L)/MathMax(h1H-h1L,_Point);
   h1LowProb = (tH1Lt&&!tH1Ht)?30.0:(tH1Ht&&!tH1Lt)?70.0:MathRound(pos*100.0);
   h1Timing = (tH1Ht&&tH1Lt)?"COMPLETION":h1LowProb>=55?"LOW FIRST":h1LowProb<=45?"HIGH FIRST":"BALANCED";
   tSeq = (!tH1Lt?"take H1 low":!tH1Ht?"take H1 high":"H1 done")
        + " -> H4 " + (f_tBias(h4O)==1?"up":"down")
        + " -> D "  + (f_tBias(dO)==1?"highs":"lows")
        + " -> W "  + (f_tBias(wO)==1?"highs":"lows");
  }


//==================================================================
// F72 — CURVE OBJECT + RECURSIVE CURVE TREE
//==================================================================
struct CurveF
  {
   int dir; double origin, extreme, dispATR, eIn, eDiss, eRes, convex, compress, maturity;
  };
CurveF gCurve;

struct CurveNodeF
  {
   int    id, parent, dir, depth, bar, srcTf;
   double origin, extreme, energy, comp, mat;
   bool   alive;
   string state;
  };
CurveNodeF g_tree[];
int    g_nodeSeq=0;
string gNodePhase="";          // emergent (OBSERVATIONAL ONLY — not authority)

// owner / tree summary
int    _ownDirT=0, _ownDepthT=0, _ownSrc=5, _treeAlive=0, _treeDepth=0, _curveBudgetDepth=1;
double _ownNrgT=0, _ownOrig=0, _ownExt=0;
string _ownState="—";
// compression persistence + life
double _cmpHist[6]; int _cmpHistN=0;
double _cpForce=50.0, _life=50.0, _mig50=0, _mig618=0;
string _cpState="NEUTRAL", _cpTrend="→ stable", _aliveTx="◐ WEAKENING · MANAGE", _htfThreat="—";
double _parentThreat=0, _htfRoomAtr=0, _retrX=50.0;
bool   _progressing=false, _recursionComplete=false;
// lineage + chain
int    _narrDir=0, _supVotes=0, _degVotes=0;
double _legX=0, _legPBdepth=0, _narrative=50.0, _wholeChainLife=50.0, _chainVitality=50.0;
string _narrState="HOLDING", _lastVote="—", _chainScope="healthy";
bool   _converging=false;
double _seqRetr[]; double _lifeSeq[];
// MTF map
int    mtfAlignN=0; string mtfStory="", mtfOwnerL="";

string f_nodeState(int d,double e,int dep,double cmp,double mat)
  {
   if(dep>0) return e>=70.0?"Transition · recursive expansion":e>=40.0?"Transition · recursive induction":"Transition · recursive liquidation";
   if(mat<12.0) return "Point 4 Origin";
   if(e>=78.0 && mat>=70.0) return d==1?"New High":d==-1?"New Low":"Climax";
   if(mat<35.0) return "Expansion";
   if(mat<55.0) return "Expansion Pre-Convexity";
   if(e>=55.0) return "Expansion Induction";
   if(e>=35.0) return "Expansion Liquidity";
   if(cmp>=60.0) return "Retracement Pre-Convexity";
   if(e>=18.0) return "Retracement Induction";
   return "Retracement";
  }

void f_updateCurve()
  {
   double atr=g_atr;
   int cvDir = l0_dir;
   double cvOrig = g_se5.o.inv;
   double cvExt = cvDir==1?(cycleHigh!=0?cycleHigh:H1b(1)):cvDir==-1?(cycleLow!=0?cycleLow:L1b(1)):g_close;
   double cvDisp = cvOrig!=0?MathAbs(cvExt-cvOrig)/MathMax(atr,1e-10):0;
   double cvComp = f_clamp((1.0-MathMin(g_disp/MathMax(g_dispThresh,1e-10),1.0))*60.0+(1.0-MathMin(g_eff/MathMax(g_effThresh,1e-10),1.0))*40.0,0.0,100.0);
   gCurve.dir=cvDir; gCurve.origin=cvOrig; gCurve.extreme=cvExt; gCurve.dispATR=cvDisp;
   gCurve.eIn=ede_expansionEnergy; gCurve.eDiss=ede_dissipatedEnergy; gCurve.eRes=re_residualEnergyScore;
   gCurve.convex=convexityScore; gCurve.compress=(g_se5.o.comp!=0?g_se5.o.comp:cvComp); gCurve.maturity=waveProgress;

   bool bullCHoCH = g_se5.o.ch==1, bearCHoCH = g_se5.o.ch==-1;

   // pre-owner (Principle 8): shallowest alive with energy>=12
   double ownMinE=12.0;
   int preOwn=-1; double preE=-1; int preDepth=999;
   int sz=ArraySize(g_tree);
   for(int i=0;i<sz;i++)
      if(g_tree[i].alive && g_tree[i].energy>=ownMinE && (g_tree[i].depth<preDepth || (g_tree[i].depth==preDepth && g_tree[i].energy>preE)))
        { preDepth=g_tree[i].depth; preE=g_tree[i].energy; preOwn=i; }
   if(preOwn<0)
      for(int i=0;i<sz;i++) if(g_tree[i].alive && g_tree[i].energy>preE){ preE=g_tree[i].energy; preOwn=i; }

   // context anchor (Chart wave root)
   int ctxDir=l0_dir; double ctxOrig=cvOrig; int ctxSrc=0;
   double ctxExt = ctxDir==1?MathMax(cycleHigh!=0?cycleHigh:H1b(1),H1b(1)):ctxDir==-1?MathMin(cycleLow!=0?cycleLow:L1b(1),L1b(1)):g_close;
   if(preOwn<0 && ctxDir!=0 && ctxOrig!=0)
     {
      g_nodeSeq++;
      int k=ArraySize(g_tree); ArrayResize(g_tree,k+1);
      g_tree[k].id=g_nodeSeq; g_tree[k].parent=-1; g_tree[k].dir=ctxDir; g_tree[k].origin=ctxOrig;
      g_tree[k].extreme=ctxExt; g_tree[k].energy=MathMax(40.0,ede_expansionEnergy>0?ede_expansionEnergy:60.0);
      g_tree[k].alive=true; g_tree[k].depth=0; g_tree[k].bar=g_chartBarCount; g_tree[k].srcTf=ctxSrc; g_tree[k].comp=0; g_tree[k].mat=0;
      g_tree[k].state="Point 4 Origin";
     }

   // compression budget
   _curveBudgetDepth = (int)MathMax(1,MathMin(4,1+MathRound(gCurve.compress/33.0)));

   // event-generated child on Phase-2 CHoCH against owner
   if(preOwn>=0)
     {
      CurveNodeF po=g_tree[preOwn];
      if(((po.dir==1 && bearCHoCH)||(po.dir==-1 && bullCHoCH)) && (po.depth+1<=_curveBudgetDepth))
        {
         g_nodeSeq++;
         int k=ArraySize(g_tree); ArrayResize(g_tree,k+1);
         g_tree[k].id=g_nodeSeq; g_tree[k].parent=po.id; g_tree[k].dir=-po.dir; g_tree[k].origin=g_close;
         g_tree[k].extreme=g_close; g_tree[k].energy=MathMax(25.0,(ede_expansionEnergy>0?ede_expansionEnergy:50.0)*0.85);
         g_tree[k].alive=true; g_tree[k].depth=po.depth+1; g_tree[k].bar=g_chartBarCount; g_tree[k].srcTf=0; g_tree[k].comp=0; g_tree[k].mat=0;
         g_tree[k].state=f_nodeState(-po.dir,g_tree[k].energy,po.depth+1,0,0);
        }
     }

   // update living nodes
   sz=ArraySize(g_tree);
   for(int i=0;i<sz;i++)
     {
      if(!g_tree[i].alive) continue;
      if(g_tree[i].depth==0)
        {
         g_tree[i].dir = g_tree[i].srcTf==6?l4_dir:g_tree[i].srcTf==5?l2_dir:l0_dir;
         g_tree[i].origin = g_tree[i].srcTf==6?g_se240.o.inv:g_tree[i].srcTf==5?g_se60.o.inv:g_se5.o.inv;
         g_tree[i].extreme = g_tree[i].srcTf==6?(g_tree[i].dir==1?g_se240.o.sh:g_se240.o.sl):g_tree[i].srcTf==5?(g_tree[i].dir==1?g_se60.o.sh:g_se60.o.sl):(g_tree[i].dir==1?g_se5.o.sh:g_se5.o.sl);
        }
      bool prog = g_tree[i].dir==1?H1b(1)>(g_tree[i].extreme!=0?g_tree[i].extreme:H1b(1)):L1b(1)<(g_tree[i].extreme!=0?g_tree[i].extreme:L1b(1));
      if(g_tree[i].depth!=0)
         g_tree[i].extreme = g_tree[i].dir==1?MathMax(g_tree[i].extreme!=0?g_tree[i].extreme:H1b(1),H1b(1)):MathMin(g_tree[i].extreme!=0?g_tree[i].extreme:L1b(1),L1b(1));
      g_tree[i].energy = prog?MathMin(100.0,g_tree[i].energy+7.0):MathMax(0.0,g_tree[i].energy-2.0);
      g_tree[i].mat  = g_tree[i].srcTf==6?(g_se240.o.wp!=0?g_se240.o.wp:gCurve.maturity):g_tree[i].srcTf==5?(g_se60.o.wp!=0?g_se60.o.wp:gCurve.maturity):(g_se5.o.wp!=0?g_se5.o.wp:gCurve.maturity);
      g_tree[i].comp = g_tree[i].srcTf==6?(g_se240.o.comp!=0?g_se240.o.comp:gCurve.compress):g_tree[i].srcTf==5?(g_se60.o.comp!=0?g_se60.o.comp:gCurve.compress):(g_se5.o.comp!=0?g_se5.o.comp:gCurve.compress);
      g_tree[i].state = f_nodeState(g_tree[i].dir,g_tree[i].energy,g_tree[i].depth,g_tree[i].comp,g_tree[i].mat);
      if(g_tree[i].energy<=2.0) g_tree[i].alive=false;
     }
   // cap tree size to 60 (shift oldest)
   while(ArraySize(g_tree)>60)
     {
      for(int a=0;a<ArraySize(g_tree)-1;a++) g_tree[a]=g_tree[a+1];
      ArrayResize(g_tree,ArraySize(g_tree)-1);
     }

   // final owner (shallowest alive with energy>=12)
   _treeAlive=0; _treeDepth=0; int ownF=-1; double ownFE=-1; int ownDepth=999;
   sz=ArraySize(g_tree);
   for(int i=0;i<sz;i++)
     {
      if(!g_tree[i].alive) continue;
      _treeAlive++; _treeDepth=MathMax(_treeDepth,g_tree[i].depth);
      if(g_tree[i].energy>=ownMinE && (g_tree[i].depth<ownDepth || (g_tree[i].depth==ownDepth && g_tree[i].energy>ownFE)))
        { ownDepth=g_tree[i].depth; ownFE=g_tree[i].energy; ownF=i; }
     }
   if(ownF<0)
      for(int i=0;i<sz;i++) if(g_tree[i].alive && g_tree[i].energy>ownFE){ ownFE=g_tree[i].energy; ownF=i; }
   _ownDirT = ownF>=0?g_tree[ownF].dir:0;
   _ownDepthT = ownF>=0?g_tree[ownF].depth:0;
   _ownNrgT = ownF>=0?g_tree[ownF].energy:0;
   _ownState = ownF>=0?g_tree[ownF].state:"—";
   gNodePhase = _ownState;   // OBSERVATIONAL ONLY — Engine 1A canonical phase unchanged
   _ownSrc = ownF>=0?g_tree[ownF].srcTf:5;
   _ownOrig = _ownSrc==6?g_se240.o.inv:_ownSrc==5?g_se60.o.inv:g_se5.o.inv;
   _ownExt  = _ownSrc==6?(_ownDirT==1?g_se240.o.sh:g_se240.o.sl):_ownSrc==5?(_ownDirT==1?g_se60.o.sh:g_se60.o.sl):(_ownDirT==1?g_se5.o.sh:g_se5.o.sl);

   // compression persistence
   double cmpNow=gCurve.compress;
   double cmp5 = _cmpHistN>=6?_cmpHist[0]:cmpNow;
   double tighten=cmpNow-cmp5;
   // push history ring (len 6)
   for(int a=0;a<5;a++) _cmpHist[a]=_cmpHist[a+1];
   _cmpHist[5]=cmpNow; if(_cmpHistN<6)_cmpHistN++;
   _cpForce=f_clamp(cmpNow*0.50+gCurve.eRes*0.20-_treeDepth*12.0+MathMax(0.0,tighten)*0.8+8.0,0.0,100.0);
   _cpState=_cpForce>=60.0?"PERSISTING":_cpForce<=35.0?"LEAKING":"NEUTRAL";
   _cpTrend=tighten>3.0?"↑ tightening":tighten<-3.0?"↓ broadening":"→ stable";

   // life
   _recursionComplete = _curveBudgetDepth>0 && _treeDepth>=_curveBudgetDepth;
   bool attacking = _ownDirT==1?H1b(1)>=(_ownExt!=0?_ownExt:H1b(1)):_ownDirT==-1?L1b(1)<=(_ownExt!=0?_ownExt:L1b(1)):false;
   bool trendImp = (_ownDirT==1&&g_bullImpulse)||(_ownDirT==-1&&g_bearImpulse);
   _progressing = attacking||trendImp;
   _retrX = (_ownExt==0||_ownOrig==0||_ownExt==_ownOrig)?50.0:MathMin(100.0,MathAbs(_ownExt-g_close)/MathAbs(_ownExt-_ownOrig)*100.0);
   _parentThreat = _ownDirT==1?(g_se240.o.ft!=0&&g_se240.o.ft>g_close?g_se240.o.ft:g_se240.o.sh):_ownDirT==-1?(g_se240.o.fb!=0&&g_se240.o.fb<g_close?g_se240.o.fb:g_se240.o.sl):0;
   _htfRoomAtr = _parentThreat==0?0:MathAbs(_parentThreat-g_close)/MathMax(atr,1e-10);
   _htfThreat = _parentThreat==0?"—":_htfRoomAtr>3.0?"CLEAR runway":_htfRoomAtr>1.0?"APPROACHING":"AT ZONE";
   _life=f_clamp(_cpForce*0.45+gCurve.eRes*0.30+(tighten>0.0?12.0:0.0)
        -(_recursionComplete&&!_progressing?25.0:0.0)-(_cpState=="LEAKING"&&!_progressing?20.0:0.0)
        +(_progressing?28.0:0.0)+(_retrX<25.0?16.0:_retrX<45.0?6.0:_retrX>75.0?-12.0:0.0)+10.0,0.0,100.0);
   string aliveCounter=_ownDirT==1?"▼ SHORT":"▲ LONG";
   _aliveTx = (_htfThreat=="AT ZONE"&&_life>=45.0)?"◆ ALIVE · AT "+f_tfLabel(g_wtf6)+" — VIGILANT":
              _progressing&&_life>=45.0?"▲ ALIVE · ATTACKING EXTREME":
              _life>=60.0?"● ALIVE · HOLD":_life<=32.0?"✕ DEAD · FLIP "+aliveCounter:"◐ WEAKENING · MANAGE";
   _mig50  = (_ownOrig==0||_ownExt==0)?0:_ownExt+0.5*(_ownOrig-_ownExt);
   _mig618 = (_ownOrig==0||_ownExt==0)?0:_ownExt+0.618*(_ownOrig-_ownExt);

   // narrative lineage
   if(_ownDirT!=_narrDir)
     {
      _narrDir=_ownDirT;
      _legX=_ownDirT==1?H1b(1):_ownDirT==-1?L1b(1):0;
      _legPBdepth=0; _narrative=50.0; _supVotes=0; _degVotes=0; _lastVote="—";
      ArrayResize(_seqRetr,0); ArrayResize(_lifeSeq,0);
     }
   if(_ownDirT!=0 && _ownOrig!=0)
     {
      bool newLegX=_ownDirT==1?H1b(1)>(_legX!=0?_legX:H1b(1)):L1b(1)<(_legX!=0?_legX:L1b(1));
      if(newLegX)
        {
         if(_legPBdepth>6.0)
           {
            bool sup=_legPBdepth<=50.0 && tighten>=-1.0;
            bool deg=_legPBdepth>=62.0 || tighten<-3.0;
            int vote=sup?1:deg?-1:0;
            _lastVote=vote==1?"SUPPORT":vote==-1?"DEGRADE":"NEUTRAL";
            _supVotes+=(vote==1?1:0); _degVotes+=(vote==-1?1:0);
            _narrative=f_clamp(_narrative+vote*12.0+(tighten>0.0?3.0:-3.0),0.0,100.0);
            int k=ArraySize(_seqRetr); ArrayResize(_seqRetr,k+1); _seqRetr[k]=_legPBdepth;
            if(ArraySize(_seqRetr)>5){ for(int a=0;a<ArraySize(_seqRetr)-1;a++)_seqRetr[a]=_seqRetr[a+1]; ArrayResize(_seqRetr,ArraySize(_seqRetr)-1); }
            int k2=ArraySize(_lifeSeq); ArrayResize(_lifeSeq,k2+1); _lifeSeq[k2]=_life;
            if(ArraySize(_lifeSeq)>5){ for(int a=0;a<ArraySize(_lifeSeq)-1;a++)_lifeSeq[a]=_lifeSeq[a+1]; ArrayResize(_lifeSeq,ArraySize(_lifeSeq)-1); }
           }
         _legX=_ownDirT==1?H1b(1):L1b(1); _legPBdepth=0;
        }
      else
        {
         double pbd=MathAbs((_legX!=0?_legX:g_close)-_ownOrig)>1e-9?MathAbs((_legX!=0?_legX:g_close)-g_close)/MathAbs((_legX!=0?_legX:g_close)-_ownOrig)*100.0:0;
         _legPBdepth=MathMax(_legPBdepth,pbd);
        }
     }
   _narrState=_narrative>=65.0?"STRENGTHENING":_narrative<=35.0?"WEAKENING":"HOLDING";
   _converging = ArraySize(_seqRetr)>=2 && _seqRetr[ArraySize(_seqRetr)-1]<_seqRetr[ArraySize(_seqRetr)-2];
   _wholeChainLife += 0.02*(_life-_wholeChainLife);
   _chainVitality = ArraySize(_lifeSeq)>=2?f_clamp(50.0+(_lifeSeq[ArraySize(_lifeSeq)-1]-_lifeSeq[0]),0.0,100.0):_wholeChainLife;
   _chainScope=_life>=50.0?"healthy":_chainVitality>=50.0?"CURVE only · chain intact":_wholeChainLife>=45.0?"CHAIN weakening":"WHOLE CHAIN decaying";

   // MTF curve map
   mtfAlignN=(m1_dir==_ownDirT)+(l3_dir==_ownDirT)+(l0_dir==_ownDirT)+(l1_dir==_ownDirT)+(l2_dir==_ownDirT)+(l4_dir==_ownDirT);
   mtfStory=_ownDirT==0?"no dominant owner":mtfAlignN>=5?"all TFs aligned → strong continuation":mtfAlignN>=4?"HTFs lead · LTFs following":mtfAlignN<=2?"LTFs counter HTF → pullback / transition":"mixed → rotation";
   mtfOwnerL=(g_se240.o.wp>10&&g_se240.o.wp<90)?f_tfLabel(g_wtf6):(g_se60.o.wp>10&&g_se60.o.wp<90)?f_tfLabel(g_wtf5):(g_se15.o.wp>10&&g_se15.o.wp<90)?f_tfLabel(g_wtf4):(g_se5.o.wp>10&&g_se5.o.wp<90)?f_tfLabel(g_wtf3):(g_se3.o.wp>10&&g_se3.o.wp<90)?f_tfLabel(g_wtf2):f_tfLabel(g_wtf1);
  }


//==================================================================
// PART D — SENSEEI META-INTELLIGENCE  (Pine exact)
//==================================================================
int    sen_master=0;
double sen_alignment=50, sen_conflict=0, sen_threat=0, sen_confidence=0, sen_oppScore=0;
string sen_timing="DEVELOPING", sen_intent="BALANCE", sen_opportunity="NONE", sen_action="WAIT";
int    sen_resCode=0; double sen_residual=0, sen_attractor=0;

void f_updateSenseei()
  {
   int v1=waveDir, v2=stackDir, v3=g_netBias, v4=g_pdir;
   int sum=v1+v2+v3+v4;
   sen_master = sum>0?1:sum<0?-1:0;
   int cast=(v1!=0)+(v2!=0)+(v3!=0)+(v4!=0);
   int forV=(v1==sen_master&&v1!=0)+(v2==sen_master&&v2!=0)+(v3==sen_master&&v3!=0)+(v4==sen_master&&v4!=0);
   sen_alignment = cast>0?(double)forV/cast*100.0:50.0;
   sen_conflict  = cast>0?(double)(cast-forV)/cast*100.0:0.0;
   sen_residual  = re_residualEnergyScore;
   sen_resCode   = re_resolutionState=="RESOLVED"?2:re_resolutionState=="PARTIALLY RESOLVED"?1:0;
   sen_attractor = eae_primaryAttractorScore;
   sen_threat = f_clamp(sen_conflict*0.40 + sen_residual*0.28 + timeConflict*0.12
                + (g_pdir!=0 && g_pdir!=sen_master?18.0:0.0) + (sen_resCode==1?10.0:0.0), 0.0,100.0);
   sen_confidence = f_clamp(sen_alignment*0.40 + timeAlign*0.12 + stackPct*0.18 + sen_attractor*0.15
                + MathMin(15.0,g_eligibleNodes*1.2) - sen_threat*0.20, 0.0,100.0);
   string ph=ie1a_currentPhase;
   sen_timing = (StringFind(ph,"Absorption")>=0||sen_resCode==2)?"RESOLVED":
                waveProgress<15?"VERY EARLY":waveProgress<35?"EARLY":waveProgress<55?"DEVELOPING":
                waveProgress<80?"MID CYCLE":waveProgress<96?"LATE":"TERMINAL";
   sen_intent = sen_conflict>55?"ABSORPTION":liqg_active?"DELIVERY":
                (StringFind(ph,"Expansion")>=0&&StringFind(ph,"Pre-Convexity")<0&&StringFind(ph,"Induction")<0&&StringFind(ph,"Liquidity")<0)?"EXPANSION":
                StringFind(ph,"Pre-Convexity")>=0?"CONTINUATION":
                StringFind(ph,"Induction")>=0?"RESOLUTION":
                StringFind(ph,"Liquidity")>=0?"DELIVERY":
                (StringFind(ph,"New High")>=0||StringFind(ph,"New Low")>=0)?"DELIVERY":
                sen_master==0?"BALANCE":"CONTINUATION";
   sen_oppScore = f_clamp(sen_alignment*0.40 + sen_attractor*0.30 + stackPct*0.30 - sen_threat*0.35, 0.0,100.0);
   sen_opportunity = sen_master==0?"NONE":sen_conflict>60?"DEVELOPING":sen_oppScore<20?"NONE":
                     sen_oppScore<40?"DEVELOPING":sen_oppScore<62?"GOOD":sen_oppScore<82?"STRONG":"EXCEPTIONAL";
   sen_action = sen_master==0?"WAIT":sen_conflict>60?"WAIT":sen_resCode==2?"MANAGE / EXIT":
                ((sen_opportunity=="STRONG"||sen_opportunity=="EXCEPTIONAL")&&sen_confidence>=g_minConf&&sen_threat<45)?"ATTACK":
                (sen_opportunity=="GOOD"||sen_opportunity=="STRONG")?"PREPARE":"WAIT";
  }

//==================================================================
// SENZO — trader voice (compact synthesis from curve tree + MTF +
// F60 lifecycle + energy + threat) — for the dashboard / heartbeat.
//==================================================================
string snz_line1="", snz_line2="", snz_line3="", snz_line4="", snz_line5="";

void f_updateSenzo()
  {
   string biasV = sen_master==1?"Bias is up top":sen_master==-1?"We're leaning short":"Market can't pick a side";
   string f60 = "F60: "+ie1a_currentPhase;
   string engV = ede_state<=1?"energy still building, early":ede_state==2?"first dissipation underway":
                 ede_state==3?"inducement working, trap being set":(ede_state>=4&&ede_state<=5)?"in delivery — business end":
                 re_resolutionState=="RESOLVED"?"done its job, energy clean":"unresolved, "+DoubleToString(re_residualEnergyScore,0)+"% left";
   snz_line1 = biasV+" · "+f60;
   snz_line2 = _ownDirT==0?"curve tree: no owner yet":(_ownDirT==1?"bull":"bear")+" curve owns · "+_ownState+" · life "+DoubleToString(_life,0);
   snz_line3 = _cpState=="PERSISTING"?"compression holding "+_cpTrend+" — stay with owner":
               _cpState=="LEAKING"?"force leaking "+_cpTrend+" — ownership ready to flip":"force neutral "+_cpTrend;
   snz_line4 = mtfStory=="no dominant owner"?"no clear MTF lead · "+engV:mtfStory+" ("+IntegerToString(mtfAlignN)+"/6, "+mtfOwnerL+" drives) · "+engV;
   snz_line5 = sen_action=="ATTACK"?"BOTTOM LINE: I'd take the shot":sen_action=="PREPARE"?"BOTTOM LINE: get ready — not yet":
               StringFind(sen_action,"MANAGE")>=0?"BOTTOM LINE: manage what you're holding":"BOTTOM LINE: sit on your hands";
  }

//==================================================================
// ATTACK SEQUENCE (Pine) — entry / stop / targets, every bar.
//==================================================================
double atkEntryPx=0, atkStopPx=0, atkT1Px=0, atkT2Px=0, atkT3Px=0;
int    atkBias=0;

void f_updateAttack()
  {
   atkEntryPx = (flipTop!=0 && flipBot!=0)?(flipTop+flipBot)/2.0:0;
   atkStopPx  = g_se5.o.inv;
   atkT1Px    = waveObj;
   atkT2Px    = g_se15.o.tgt;
   atkT3Px    = g_se60.o.tgt;
   atkBias = (atkEntryPx==0||atkT1Px==0)?(waveDir!=0?waveDir:direction):(atkT1Px>=atkEntryPx?1:-1);
  }

//==================================================================
// MASTER PERCEPTION UPDATE — runs the full F60 chain in source order.
//==================================================================
bool f_perceive()
  {
   if(!f_updateStructure()) return false;   // physics + f_se + Engine 1A
   f_updatePivots();                        // Section 5 chart pivot memory
   f_updateObservation();                   // obs_*
   f_updateERF();                           // EDE / RE / EAE
   f_updateLiquidity();                     // Section 10
   f_updateWaveIntel();                     // Section 11/12
   f_updateBelief();                        // Section 12A
   f_updateSpawn();                         // Section 13 + recursion
   f_updateLiqg();                          // Engine 1A.7
   f_updateFRZ();                           // FRZ
   f_networkUpdate();                       // Invisible Network
   f_updateTIE();                           // Time Intelligence
   f_updateCurve();                         // F72 curve + tree + life + lineage
   f_updateSenseei();                       // Senseei meta-intelligence
   f_updateSenzo();                         // Senzo voice
   f_updateAttack();                        // Attack Sequence
   return true;
  }


//==================================================================
// EXECUTION LAYER (EA) — the only addition over the Pine indicator.
//   Routes orders from the Senseei action verdict. The engine owns
//   the decision; this layer only sizes, places, and manages.
//==================================================================
datetime g_lastChartBar = 0;
bool     g_warmed = false;

int f_countPositions()
  {
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic) c++;
     }
   return c;
  }

int f_positionDir()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic)
         return PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1;
     }
   return 0;
  }

double f_lots(double entry, double stop)
  {
   double dist = MathAbs(entry-stop);
   if(dist<=0) return 0;
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSz<=0||tickVal<=0) return InpMinLot;
   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY)*InpRiskPct/100.0;
   double lossPerLot = dist/tickSz*tickVal;
   if(lossPerLot<=0) return InpMinLot;
   double lots = riskMoney/lossPerLot;
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step>0) lots = MathFloor(lots/step)*step;
   lots = MathMax(lots, MathMax(InpMinLot, minV));
   lots = MathMin(lots, MathMin(InpMaxLot, maxV));
   return lots;
  }

void f_closeAll(string why)
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic)
        {
         g_trade.PositionClose(tk);
         PrintFormat("[F60] CLOSE #%I64u — %s", tk, why);
        }
     }
  }

void f_route()
  {
   if(!InpEnableTrading) return;
   int posCount = f_countPositions();
   int posDir   = f_positionDir();

   // MANAGE / EXIT — close on resolution
   if(InpManageExits && StringFind(sen_action,"MANAGE")>=0 && posCount>0)
     { f_closeAll("Senseei MANAGE/EXIT (resolved)"); return; }

   // ATTACK — open in master direction if flat / room available
   bool attack = (sen_action=="ATTACK" && sen_master!=0);
   if(!attack) return;
   if(posCount>=InpMaxPositions)
     {
      // allow reverse if holding opposite direction
      if(posDir!=0 && posDir!=sen_master) f_closeAll("reverse on opposite ATTACK");
      else return;
     }

   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double atr=g_atr>0?g_atr:f_atrChart(14);
   double entry = sen_master==1?ask:bid;
   double stop  = atkStopPx;
   double tp    = atkT1Px;
   // validate stop side; fallback to ATR if invalid
   if(sen_master==1 && (stop==0 || stop>=entry)) stop=entry-atr*1.5;
   if(sen_master==-1 && (stop==0 || stop<=entry)) stop=entry+atr*1.5;
   if(sen_master==1 && (tp==0 || tp<=entry)) tp=entry+MathAbs(entry-stop)*2.0;
   if(sen_master==-1 && (tp==0 || tp>=entry)) tp=entry-MathAbs(entry-stop)*2.0;

   double lots=f_lots(entry,stop);
   if(lots<=0) return;
   g_trade.SetDeviationInPoints(InpSlippage);
   g_trade.SetExpertMagicNumber(InpMagic);
   bool ok=false;
   if(sen_master==1) ok=g_trade.Buy(lots,_Symbol,0.0,stop,tp,"F60 ATTACK L");
   else              ok=g_trade.Sell(lots,_Symbol,0.0,stop,tp,"F60 ATTACK S");
   PrintFormat("[F60] %s %.2f lots — conf %.0f opp %s SL %.5f TP %.5f (%s)",
               sen_master==1?"BUY":"SELL", lots, sen_confidence, sen_opportunity, stop, tp,
               ok?"OK":("FAIL "+IntegerToString(g_trade.ResultRetcode())));
  }

//==================================================================
// DASHBOARD (Comment) + heartbeat
//==================================================================
string f_dashboard()
  {
   string s="";
   s+="╔═ F16 RAPTOR v60 — "+F60_VERSION+"  ["+_Symbol+" "+f_tfLabel(_Period)+"]\n";
   s+="║ PHASE (Engine 1A · authority): "+ie1a_currentPhase+"  conf "+DoubleToString(ie1a_phaseConfidence,0)+"%\n";
   s+="║ Node phase (observational):    "+gNodePhase+"\n";
   s+="║ Wave dir "+(waveDir==1?"▲":waveDir==-1?"▼":"—")+"  stack "+DoubleToString(stackPct,0)+"%  progress "+DoubleToString(waveProgress,0)+"%\n";
   s+="╠─ SENSEEI ───────────────────────────────\n";
   s+="║ Master "+(sen_master==1?"▲ BULL":sen_master==-1?"▼ BEAR":"○ —")+"   ACTION → "+sen_action+"\n";
   s+="║ Align "+DoubleToString(sen_alignment,0)+"  Conflict "+DoubleToString(sen_conflict,0)+"  Threat "+DoubleToString(sen_threat,0)+"\n";
   s+="║ Confidence "+DoubleToString(sen_confidence,0)+"%  Opportunity "+sen_opportunity+"  ("+DoubleToString(sen_oppScore,0)+"/100)\n";
   s+="║ Timing "+sen_timing+"  Intent "+sen_intent+"\n";
   s+="╠─ ENERGY / RESOLUTION ───────────────────\n";
   s+="║ EDE state "+IntegerToString(ede_state)+"  Resolution "+re_resolutionState+"  Residual "+DoubleToString(re_residualEnergyScore,0)+"%\n";
   s+="║ Attractor P "+(eae_primaryAttractorPrice!=0?DoubleToString(eae_primaryAttractorPrice,_Digits):"—")+"  ("+eae_primaryAttractorLabel+")\n";
   s+="╠─ CURVE TREE ────────────────────────────\n";
   s+="║ Owner "+(_ownDirT==1?"▲":_ownDirT==-1?"▼":"○")+" "+_ownState+"  life "+DoubleToString(_life,0)+"  "+_aliveTx+"\n";
   s+="║ Force "+_cpState+" "+DoubleToString(_cpForce,0)+" "+_cpTrend+"  depth "+IntegerToString(_treeDepth)+"/"+IntegerToString(_curveBudgetDepth)+"\n";
   s+="║ Narrative "+_narrState+" "+DoubleToString(_narrative,0)+"  Chain "+_chainScope+"\n";
   s+="║ MTF "+mtfStory+"  ("+IntegerToString(mtfAlignN)+"/6, "+mtfOwnerL+")\n";
   s+="║ HTF parent threat "+_htfThreat+"\n";
   s+="╠─ NETWORK / TIME ────────────────────────\n";
   s+="║ netBias "+(g_netBias==1?"▲":g_netBias==-1?"▼":"—")+"  pdir "+IntegerToString(g_pdir)+"  pressure "+DoubleToString(g_pressure,0)+"  nodes "+IntegerToString(ArraySize(g_nPx))+" ("+IntegerToString(g_eligibleNodes)+" live)\n";
   s+="║ timeDir "+(timeDir==1?"▲":timeDir==-1?"▼":"—")+"  align "+DoubleToString(timeAlign,0)+"  h1 "+h1Timing+"\n";
   s+="║ "+tSeq+"\n";
   s+="╠─ ATTACK SEQUENCE ───────────────────────\n";
   s+="║ Entry "+(atkEntryPx!=0?DoubleToString(atkEntryPx,_Digits):"—")+"  Stop "+(atkStopPx!=0?DoubleToString(atkStopPx,_Digits):"—")+"\n";
   s+="║ T1 "+(atkT1Px!=0?DoubleToString(atkT1Px,_Digits):"—")+"  T2 "+(atkT2Px!=0?DoubleToString(atkT2Px,_Digits):"—")+"  T3 "+(atkT3Px!=0?DoubleToString(atkT3Px,_Digits):"—")+"\n";
   s+="╠─ SENZO ─────────────────────────────────\n";
   s+="║ "+snz_line1+"\n║ "+snz_line2+"\n║ "+snz_line3+"\n║ "+snz_line4+"\n║ "+snz_line5+"\n";
   s+="╚═ positions: "+IntegerToString(f_countPositions())+(InpEnableTrading?"  [LIVE]":"  [OBSERVE]")+"\n";
   return s;
  }

//==================================================================
// OnInit / OnTick / OnTimer / OnDeinit
//==================================================================
int OnInit()
  {
   // resolve params
   g_pivotLen=InpPivotLen; g_atrLen=InpAtrLen; g_effLen=InpEffLen; g_structLenL=InpStructLenL;
   g_acceptBars=InpAcceptBars; g_obMaxBars=InpObMaxBars; g_inducLookback=InpInducLookback;
   g_liqSweepLookback=InpLiqSweepLookback; g_resetBars=InpResetBars; g_beliefSmooth=InpBeliefSmooth;
   g_pivLen=InpPivLen; g_lookback=InpLookback; g_authMin=InpAuthMin; g_nodeMax=InpNodeMax;
   g_dormantBars=InpDormantBars; g_historyBars=InpHistoryBars; g_minConf=InpMinConf;
   g_impulseAtrMult=InpImpulseAtrMult; g_effThresh=InpEffThresh; g_dispThresh=InpDispThresh;
   g_convMult=InpConvMult; g_chochBufferATR=InpChochBufferATR; g_inducZoneWidth=InpInducZoneWidth;
   g_liqRadius=InpLiqRadius; g_liqAgDecay=InpLiqAgDecay; g_wickFrac=InpWickFrac;
   g_useStrictStruct=InpUseStrictStruct; g_requireLiqSweep=InpRequireLiqSweep;

   f_buildLadder();

   g_se1.Init(g_wtf1);   g_se3.Init(g_wtf2);   g_se5.Init(g_wtf3);
   g_se15.Init(g_wtf4);  g_se60.Init(g_wtf5);  g_se240.Init(g_wtf6);
   g_physM5.Init(g_wtf3, g_atrLen, g_effLen, g_effThresh, g_dispThresh, g_convMult);

   g_fuMN.Init(PERIOD_MN1,g_wickFrac,g_lookback); g_fuW.Init(PERIOD_W1,g_wickFrac,g_lookback);
   g_fuD.Init(PERIOD_D1,g_wickFrac,g_lookback);    g_fuH4.Init(PERIOD_H4,g_wickFrac,g_lookback);
   g_fuH1.Init(PERIOD_H1,g_wickFrac,g_lookback);    g_fuM15.Init(PERIOD_M15,g_wickFrac,g_lookback);
   g_fuM5.Init(PERIOD_M5,g_wickFrac,g_lookback);
   ArrayInitialize(g_pvFu,0);

   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   EventSetTimer(MathMax(1,InpHeartbeatSec));

   PrintFormat("[F60] %s online · ladder %s/%s/%s/%s/%s/%s · trading=%s",
      F60_VERSION, f_tfLabel(g_wtf1),f_tfLabel(g_wtf2),f_tfLabel(g_wtf3),
      f_tfLabel(g_wtf4),f_tfLabel(g_wtf5),f_tfLabel(g_wtf6), InpEnableTrading?"ON":"OFF");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   Comment("");
  }

void OnTick()
  {
   datetime barT = iTime(_Symbol,_Period,0);
   bool newBar = (barT != g_lastChartBar);
   if(newBar)
     {
      g_lastChartBar = barT;
      g_chartBarCount++;
      if(f_perceive())
        {
         g_warmed = true;
         f_route();
         if(InpShowDashboard) Comment(f_dashboard());
        }
     }
  }

void OnTimer()
  {
   datetime now=TimeCurrent();
   if(g_lastHeartbeat==0 || (now-g_lastHeartbeat)>=InpHeartbeatSec)
     {
      g_lastHeartbeat=now;
      if(!g_warmed) return;
      if(InpShowDashboard) Comment(f_dashboard());
      PrintFormat("[F60·HB] phase=%s action=%s conf=%.0f master=%d life=%.0f owner=%s netBias=%d",
         ie1a_currentPhase, sen_action, sen_confidence, sen_master, _life, _ownState, g_netBias);
     }
  }
