//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   The explainability backbone. Every other module logs through   |
//|   this. Three sinks:                                             |
//|     - Print() to terminal (always)                               |
//|     - decision_log.csv  (every decision, with trinity snapshot)  |
//|     - execution_log.csv (every order or paper-order)             |
//|     - exception_log.csv (every error / unexpected condition)     |
//|                                                                  |
//|   Layer 14 self-observation will read these CSVs to compute      |
//|   confidence decay and contradiction detection in Phase 6.       |
//+------------------------------------------------------------------+
#ifndef __OMEGA_LOGGER_MQH__
#define __OMEGA_LOGGER_MQH__

#include "Common.mqh"

enum ENUM_OMEGA_LOG_LEVEL
  {
   LOG_DEBUG       = 0,
   LOG_INFO        = 1,
   LOG_DECISION    = 2,
   LOG_EXECUTION   = 3,
   LOG_WARNING     = 4,
   LOG_EXCEPTION   = 5
  };

class OmegaLogger
  {
private:
   static int                 s_decisionFile;
   static int                 s_executionFile;
   static int                 s_exceptionFile;
   static bool                s_initialized;
   static ENUM_OMEGA_LOG_LEVEL s_minLevel;

   static string LevelString(ENUM_OMEGA_LOG_LEVEL l)
     {
      switch(l)
        {
         case LOG_DEBUG:     return "DEBUG";
         case LOG_INFO:      return "INFO";
         case LOG_DECISION:  return "DECIDE";
         case LOG_EXECUTION: return "EXEC";
         case LOG_WARNING:   return "WARN";
         case LOG_EXCEPTION: return "EXCEPT";
        }
      return "?";
     }

   static int OpenCsv(const string filename, const string header)
     {
      int handle = FileOpen(filename, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
        {
         Print("[OMEGA-LOGGER] FileOpen failed for ", filename, " err=", GetLastError());
         return INVALID_HANDLE;
        }
      // append-mode: seek end, write header only if file is empty
      FileSeek(handle, 0, SEEK_END);
      if(FileSize(handle) == 0)
        {
         FileWriteString(handle, header + "\n");
        }
      return handle;
     }

public:
   static bool Init(ENUM_OMEGA_LOG_LEVEL minLevel = LOG_INFO)
     {
      s_minLevel = minLevel;
      s_decisionFile = OpenCsv(
         OMEGA_LOG_DIR + "/decision_log.csv",
         "timestamp,symbol,mode,decision,reason,life,stability,confidence,detail"
      );
      s_executionFile = OpenCsv(
         OMEGA_LOG_DIR + "/execution_log.csv",
         "timestamp,symbol,action,ticket,price,lots,reason,detail"
      );
      s_exceptionFile = OpenCsv(
         OMEGA_LOG_DIR + "/exception_log.csv",
         "timestamp,module,code,message"
      );
      s_initialized = (s_decisionFile != INVALID_HANDLE);
      if(s_initialized)
        {
         LogInfo("LOGGER", StringFormat("Initialized · level=%s · root=%s",
                  LevelString(minLevel), OMEGA_LOG_DIR));
        }
      else
        {
         Print("[OMEGA-LOGGER] WARNING: csv sinks unavailable — falling back to Print() only.");
        }
      return true; // Print() sink always works; CSVs are best-effort
     }

   static void Shutdown()
     {
      if(s_decisionFile  != INVALID_HANDLE) { FileFlush(s_decisionFile);  FileClose(s_decisionFile);  s_decisionFile  = INVALID_HANDLE; }
      if(s_executionFile != INVALID_HANDLE) { FileFlush(s_executionFile); FileClose(s_executionFile); s_executionFile = INVALID_HANDLE; }
      if(s_exceptionFile != INVALID_HANDLE) { FileFlush(s_exceptionFile); FileClose(s_exceptionFile); s_exceptionFile = INVALID_HANDLE; }
      s_initialized = false;
     }

   static void Flush()
     {
      if(s_decisionFile  != INVALID_HANDLE) FileFlush(s_decisionFile);
      if(s_executionFile != INVALID_HANDLE) FileFlush(s_executionFile);
      if(s_exceptionFile != INVALID_HANDLE) FileFlush(s_exceptionFile);
     }

   //--- minimum level filter
   static void SetMinLevel(ENUM_OMEGA_LOG_LEVEL l) { s_minLevel = l; }
   static ENUM_OMEGA_LOG_LEVEL MinLevel() { return s_minLevel; }

   //--- core log
   static void Log(ENUM_OMEGA_LOG_LEVEL level, string module, string msg)
     {
      if((int)level < (int)s_minLevel) return;
      string ts = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
      Print(StringFormat("[%s][%s][%s] %s", ts, LevelString(level), module, msg));
     }

   static void LogDebug(string module, string msg)   { Log(LOG_DEBUG,   module, msg); }
   static void LogInfo(string module, string msg)    { Log(LOG_INFO,    module, msg); }
   static void LogWarning(string module, string msg) { Log(LOG_WARNING, module, msg); }

   static void LogException(string module, int code, string msg)
     {
      Log(LOG_EXCEPTION, module, StringFormat("[%d] %s", code, msg));
      if(s_exceptionFile != INVALID_HANDLE)
        {
         string ts = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
         FileWriteString(s_exceptionFile,
                         StringFormat("%s,%s,%d,%s\n", ts, module, code, msg));
         FileFlush(s_exceptionFile);
        }
     }

   //--- structured decision log
   static void LogDecision(string symbol, ENUM_OMEGA_MODE mode, ENUM_OMEGA_DECISION decision,
                           ENUM_OMEGA_REASON reason, double life, double stability, double confidence,
                           string detail)
     {
      string decStr = OmegaStr::DecisionToString(decision);
      string reaStr = OmegaStr::ReasonToString(reason);
      Log(LOG_DECISION, "DECIDE",
          StringFormat("%s · %s · %s · L=%.1f S=%.1f C=%.1f · %s",
                       symbol, decStr, reaStr, life, stability, confidence, detail));
      if(s_decisionFile != INVALID_HANDLE)
        {
         string ts = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
         string line = StringFormat("%s,%s,%s,%s,%s,%.2f,%.2f,%.2f,%s\n",
                                    ts, symbol, OmegaStr::ModeToString(mode), decStr, reaStr,
                                    life, stability, confidence, detail);
         FileWriteString(s_decisionFile, line);
        }
     }

   //--- structured execution log
   static void LogExecution(string symbol, string action, ulong ticket, double price, double lots,
                            ENUM_OMEGA_REASON reason, string detail)
     {
      string reaStr = OmegaStr::ReasonToString(reason);
      Log(LOG_EXECUTION, "EXEC",
          StringFormat("%s · %s · #%I64u · px=%.5f · vol=%.2f · %s · %s",
                       symbol, action, ticket, price, lots, reaStr, detail));
      if(s_executionFile != INVALID_HANDLE)
        {
         string ts = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
         string line = StringFormat("%s,%s,%s,%I64u,%.5f,%.2f,%s,%s\n",
                                    ts, symbol, action, ticket, price, lots, reaStr, detail);
         FileWriteString(s_executionFile, line);
        }
     }
  };

//--- static member definitions (required outside class in MQL5)
int                 OmegaLogger::s_decisionFile  = INVALID_HANDLE;
int                 OmegaLogger::s_executionFile = INVALID_HANDLE;
int                 OmegaLogger::s_exceptionFile = INVALID_HANDLE;
bool                OmegaLogger::s_initialized   = false;
ENUM_OMEGA_LOG_LEVEL OmegaLogger::s_minLevel     = LOG_INFO;

#endif // __OMEGA_LOGGER_MQH__
