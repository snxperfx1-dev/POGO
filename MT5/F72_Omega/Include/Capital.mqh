//+------------------------------------------------------------------+
//|                                                      Capital.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 13 — Capital is alive. Equity tracking, drawdown state   |
//|   machine (HEALTHY → WARNING → RESTRICTED → SUSPENDED), and a    |
//|   continuous Throttle() multiplier (0..1) that scales risk down  |
//|   smoothly as drawdowns approach their limits — instead of       |
//|   hard-cliffing.                                                 |
//|                                                                  |
//|   Limits:                                                        |
//|     daily   3%  (default)                                        |
//|     weekly  8%                                                   |
//|     hard   15%   — kill switch                                   |
//|                                                                  |
//|   Capital READS the Trinity (it doesn't own it), but its outputs |
//|   GATE Risk and Execution. Strict downstream-only dependency.    |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CAPITAL_MQH__
#define __OMEGA_CAPITAL_MQH__

#include "Common.mqh"
#include "Logger.mqh"

class OmegaCapital
  {
private:
   double                   m_baselineEquity;
   double                   m_dayStartEquity;
   double                   m_weekStartEquity;
   double                   m_peakEquity;
   double                   m_dailyLossLimitPct;
   double                   m_weeklyLossLimitPct;
   double                   m_hardLimitPct;
   datetime                 m_dayStart;
   datetime                 m_weekStart;
   ENUM_OMEGA_CAPITAL_STATE m_state;

   static datetime DayStartOf(datetime t)
     {
      MqlDateTime dt; TimeToStruct(t, dt);
      dt.hour = 0; dt.min = 0; dt.sec = 0;
      return StructToTime(dt);
     }
   static datetime WeekStartOf(datetime t)
     {
      // Monday 00:00 (server time)
      datetime d = DayStartOf(t);
      MqlDateTime dt; TimeToStruct(d, dt);
      int dow = (int)dt.day_of_week;     // 0=Sun..6=Sat
      int back = (dow == 0) ? 6 : (dow - 1);
      return d - (datetime)((long)back * 86400);
     }

public:
                     OmegaCapital()
     {
      m_baselineEquity     = 0;
      m_dayStartEquity     = 0;
      m_weekStartEquity    = 0;
      m_peakEquity         = 0;
      m_dailyLossLimitPct  = 3.0;
      m_weeklyLossLimitPct = 8.0;
      m_hardLimitPct       = 15.0;
      m_dayStart           = 0;
      m_weekStart          = 0;
      m_state              = CAPITAL_HEALTHY;
     }

   void Init(double dailyPct = 3.0, double weeklyPct = 8.0, double hardPct = 15.0)
     {
      m_dailyLossLimitPct  = dailyPct;
      m_weeklyLossLimitPct = weeklyPct;
      m_hardLimitPct       = hardPct;
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      m_baselineEquity  = eq;
      m_peakEquity      = eq;
      m_dayStartEquity  = eq;
      m_weekStartEquity = eq;
      m_dayStart  = DayStartOf(TimeCurrent());
      m_weekStart = WeekStartOf(TimeCurrent());
      m_state     = CAPITAL_HEALTHY;
      OmegaLogger::LogInfo("CAPITAL",
         StringFormat("Initialized · equity=%.2f · daily=%.1f%% weekly=%.1f%% hard=%.1f%%",
                      eq, dailyPct, weeklyPct, hardPct));
     }

   void Update()
     {
      double   eq  = AccountInfoDouble(ACCOUNT_EQUITY);
      datetime now = TimeCurrent();

      //--- roll daily / weekly anchors
      datetime newDay = DayStartOf(now);
      if(newDay != m_dayStart)
        {
         m_dayStart       = newDay;
         m_dayStartEquity = eq;
         OmegaLogger::LogInfo("CAPITAL", StringFormat("Day rolled · equity=%.2f", eq));
        }
      datetime newWeek = WeekStartOf(now);
      if(newWeek != m_weekStart)
        {
         m_weekStart       = newWeek;
         m_weekStartEquity = eq;
         OmegaLogger::LogInfo("CAPITAL", StringFormat("Week rolled · equity=%.2f", eq));
        }

      if(eq > m_peakEquity) m_peakEquity = eq;

      double ddDay  = OmegaMath::Pct(m_dayStartEquity  - eq, m_dayStartEquity);
      double ddWeek = OmegaMath::Pct(m_weekStartEquity - eq, m_weekStartEquity);
      double ddHard = OmegaMath::Pct(m_baselineEquity  - eq, m_baselineEquity);

      ENUM_OMEGA_CAPITAL_STATE prev = m_state;
      if(ddHard >= m_hardLimitPct)            m_state = CAPITAL_SUSPENDED;
      else if(ddWeek >= m_weeklyLossLimitPct) m_state = CAPITAL_RESTRICTED;
      else if(ddDay  >= m_dailyLossLimitPct)  m_state = CAPITAL_RESTRICTED;
      else if(ddDay  >= m_dailyLossLimitPct  * 0.66 ||
              ddWeek >= m_weeklyLossLimitPct * 0.66) m_state = CAPITAL_WARNING;
      else                                    m_state = CAPITAL_HEALTHY;

      if(m_state != prev)
         OmegaLogger::LogWarning("CAPITAL",
            StringFormat("State %s -> %s · ddDay=%.2f%% ddWeek=%.2f%% ddHard=%.2f%%",
                         OmegaStr::CapitalStateToString(prev),
                         OmegaStr::CapitalStateToString(m_state),
                         ddDay, ddWeek, ddHard));
     }

   //--- accessors
   ENUM_OMEGA_CAPITAL_STATE State()        const { return m_state; }
   double Equity()                         const { return AccountInfoDouble(ACCOUNT_EQUITY); }
   double Baseline()                       const { return m_baselineEquity; }
   double DayStart()                       const { return m_dayStartEquity; }
   double WeekStart()                      const { return m_weekStartEquity; }
   double DailyDrawdownPct()               const { return OmegaMath::Pct(m_dayStartEquity  - Equity(), m_dayStartEquity); }
   double WeeklyDrawdownPct()              const { return OmegaMath::Pct(m_weekStartEquity - Equity(), m_weekStartEquity); }
   double HardDrawdownPct()                const { return OmegaMath::Pct(m_baselineEquity  - Equity(), m_baselineEquity); }
   double DailyLimitPct()                  const { return m_dailyLossLimitPct; }
   double WeeklyLimitPct()                 const { return m_weeklyLossLimitPct; }
   double HardLimitPct()                   const { return m_hardLimitPct; }

   //--- Continuous throttle (0..1) — risk multiplier that decays
   //--- smoothly toward zero as drawdowns approach their limits.
   double Throttle() const
     {
      double dt = OmegaMath::Clamp(1.0 - (DailyDrawdownPct()  / m_dailyLossLimitPct ), 0.0, 1.0);
      double wt = OmegaMath::Clamp(1.0 - (WeeklyDrawdownPct() / m_weeklyLossLimitPct), 0.0, 1.0);
      double ht = OmegaMath::Clamp(1.0 - (HardDrawdownPct()   / m_hardLimitPct      ), 0.0, 1.0);
      return MathMin(dt, MathMin(wt, ht));
     }
  };

#endif // __OMEGA_CAPITAL_MQH__
