//+------------------------------------------------------------------+
//|                                                Participants.mqh  |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 13 + 14 — orchestrator.                                  |
//|                                                                  |
//|   Owns one ParticipantEngine and one FlipEngine. Runs both per   |
//|   closed bar and emits a single composite snapshot for the       |
//|   heartbeat. Writes participantStability and flipQuality into    |
//|   OmegaSupporting so downstream layers (Risk, DecisionEngine)    |
//|   can read them.                                                 |
//+------------------------------------------------------------------+
#ifndef __OMEGA_PARTICIPANTS_MQH__
#define __OMEGA_PARTICIPANTS_MQH__

#include "ParticipantEngine.mqh"
#include "FlipEngine.mqh"
#include "../Memory.mqh"
#include "../Curve/Curve.mqh"

class OmegaParticipants
  {
public:
   ParticipantEngine fib;        // 0.618 / 0.70 / 0.786 retracement zones
   FlipEngine        flip;       // FU candle / flip zones

   string            symbol;
   datetime          lastBarTime;
   long              barsProcessed;

                     OmegaParticipants()
     {
      symbol = "";
      lastBarTime = 0;
      barsProcessed = 0;
     }

   void Init(string sym)
     {
      symbol = sym;
      fib.Init(sym);
      flip.Init(sym);
      OmegaLogger::LogInfo("PARTICIPANTS",
         StringFormat("Init %s · ParticipantEngine + FlipEngine wired", sym));
     }

   void Reset()
     {
      fib.Reset();
      flip.Reset();
      lastBarTime = 0;
      barsProcessed = 0;
     }

   //--- runs after curve+tree, before meta. One advance per closed bar.
   bool Update(OmegaCurve &curve, OmegaState &state)
     {
      bool a = fib.Update(curve);
      bool b = flip.Update(curve);
      bool advanced = (a || b);
      if(advanced)
        {
         barsProcessed++;
         CurveState *chart = curve.ChartTfState();
         if(chart != NULL) lastBarTime = chart.lastBarTime;

         //--- write into supporting fields
         state.supporting.participantStability = fib.Stability();
         state.supporting.flipQuality          = flip.Quality();
        }
      return advanced;
     }

   string Snapshot() const
     {
      return StringFormat("%s · %s", fib.Snapshot(), flip.Snapshot());
     }
  };

#endif // __OMEGA_PARTICIPANTS_MQH__
