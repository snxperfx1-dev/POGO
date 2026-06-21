//+------------------------------------------------------------------+
//|                                              PositionHealth.mqh  |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 7 / 13 — single-position state and health tracking.      |
//|                                                                  |
//|   Each campaign has multiple positions, each with its own role:  |
//|     ORIGIN     — first commitment (early in the life)            |
//|     ENTRY      — continuation entries on healthy progression     |
//|     PROGRESS   — pyramid adds on new extremes                    |
//|     TERMINAL   — late add when price approaches HTF objective    |
//|                                                                  |
//|   PositionHealth tracks each position's:                         |
//|     ticket / role / direction / open price / volume              |
//|     campaignId — FK into CampaignDB                              |
//|     initial SL / current SL / initial TP                         |
//|     MAE / MFE  — max adverse / favorable excursion (point units) |
//|     trailTier — # of times SL has stepped up                     |
//|     pnl, age, alive flag                                         |
//|                                                                  |
//|   Role-based behaviour and SL trailing rules live in the         |
//|   CampaignPositions manager (above this module).                 |
//+------------------------------------------------------------------+
#ifndef __OMEGA_POSITION_HEALTH_MQH__
#define __OMEGA_POSITION_HEALTH_MQH__

#include "../Common.mqh"
#include "../Logger.mqh"

//=== Position role inside a campaign ================================
enum ENUM_POSITION_ROLE
  {
   POS_ORIGIN     = 0,
   POS_ENTRY      = 1,
   POS_PROGRESS   = 2,
   POS_TERMINAL   = 3
  };

class PositionRoleStr
  {
public:
   static string ToString(ENUM_POSITION_ROLE r)
     {
      switch(r)
        {
         case POS_ORIGIN:    return "ORIGIN";
         case POS_ENTRY:     return "ENTRY";
         case POS_PROGRESS:  return "PROGRESS";
         case POS_TERMINAL:  return "TERMINAL";
        }
      return "?";
     }
  };

//=== Per-position record ============================================
struct OmegaPosition
  {
   //--- identity
   ulong              ticket;
   long               campaignId;
   string             symbol;
   ENUM_POSITION_ROLE role;
   int                direction;        // +1 / -1
   bool               alive;
   bool               isPaper;          // true = paper ticket, not live

   //--- prices / sizing
   double             openPrice;
   double             openVolume;
   double             currentVolume;    // may be reduced by partial closes
   double             initialSL;
   double             currentSL;
   double             initialTP;        // 0 if none — managed by trail

   //--- bookkeeping
   datetime           opened;
   datetime           closed;

   //--- excursion (in points)
   double             maxFavorablePts;
   double             maxAdversePts;
   int                trailTier;        // 0 = initial, 1 = breakeven, 2 = +1R …

   //--- realized P&L when closed (broker units)
   double             realizedPnl;
   ENUM_OMEGA_REASON  closeReason;

                     OmegaPosition() { Reset(); }

   void Reset()
     {
      ticket = 0; campaignId = 0; symbol = "";
      role = POS_ENTRY; direction = 0;
      alive = false; isPaper = false;
      openPrice = openVolume = currentVolume = 0;
      initialSL = currentSL = initialTP = 0;
      opened = 0; closed = 0;
      maxFavorablePts = maxAdversePts = 0;
      trailTier = 0;
      realizedPnl = 0;
      closeReason = REASON_NONE;
     }

   //--- update MFE/MAE on a fresh tick (point units = price-point ATR-style)
   void TickExcursion(double bid, double ask)
     {
      if(!alive) return;
      double price = (direction == 1) ? bid : ask;
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0) return;
      double favPts = ((direction == 1) ? (price - openPrice) : (openPrice - price)) / point;
      double advPts = -favPts;
      if(favPts > maxFavorablePts) maxFavorablePts = favPts;
      if(advPts > maxAdversePts)   maxAdversePts   = advPts;
     }

   //--- distance (points) from current price to currentSL
   double SLPoints() const
     {
      if(initialSL <= 0 || openPrice <= 0) return 0.0;
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0) return 0.0;
      return MathAbs(openPrice - initialSL) / point;
     }

   //--- short snapshot for logs
   string Snapshot() const
     {
      return StringFormat("#%I64u %s %s %.2f%s @ %.5f sl=%.5f mfe=%.0f mae=%.0f tier=%d alive=%s camp=%I64d",
                          ticket, PositionRoleStr::ToString(role),
                          (direction == 1 ? "LONG" : "SHORT"),
                          currentVolume, isPaper ? "(P)" : "",
                          openPrice, currentSL,
                          maxFavorablePts, maxAdversePts, trailTier,
                          alive ? "Y" : "N",
                          campaignId);
     }
  };

#endif // __OMEGA_POSITION_HEALTH_MQH__
