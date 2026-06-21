//+------------------------------------------------------------------+
//|                                                       Shadow.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Phase 7 · shadow logger.                                       |
//|                                                                  |
//|   Lets the engine log a SECOND set of decisions in parallel to   |
//|   the live ones — using a different parameter set — without      |
//|   actually trading them. The shadow CSV becomes a side-by-side   |
//|   comparison harness so you can ask "what if I had used these    |
//|   thresholds instead?" against real ticks, not synthetic data.   |
//|                                                                  |
//|   Output:  MQL5/Files/F72_Omega/paper/shadow_<tag>.csv           |
//+------------------------------------------------------------------+
#ifndef __OMEGA_BACKTEST_SHADOW_MQH__
#define __OMEGA_BACKTEST_SHADOW_MQH__

#include "../Common.mqh"
#include "../Logger.mqh"

class ShadowLogger
  {
private:
   int    m_handle;
   string m_path;
   string m_tag;
   bool   m_open;

public:
                     ShadowLogger() { m_handle = INVALID_HANDLE; m_open = false; }

   bool Init(string tag)
     {
      m_tag  = tag;
      m_path = StringFormat("F72_Omega/paper/shadow_%s.csv", tag);
      m_handle = FileOpen(m_path, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(m_handle == INVALID_HANDLE)
        {
         OmegaLogger::LogException("SHADOW", GetLastError(),
            StringFormat("Open failed: %s", m_path));
         return false;
        }
      FileSeek(m_handle, 0, SEEK_END);
      if(FileSize(m_handle) == 0)
         FileWriteString(m_handle, "timestamp,tag,decision,reason,life,stability,confidence,detail\n");
      m_open = true;
      OmegaLogger::LogInfo("SHADOW", StringFormat("Init tag=%s · path=%s", tag, m_path));
      return true;
     }

   void Log(ENUM_OMEGA_DECISION dec, ENUM_OMEGA_REASON reason,
            double life, double stab, double conf, string detail)
     {
      if(!m_open) return;
      string ts = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
      string line = StringFormat("%s,%s,%s,%s,%.2f,%.2f,%.2f,%s\n",
                                  ts, m_tag,
                                  OmegaStr::DecisionToString(dec),
                                  OmegaStr::ReasonToString(reason),
                                  life, stab, conf, detail);
      FileWriteString(m_handle, line);
     }

   void Flush() { if(m_open) FileFlush(m_handle); }

   void Shutdown()
     {
      if(m_open) { FileFlush(m_handle); FileClose(m_handle); }
      m_open = false;
      m_handle = INVALID_HANDLE;
     }
  };

#endif // __OMEGA_BACKTEST_SHADOW_MQH__
