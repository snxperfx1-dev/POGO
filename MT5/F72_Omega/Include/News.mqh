//+------------------------------------------------------------------+
//|                                                         News.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 10 context. Phase 7 upgrade: CSV-based calendar reader.  |
//|                                                                  |
//|   The engine NEVER blacks out by news. News is CONTEXT — it      |
//|   feeds the regime / probability layers and stamps campaigns     |
//|   with their environment. Whether to act through it is decided   |
//|   by the trinity, not by a hard veto.                            |
//|                                                                  |
//|   Calendar file (optional) lives at:                             |
//|     MQL5/Files/F72_Omega/news/calendar.csv                       |
//|                                                                  |
//|   Format (CSV, header row):                                      |
//|     time,currency,impact,title                                   |
//|     2025-01-15 13:30,USD,3,US CPI                                |
//|                                                                  |
//|   `impact`: 1=low, 2=medium, 3=high. Lookahead window default    |
//|   is ±15 minutes around event time.                              |
//+------------------------------------------------------------------+
#ifndef __OMEGA_NEWS_MQH__
#define __OMEGA_NEWS_MQH__

#include "Common.mqh"
#include "Logger.mqh"

#define OMEGA_NEWS_CAPACITY  256
#define OMEGA_NEWS_DEFAULT_WINDOW_MIN 15

struct NewsEvent
  {
   datetime time;
   string   currency;
   int      impact;     // 1=low 2=med 3=high
   string   title;
  };

class OmegaNewsCalendar
  {
private:
   NewsEvent m_events[OMEGA_NEWS_CAPACITY];
   int       m_count;
   bool      m_loaded;
   int       m_windowMin;

   static datetime ParseTime(string s)
     {
      //-- expects "YYYY-MM-DD HH:MM" or "YYYY.MM.DD HH:MM"
      string norm = s;
      StringReplace(norm, "-", ".");
      return StringToTime(norm);
     }

public:
                     OmegaNewsCalendar()
     {
      m_count = 0;
      m_loaded = false;
      m_windowMin = OMEGA_NEWS_DEFAULT_WINDOW_MIN;
     }

   bool Load(string path = "F72_Omega/news/calendar.csv", int windowMin = OMEGA_NEWS_DEFAULT_WINDOW_MIN)
     {
      m_windowMin = windowMin;
      m_count = 0;
      int h = FileOpen(path, FILE_READ | FILE_CSV | FILE_ANSI, ',');
      if(h == INVALID_HANDLE)
        {
         OmegaLogger::LogInfo("NEWS",
            StringFormat("No calendar file at %s — skipping", path));
         m_loaded = false;
         return false;
        }
      bool first = true;
      while(!FileIsEnding(h) && m_count < OMEGA_NEWS_CAPACITY)
        {
         string t = FileReadString(h);
         string c = FileReadString(h);
         string i = FileReadString(h);
         string ti= FileReadString(h);
         if(first) { first = false; continue; }
         if(StringLen(t) == 0) break;
         m_events[m_count].time     = ParseTime(t);
         m_events[m_count].currency = c;
         m_events[m_count].impact   = (int)StringToInteger(i);
         m_events[m_count].title    = ti;
         m_count++;
        }
      FileClose(h);
      m_loaded = true;
      OmegaLogger::LogInfo("NEWS",
         StringFormat("Calendar loaded · %d events · window=±%dm", m_count, windowMin));
      return true;
     }

   //--- highest-impact event currently within ±windowMin of `now`
   int CurrentImpact(datetime now = 0) const
     {
      if(!m_loaded || m_count == 0) return 0;
      if(now == 0) now = TimeCurrent();
      long w = (long)m_windowMin * 60;
      int best = 0;
      for(int i = 0; i < m_count; i++)
        {
         long dt = (long)m_events[i].time - (long)now;
         if(MathAbs(dt) <= w && m_events[i].impact > best)
            best = m_events[i].impact;
        }
      return best;
     }

   string CurrentEnvironment(datetime now = 0) const
     {
      int impact = CurrentImpact(now);
      switch(impact)
        {
         case 3: return "HIGH_IMPACT";
         case 2: return "MED_IMPACT";
         case 1: return "LOW_IMPACT";
        }
      return m_loaded ? "QUIET" : "NORMAL";
     }

   bool Loaded() const { return m_loaded; }
   int  Count()  const { return m_count; }
  };

//=== Static convenience wrapper kept for backward compatibility ===
class OmegaNews
  {
public:
   //-- Phase 1 returned const "NORMAL"; Phase 7 forwards to the
   //   shared OmegaNewsCalendar instance owned by the EA. The EA
   //   sets g_omega_news once on init.
   static string Environment() { return "NORMAL"; }
   static int    Severity()    { return 0; }
  };

#endif // __OMEGA_NEWS_MQH__
