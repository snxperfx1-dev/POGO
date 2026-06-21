//+------------------------------------------------------------------+
//|                                                      Session.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 9 context — informational ONLY.                          |
//|   The engine never blacks out by session. Sessions provide a     |
//|   field in campaign memory ("when was this born?") and feed the  |
//|   regime / probability layers in Phase 6. Do NOT introduce       |
//|   "London-only" or "no-Friday" logic — it contradicts the philo. |
//|                                                                  |
//|   These windows are approximations on server time; Phase 7 will  |
//|   fold broker timezone offset.                                   |
//+------------------------------------------------------------------+
#ifndef __OMEGA_SESSION_MQH__
#define __OMEGA_SESSION_MQH__

#include "Common.mqh"

class OmegaSession
  {
public:
   static ENUM_OMEGA_SESSION Current(datetime t = 0)
     {
      if(t == 0) t = TimeCurrent();
      MqlDateTime dt; TimeToStruct(t, dt);
      int h = (int)dt.hour;
      bool asian  = (h >= 0  && h <  8);
      bool london = (h >= 7  && h < 16);
      bool ny     = (h >= 12 && h < 21);
      if(london && ny) return SESSION_OVERLAP_LN;
      if(ny)           return SESSION_NY;
      if(london)       return SESSION_LONDON;
      if(asian)        return SESSION_ASIAN;
      return SESSION_OFF;
     }
  };

#endif // __OMEGA_SESSION_MQH__
