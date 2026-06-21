//+------------------------------------------------------------------+
//|                                              ParticipantZone.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 13 — atomic zone primitive shared by ParticipantEngine   |
//|   (Fibonacci: 0.618 / 0.70 / 0.786) and FlipEngine (FU spikes).  |
//|                                                                  |
//|   Each zone is a price band with a tolerance, a touch counter,   |
//|   reaction counter, violation counter, and an age. Engines       |
//|   update zones per closed bar; the zone itself owns the state    |
//|   transitions:                                                   |
//|                                                                  |
//|     UNTESTED → TOUCHED → REACTED        (good: participants held)|
//|     UNTESTED → TOUCHED → VIOLATED       (bad: zone invalidated)  |
//|     UNTESTED → EXPIRED  (no touch within ageLimit)               |
//+------------------------------------------------------------------+
#ifndef __OMEGA_PARTICIPANT_ZONE_MQH__
#define __OMEGA_PARTICIPANT_ZONE_MQH__

#include "../Common.mqh"

//=== zone type taxonomy =============================================
enum ENUM_ZONE_TYPE
  {
   ZONE_TYPE_NONE      = 0,
   ZONE_TYPE_FIB_618   = 1,   // 0.618 retracement
   ZONE_TYPE_FIB_70    = 2,   // 0.70 interference
   ZONE_TYPE_FIB_786   = 3,   // 0.786 heavy
   ZONE_TYPE_FU_FLIP   = 4,   // FU candle flip zone
   ZONE_TYPE_TRUE_IND  = 5    // lowest active flip — "true induction"
  };

//=== zone state machine ============================================
enum ENUM_ZONE_STATE
  {
   ZONE_UNTESTED   = 0,
   ZONE_TOUCHED    = 1,
   ZONE_REACTED    = 2,
   ZONE_VIOLATED   = 3,
   ZONE_EXPIRED    = 4
  };

//=== one zone =======================================================
struct ParticipantZone
  {
   //--- identity
   ENUM_ZONE_TYPE   type;
   int              direction;       // +1 bull defence / -1 bear defence
   //--- geometry
   double           price;           // central price
   double           tolerance;       // ± half-band (price units, typically 0.25*ATR)
   //--- state
   ENUM_ZONE_STATE  state;
   int              touchCount;
   int              reactionCount;
   int              violationCount;
   //--- lifecycle
   datetime         born;
   datetime         lastTouch;
   datetime         expired;
   int              ageBars;
   bool             active;          // true while it can still trigger updates

                     ParticipantZone() { Reset(); }

   void Reset()
     {
      type = ZONE_TYPE_NONE; direction = 0;
      price = 0; tolerance = 0;
      state = ZONE_UNTESTED;
      touchCount = reactionCount = violationCount = 0;
      born = lastTouch = expired = 0;
      ageBars = 0;
      active = false;
     }

   void Init(ENUM_ZONE_TYPE t, int dir, double px, double tol)
     {
      Reset();
      type      = t;
      direction = dir;
      price     = px;
      tolerance = tol;
      born      = TimeCurrent();
      active    = true;
     }

   //--- low/high of the band
   double Lower() const { return price - tolerance; }
   double Upper() const { return price + tolerance; }

   //--- did this bar touch the band?
   bool BarTouches(double barHigh, double barLow) const
     {
      return barHigh >= Lower() && barLow <= Upper();
     }

   //--- did this bar's CLOSE violate the zone (move beyond it in
   //    the direction the zone was supposed to defend against)?
   //    For a bull-defending zone (direction == 1), violation = close < Lower()
   //    For a bear-defending zone (direction == -1), violation = close > Upper()
   bool CloseViolates(double barClose) const
     {
      if(direction == 1)  return barClose < Lower();
      if(direction == -1) return barClose > Upper();
      return false;
     }

   //--- update on a closed bar. Returns true if state advanced.
   //    `reactDistATR` is how far price needs to move away from the band
   //    after touching to count as a reaction (typically 0.5 * ATR).
   bool Update(double barHigh, double barLow, double barClose, double atr)
     {
      if(!active) return false;
      ageBars++;
      bool advanced = false;
      bool touched  = BarTouches(barHigh, barLow);
      double reactDist = atr * 0.5;

      //--- violation FIRST — close beyond the zone invalidates it
      if(CloseViolates(barClose))
        {
         violationCount++;
         state   = ZONE_VIOLATED;
         active  = false;
         expired = TimeCurrent();
         return true;
        }

      if(touched)
        {
         touchCount++;
         lastTouch = TimeCurrent();
         if(state == ZONE_UNTESTED) { state = ZONE_TOUCHED; advanced = true; }
        }

      //--- reaction: previously touched, now price has moved away by reactDist
      if(state == ZONE_TOUCHED && !touched)
        {
         double awayDist = (direction == 1) ? (barLow - Upper()) : (Lower() - barHigh);
         if(awayDist >= reactDist)
           {
            reactionCount++;
            state    = ZONE_REACTED;
            advanced = true;
           }
        }
      return advanced;
     }

   //--- 0..100 score: how WELL has this zone defended?
   //    Touches without violation = good; reactions = best; violations = bad.
   double DefenceScore() const
     {
      double s = 50.0;
      s += reactionCount * 12.0;
      s += touchCount    * 4.0;
      s -= violationCount * 30.0;
      return OmegaMath::Clamp(s, 0.0, 100.0);
     }

   //--- age-based expiry helper
   void ExpireIfOld(int maxAgeBars)
     {
      if(active && ageBars > maxAgeBars)
        {
         state   = ZONE_EXPIRED;
         active  = false;
         expired = TimeCurrent();
        }
     }

   string TypeString() const
     {
      switch(type)
        {
         case ZONE_TYPE_FIB_618:   return "0.618";
         case ZONE_TYPE_FIB_70:    return "0.70";
         case ZONE_TYPE_FIB_786:   return "0.786";
         case ZONE_TYPE_FU_FLIP:   return "FLIP";
         case ZONE_TYPE_TRUE_IND:  return "TRUE_IND";
        }
      return "?";
     }

   string StateString() const
     {
      switch(state)
        {
         case ZONE_UNTESTED:  return "UNTESTED";
         case ZONE_TOUCHED:   return "TOUCHED";
         case ZONE_REACTED:   return "REACTED";
         case ZONE_VIOLATED:  return "VIOLATED";
         case ZONE_EXPIRED:   return "EXPIRED";
        }
      return "?";
     }

   string Snapshot() const
     {
      return StringFormat("%s@%.5f±%.5f %s t=%d r=%d v=%d age=%d %s",
                          TypeString(), price, tolerance, StateString(),
                          touchCount, reactionCount, violationCount, ageBars,
                          active ? "active" : "dead");
     }
  };

#endif // __OMEGA_PARTICIPANT_ZONE_MQH__
