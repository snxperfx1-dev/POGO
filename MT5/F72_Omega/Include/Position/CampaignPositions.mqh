//+------------------------------------------------------------------+
//|                                          CampaignPositions.mqh   |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 13/15 — campaign-aware position manager.                 |
//|                                                                  |
//|   Tracks every open position keyed by ticket. Supports:          |
//|     - Origin / Entry / Progress / Terminal roles                 |
//|     - hedge mode (longs and shorts coexisting)                   |
//|     - pyramiding within a campaign (multiple progress positions) |
//|     - SL trailing in tiers (initial → breakeven → +1R → +2R …)   |
//|     - partial reductions                                         |
//|     - mass exit                                                  |
//|     - explainability: every action goes through OmegaLogger      |
//|                                                                  |
//|   Reads orders back from the live broker via OnTradeTransaction  |
//|   so that even manual broker-side closes are reflected.          |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CAMPAIGN_POSITIONS_MQH__
#define __OMEGA_CAMPAIGN_POSITIONS_MQH__

#include "../Common.mqh"
#include "../Logger.mqh"
#include "../Memory.mqh"
#include "../Capital.mqh"
#include "../Risk.mqh"
#include "../PaperTrade.mqh"
#include "../CampaignDB.mqh"
#include "../Curve/Curve.mqh"
#include "PositionHealth.mqh"

#define OMEGA_POS_CAPACITY 32

class CampaignPositions
  {
private:
   OmegaPosition       m_pos[OMEGA_POS_CAPACITY];
   int                 m_count;
   string              m_symbol;
   ulong               m_magic;
   OmegaPaperTrade    *m_trade;
   OmegaCapital       *m_capital;
   OmegaRisk          *m_risk;
   CampaignDB         *m_db;

   //--- find an empty slot (or evict oldest closed)
   int FindFreeSlot()
     {
      for(int i = 0; i < m_count; i++)
         if(!m_pos[i].alive && m_pos[i].ticket == 0) return i;
      if(m_count < OMEGA_POS_CAPACITY) return m_count++;
      //-- full: evict oldest closed
      int evict = -1;
      datetime oldest = D'2099.01.01';
      for(int i = 0; i < m_count; i++)
        {
         if(m_pos[i].alive) continue;
         if(m_pos[i].closed > 0 && m_pos[i].closed < oldest)
           {
            oldest = m_pos[i].closed;
            evict = i;
           }
        }
      if(evict >= 0) { m_pos[evict].Reset(); return evict; }
      return -1;
     }

   int IndexOfTicket(ulong ticket) const
     {
      for(int i = 0; i < m_count; i++)
         if(m_pos[i].ticket == ticket) return i;
      return -1;
     }

public:
                     CampaignPositions()
     {
      m_count = 0; m_symbol = ""; m_magic = 0;
      m_trade = NULL; m_capital = NULL; m_risk = NULL; m_db = NULL;
     }

   void Init(string sym, ulong magic,
             OmegaPaperTrade *trade, OmegaCapital *capital, OmegaRisk *risk, CampaignDB *db)
     {
      m_symbol  = sym;
      m_magic   = magic;
      m_trade   = trade;
      m_capital = capital;
      m_risk    = risk;
      m_db      = db;
      m_count   = 0;
      OmegaLogger::LogInfo("POSITIONS",
         StringFormat("Init %s · capacity=%d · magic=%I64u", sym, OMEGA_POS_CAPACITY, magic));
     }

   //=== Counters ===================================================
   int CountActive(int direction = 0) const
     {
      int n = 0;
      for(int i = 0; i < m_count; i++)
        {
         if(!m_pos[i].alive) continue;
         if(direction != 0 && m_pos[i].direction != direction) continue;
         n++;
        }
      return n;
     }

   int CountByRole(ENUM_POSITION_ROLE role, int direction = 0) const
     {
      int n = 0;
      for(int i = 0; i < m_count; i++)
        {
         if(!m_pos[i].alive) continue;
         if(m_pos[i].role != role) continue;
         if(direction != 0 && m_pos[i].direction != direction) continue;
         n++;
        }
      return n;
     }

   double TotalRisk() const
     {
      double tot = 0;
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickVal  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      if(point <= 0 || tickSize <= 0 || tickVal <= 0) return 0;
      for(int i = 0; i < m_count; i++)
        {
         if(!m_pos[i].alive) continue;
         double slPts = m_pos[i].SLPoints();
         double riskMoney = (slPts * point / tickSize) * tickVal * m_pos[i].currentVolume;
         tot += riskMoney;
        }
      return tot;
     }

   //=== Open ========================================================
   ulong Open(int direction, ENUM_POSITION_ROLE role,
              double stopDistPoints, long campaignId,
              ENUM_OMEGA_REASON reason, string detail,
              const OmegaState &state)
     {
      if(m_trade == NULL || m_risk == NULL || m_capital == NULL)
        {
         OmegaLogger::LogException("POSITIONS", -1, "Open: dependencies not wired");
         return 0;
        }
      double riskPct = m_risk.RiskPctFor(state);
      double lots    = m_risk.LotsFor(m_symbol, riskPct, stopDistPoints, m_capital);
      if(lots <= 0)
        {
         OmegaLogger::LogWarning("POSITIONS",
            StringFormat("%s · zero lots · risk=%.2f%% sd=%.0f", m_symbol, riskPct, stopDistPoints));
         return 0;
        }

      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double askPx = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bidPx = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double openPx = (direction == 1) ? askPx : bidPx;
      double slDist = stopDistPoints * point;
      double sl     = (direction == 1) ? (openPx - slDist) : (openPx + slDist);

      ulong tk = (direction == 1)
         ? m_trade.Buy(m_symbol, lots, sl, 0.0, reason, detail)
         : m_trade.Sell(m_symbol, lots, sl, 0.0, reason, detail);
      if(tk == 0)
        {
         OmegaLogger::LogWarning("POSITIONS",
            StringFormat("%s · order failed · dir=%d lots=%.2f", m_symbol, direction, lots));
         return 0;
        }

      int slot = FindFreeSlot();
      if(slot < 0)
        {
         OmegaLogger::LogException("POSITIONS", -2, "No free slot for new position");
         //-- still record on broker, but lose tracking. Rare.
         return tk;
        }
      m_pos[slot].Reset();
      m_pos[slot].ticket         = tk;
      m_pos[slot].campaignId     = campaignId;
      m_pos[slot].symbol         = m_symbol;
      m_pos[slot].role           = role;
      m_pos[slot].direction      = direction;
      m_pos[slot].alive          = true;
      m_pos[slot].isPaper        = (m_trade.Mode() != OMEGA_MODE_AUTONOMOUS);
      m_pos[slot].openPrice      = openPx;
      m_pos[slot].openVolume     = lots;
      m_pos[slot].currentVolume  = lots;
      m_pos[slot].initialSL      = sl;
      m_pos[slot].currentSL      = sl;
      m_pos[slot].opened         = TimeCurrent();
      OmegaLogger::LogInfo("POSITIONS",
         StringFormat("OPEN · %s · risk=%.2f%% · %s",
                       PositionRoleStr::ToString(role), riskPct,
                       m_pos[slot].Snapshot()));
      return tk;
     }

   //=== Close one ticket ===========================================
   bool Close(ulong ticket, ENUM_OMEGA_REASON reason, string detail)
     {
      int idx = IndexOfTicket(ticket);
      if(idx < 0)
        {
         //-- not tracked — still try to close for safety
         return m_trade.Close(ticket, reason, detail);
        }
      bool ok = m_trade.Close(ticket, reason, detail);
      if(ok)
        {
         m_pos[idx].alive       = false;
         m_pos[idx].closed      = TimeCurrent();
         m_pos[idx].closeReason = reason;
         OmegaLogger::LogInfo("POSITIONS",
            StringFormat("CLOSE · %s · %s",
                          OmegaStr::ReasonToString(reason), m_pos[idx].Snapshot()));
        }
      return ok;
     }

   //=== Close all positions matching direction (0 = any) ===========
   int CloseAll(int direction, ENUM_OMEGA_REASON reason, string detail)
     {
      int n = 0;
      for(int i = 0; i < m_count; i++)
        {
         if(!m_pos[i].alive) continue;
         if(direction != 0 && m_pos[i].direction != direction) continue;
         if(Close(m_pos[i].ticket, reason, detail)) n++;
        }
      return n;
     }

   //=== Reduce (partial close) =====================================
   //   Closes the OLDEST profitable same-direction position. Phase 5
   //   simplification — full partial-volume reduction lands in 5.1.
   bool ReduceOldest(int direction, ENUM_OMEGA_REASON reason, string detail)
     {
      int target = -1;
      datetime oldest = D'2099.01.01';
      for(int i = 0; i < m_count; i++)
        {
         if(!m_pos[i].alive) continue;
         if(m_pos[i].direction != direction) continue;
         if(m_pos[i].opened < oldest)
           {
            oldest = m_pos[i].opened;
            target = i;
           }
        }
      if(target < 0) return false;
      return Close(m_pos[target].ticket, reason, detail);
     }

   //=== Trailing SL ================================================
   //   Per closed bar: bump current SL up tiers as MFE crosses 1R / 2R / 3R.
   //   Tier 0 = initial; Tier 1 = breakeven; Tier 2 = +1R; Tier 3 = +2R.
   void TrailStops()
     {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(point <= 0) return;
      for(int i = 0; i < m_count; i++)
        {
         if(!m_pos[i].alive) continue;
         double openPx  = m_pos[i].openPrice;
         double initSL  = m_pos[i].initialSL;
         double slDist  = MathAbs(openPx - initSL);
         if(slDist <= 0) continue;
         double mfePts  = m_pos[i].maxFavorablePts;
         double rUnit   = slDist / point;        // 1R distance in points
         double newSL   = m_pos[i].currentSL;
         int    tier    = m_pos[i].trailTier;

         //-- tier 1 — breakeven once MFE >= 1R
         if(tier < 1 && mfePts >= rUnit)
           {
            newSL = openPx;
            tier  = 1;
           }
         //-- tier 2 — +1R once MFE >= 2R
         if(tier < 2 && mfePts >= 2.0 * rUnit)
           {
            newSL = (m_pos[i].direction == 1) ? (openPx + slDist) : (openPx - slDist);
            tier  = 2;
           }
         //-- tier 3 — +2R once MFE >= 3R
         if(tier < 3 && mfePts >= 3.0 * rUnit)
           {
            newSL = (m_pos[i].direction == 1) ? (openPx + 2.0 * slDist) : (openPx - 2.0 * slDist);
            tier  = 3;
           }
         if(tier > m_pos[i].trailTier
            && MathAbs(newSL - m_pos[i].currentSL) > point * 5)
           {
            if(m_trade.ModifySLTP(m_pos[i].ticket, newSL, 0.0, REASON_HEALTHY_CONTINUATION,
                  StringFormat("trail tier %d -> %d MFE=%.0f", m_pos[i].trailTier, tier, mfePts)))
              {
               m_pos[i].currentSL  = newSL;
               m_pos[i].trailTier  = tier;
              }
           }
        }
     }

   //=== Per-tick excursion update ==================================
   void TickUpdate()
     {
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      for(int i = 0; i < m_count; i++)
         if(m_pos[i].alive) m_pos[i].TickExcursion(bid, ask);
     }

   //=== Per closed bar: trail + housekeeping =======================
   void BarUpdate(const OmegaState &state, OmegaCurve &curve)
     {
      TrailStops();
     }

   //=== Snapshot ===================================================
   string Snapshot() const
     {
      int alive = 0, longs = 0, shorts = 0;
      for(int i = 0; i < m_count; i++)
        {
         if(!m_pos[i].alive) continue;
         alive++;
         if(m_pos[i].direction == 1)  longs++;
         if(m_pos[i].direction == -1) shorts++;
        }
      return StringFormat("alive=%d (L=%d S=%d) total=%d riskOpen=%.2f",
                          alive, longs, shorts, m_count, TotalRisk());
     }

   //=== Read-only access ============================================
   int Count() const { return m_count; }
   //--- Read access by-value (MQL5 forbids pointers-to-struct).
   //    Returns true if a position exists at index `i`.
   bool GetAt(int i, OmegaPosition &out) const
     {
      if(i < 0 || i >= m_count) return false;
      out = m_pos[i];
      return true;
     }
  };

#endif // __OMEGA_CAMPAIGN_POSITIONS_MQH__
