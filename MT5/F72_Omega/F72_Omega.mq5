//+------------------------------------------------------------------+
//|                                                    F72_Omega.mq5 |
//|                                                        F72 OMEGA |
//|       *** AUTONOMOUS · PRODUCTION THRESHOLDS ***                 |
//+------------------------------------------------------------------+
#property copyright "F72 OMEGA"
#property version   "1.00"
#property strict
#property description "F72 OMEGA — multi-timeframe curve organism."
#property description "AUTONOMOUS only. Production thresholds. Force-fallback for warmup only."
#include <Trade/Trade.mqh>


//==================================================================
//= MODULE: Common
//= Source: Include/Common.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                       Common.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 0 — Universe primitives. Every other module includes     |
//|   this. NO module above this is allowed to define its own enums  |
//|   for cross-cutting concerns (modes, decisions, reasons,         |
//|   sessions, capital states). Single source of truth.             |
//+------------------------------------------------------------------+
#ifndef __OMEGA_COMMON_MQH__
#define __OMEGA_COMMON_MQH__


//=== Operating modes (Layer: Human Override Philosophy) =============
//   Only AUTONOMOUS exists now — the engine trades. Earlier modes
//   (OBSERVER, COPILOT, PAPER, SHADOW) were removed by request.
//===================================================================
enum ENUM_OMEGA_MODE
  {
   OMEGA_MODE_AUTONOMOUS   = 0
  };

//=== Decisions =====================================================
//   These are CONSEQUENCES of trinity state, never direct signals.
//===================================================================
enum ENUM_OMEGA_DECISION
  {
   OMEGA_DEC_OBSERVE       = 0,
   OMEGA_DEC_ENTER_LONG    = 1,
   OMEGA_DEC_ENTER_SHORT   = 2,
   OMEGA_DEC_HOLD          = 3,
   OMEGA_DEC_ADD           = 4,
   OMEGA_DEC_REDUCE        = 5,
   OMEGA_DEC_REVERSE       = 6,
   OMEGA_DEC_EXIT          = 7,
   OMEGA_DEC_TRANSFER      = 8
  };

//=== Reason codes (explainability) =================================
//   Every decision carries one. Layer 14 self-observation rolls
//   these up to detect contradiction, regime drift, overfit.
//===================================================================
enum ENUM_OMEGA_REASON
  {
   REASON_NONE                     = 0,
   REASON_LIFE_HEALTHY             = 1,
   REASON_LIFE_WEAKENING           = 2,
   REASON_LIFE_DECAY               = 3,
   REASON_LIFE_DEAD                = 4,
   REASON_STORY_STABLE             = 10,
   REASON_STORY_CONTRADICTION      = 11,
   REASON_STORY_STRENGTHENING      = 12,
   REASON_STORY_WEAKENING          = 13,
   REASON_CONFIDENCE_HIGH          = 20,
   REASON_CONFIDENCE_LOW           = 21,
   REASON_CONFIDENCE_DECAY         = 22,
   REASON_OWNERSHIP_TRANSFER       = 30,
   REASON_OWNERSHIP_PERSISTING     = 31,
   REASON_OWNERSHIP_LEAKING        = 32,
   REASON_CHAIN_HEALTHY            = 40,
   REASON_CHAIN_WEAKENING          = 41,
   REASON_CHAIN_DECAY              = 42,
   REASON_COMPRESSION_TIGHT        = 50,
   REASON_COMPRESSION_WIDE         = 51,
   REASON_COMPRESSION_TIGHTENING   = 52,
   REASON_FORCE_PERSISTING         = 60,
   REASON_FORCE_LEAKING            = 61,
   REASON_REGIME_HEALTHY           = 70,
   REASON_REGIME_SHIFT             = 71,
   REASON_RISK_LIMIT               = 80,
   REASON_DAILY_LIMIT              = 81,
   REASON_WEEKLY_LIMIT             = 82,
   REASON_HARD_LIMIT               = 83,
   REASON_DRAWDOWN_THROTTLE        = 84,
   REASON_NARRATIVE_ALIGN          = 90,
   REASON_NARRATIVE_DIVERGE        = 91,
   REASON_HEALTHY_CONTINUATION     = 100,
   REASON_TERMINAL_INDUCTION       = 101,
   REASON_FAILURE_SWING            = 102,
   REASON_RECURSION_BUDGET_FULL    = 110,
   REASON_RECURSION_BUDGET_LEFT    = 111,
   REASON_HEARTBEAT                = 199,
   REASON_PHASE_NOT_BUILT          = 200
  };

//=== Capital state machine =========================================
enum ENUM_OMEGA_CAPITAL_STATE
  {
   CAPITAL_HEALTHY     = 0,
   CAPITAL_WARNING     = 1,
   CAPITAL_RESTRICTED  = 2,
   CAPITAL_SUSPENDED   = 3
  };

//=== Sessions (informational only — engine never blacks out) =======
enum ENUM_OMEGA_SESSION
  {
   SESSION_OFF         = 0,
   SESSION_ASIAN       = 1,
   SESSION_LONDON      = 2,
   SESSION_NY          = 3,
   SESSION_OVERLAP_LN  = 4
  };

//=== Constants =====================================================
#define OMEGA_VERSION                "1.0.0-phase5.6"
#define OMEGA_FILES_ROOT             "F72_Omega"
#define OMEGA_LOG_DIR                "F72_Omega/logs"
#define OMEGA_CAMPAIGN_DIR           "F72_Omega/campaigns"
#define OMEGA_ROLLING_DIR            "F72_Omega/rolling"
#define OMEGA_TRINITY_NEUTRAL        50.0

//=== Math helpers (namespaced via class to avoid collisions) =======
class OmegaMath
  {
public:
   static double Clamp(double v, double lo, double hi)
     {
      return MathMax(lo, MathMin(hi, v));
     }
   static double Lerp(double a, double b, double t)
     {
      return a + (b - a) * t;
     }
   static double SafeDiv(double n, double d, double fallback = 0.0)
     {
      return (MathAbs(d) < 1e-10) ? fallback : (n / d);
     }
   static double Pct(double v, double total, double fallback = 0.0)
     {
      return SafeDiv(v, total, fallback) * 100.0;
     }
  };

//=== String helpers ================================================
class OmegaStr
  {
public:
   static string ModeToString(ENUM_OMEGA_MODE m)
     {
      if(m == OMEGA_MODE_AUTONOMOUS) return "AUTONOMOUS";
      return "AUTONOMOUS";
     }
   static string DecisionToString(ENUM_OMEGA_DECISION d)
     {
      switch(d)
        {
         case OMEGA_DEC_OBSERVE:      return "OBSERVE";
         case OMEGA_DEC_ENTER_LONG:   return "ENTER_LONG";
         case OMEGA_DEC_ENTER_SHORT:  return "ENTER_SHORT";
         case OMEGA_DEC_HOLD:         return "HOLD";
         case OMEGA_DEC_ADD:          return "ADD";
         case OMEGA_DEC_REDUCE:       return "REDUCE";
         case OMEGA_DEC_REVERSE:      return "REVERSE";
         case OMEGA_DEC_EXIT:         return "EXIT";
         case OMEGA_DEC_TRANSFER:     return "TRANSFER";
        }
      return "UNKNOWN";
     }
   static string ReasonToString(ENUM_OMEGA_REASON r)
     {
      switch(r)
        {
         case REASON_NONE:                  return "NONE";
         case REASON_LIFE_HEALTHY:          return "LIFE_HEALTHY";
         case REASON_LIFE_WEAKENING:        return "LIFE_WEAKENING";
         case REASON_LIFE_DECAY:            return "LIFE_DECAY";
         case REASON_LIFE_DEAD:             return "LIFE_DEAD";
         case REASON_STORY_STABLE:          return "STORY_STABLE";
         case REASON_STORY_CONTRADICTION:   return "STORY_CONTRADICTION";
         case REASON_STORY_STRENGTHENING:   return "STORY_STRENGTHENING";
         case REASON_STORY_WEAKENING:       return "STORY_WEAKENING";
         case REASON_CONFIDENCE_HIGH:       return "CONFIDENCE_HIGH";
         case REASON_CONFIDENCE_LOW:        return "CONFIDENCE_LOW";
         case REASON_CONFIDENCE_DECAY:      return "CONFIDENCE_DECAY";
         case REASON_OWNERSHIP_TRANSFER:    return "OWNERSHIP_TRANSFER";
         case REASON_OWNERSHIP_PERSISTING:  return "OWNERSHIP_PERSISTING";
         case REASON_OWNERSHIP_LEAKING:     return "OWNERSHIP_LEAKING";
         case REASON_CHAIN_HEALTHY:         return "CHAIN_HEALTHY";
         case REASON_CHAIN_WEAKENING:       return "CHAIN_WEAKENING";
         case REASON_CHAIN_DECAY:           return "CHAIN_DECAY";
         case REASON_COMPRESSION_TIGHT:     return "COMPRESSION_TIGHT";
         case REASON_COMPRESSION_WIDE:      return "COMPRESSION_WIDE";
         case REASON_COMPRESSION_TIGHTENING:return "COMPRESSION_TIGHTENING";
         case REASON_FORCE_PERSISTING:      return "FORCE_PERSISTING";
         case REASON_FORCE_LEAKING:         return "FORCE_LEAKING";
         case REASON_REGIME_HEALTHY:        return "REGIME_HEALTHY";
         case REASON_REGIME_SHIFT:          return "REGIME_SHIFT";
         case REASON_RISK_LIMIT:            return "RISK_LIMIT";
         case REASON_DAILY_LIMIT:           return "DAILY_LIMIT";
         case REASON_WEEKLY_LIMIT:          return "WEEKLY_LIMIT";
         case REASON_HARD_LIMIT:            return "HARD_LIMIT";
         case REASON_DRAWDOWN_THROTTLE:     return "DRAWDOWN_THROTTLE";
         case REASON_NARRATIVE_ALIGN:       return "NARRATIVE_ALIGN";
         case REASON_NARRATIVE_DIVERGE:     return "NARRATIVE_DIVERGE";
         case REASON_HEALTHY_CONTINUATION:  return "HEALTHY_CONTINUATION";
         case REASON_TERMINAL_INDUCTION:    return "TERMINAL_INDUCTION";
         case REASON_FAILURE_SWING:         return "FAILURE_SWING";
         case REASON_RECURSION_BUDGET_FULL: return "RECURSION_BUDGET_FULL";
         case REASON_RECURSION_BUDGET_LEFT: return "RECURSION_BUDGET_LEFT";
         case REASON_HEARTBEAT:             return "HEARTBEAT";
         case REASON_PHASE_NOT_BUILT:       return "PHASE_NOT_BUILT";
        }
      return StringFormat("REASON_%d", (int)r);
     }
   static string CapitalStateToString(ENUM_OMEGA_CAPITAL_STATE s)
     {
      switch(s)
        {
         case CAPITAL_HEALTHY:    return "HEALTHY";
         case CAPITAL_WARNING:    return "WARNING";
         case CAPITAL_RESTRICTED: return "RESTRICTED";
         case CAPITAL_SUSPENDED:  return "SUSPENDED";
        }
      return "UNKNOWN";
     }
   static string SessionToString(ENUM_OMEGA_SESSION s)
     {
      switch(s)
        {
         case SESSION_ASIAN:       return "ASIAN";
         case SESSION_LONDON:      return "LONDON";
         case SESSION_NY:          return "NY";
         case SESSION_OVERLAP_LN:  return "LN_OVERLAP";
         case SESSION_OFF:         return "OFF";
        }
      return "UNKNOWN";
     }
   //--- minimal JSON string escaper
   static string EscapeJson(string s)
     {
      string r = s;
      StringReplace(r, "\\", "\\\\");
      StringReplace(r, "\"", "\\\"");
      StringReplace(r, "\n", "\\n");
      StringReplace(r, "\r", "\\r");
      StringReplace(r, "\t", "\\t");
      return r;
     }
  };

#endif // __OMEGA_COMMON_MQH__

//==================================================================
//= MODULE: Logger
//= Source: Include/Logger.mqh
//==================================================================
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

//==================================================================
//= MODULE: Memory
//= Source: Include/Memory.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                       Memory.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   The TRINITY container.                                         |
//|                                                                  |
//|   life       — "Is the story still alive?"  (Layer 7)            |
//|   stability  — "How stable is the narrative?" (Layer 3)          |
//|   confidence — "How much do I trust myself?" (Layer 14)          |
//|                                                                  |
//|   Every other module FEEDS the trinity. Risk, Capital, and       |
//|   Execution READ the trinity. The dependency hierarchy is        |
//|   strict and one-directional.                                    |
//|                                                                  |
//|   In Phase 1 the perception layers (curve, force, chain,         |
//|   narrative) are not built yet — primed=false — so the trinity   |
//|   stays at its neutral 50.0 anchor and the engine deliberately   |
//|   does not act. That neutrality IS a state, and the engine logs  |
//|   it explicitly each heartbeat as REASON_PHASE_NOT_BUILT.        |
//+------------------------------------------------------------------+
#ifndef __OMEGA_MEMORY_MQH__
#define __OMEGA_MEMORY_MQH__


//=== The supporting fields the perception layers populate ==========
//   Layer order matches the user's spec:
//     Universe → Curve → Compression → Convexity → Force → Ownership
//     → Recursion → Chain → Narrative → LifeScore → StoryStability
//     → StoryConfidence → Risk → Capital → Execution
//
//   Each lower layer only WRITES to its own field; it never reads
//   anything above it. DeriveTrinity() folds them upward.
//===================================================================
struct OmegaSupporting
  {
   //--- physics (Phase 2)
   double  forceScore;
   double  compression;
   double  convexity;
   //--- structure (Phase 3)
   double  ownershipStability;
   double  chainHealth;
   int     recursionDepth;
   int     recursionBudget;
   //--- narrative (Phase 4)
   double  alignment;
   double  narrative;
   //--- participants (Phase 8)
   double  participantStability;
   double  flipQuality;
   //--- regime / probabilities (Phase 6)
   double  regime;
   double  pContinuation;
   double  pTerminal;
   double  pTransfer;
  };

//=== State container ===============================================
class OmegaState
  {
public:
   //--- THE TRINITY (the only three values decisions are allowed to read)
   double           life;
   double           stability;
   double           confidence;

   //--- the supporting layers (perception)
   OmegaSupporting  supporting;

   //--- bookkeeping
   datetime         updated;
   long             tickCount;
   bool             primed;          // false until perception layers exist
   bool             dirty;           // true when persistence should flush

                    OmegaState() { Reset(); }

   void Reset()
     {
      life        = OMEGA_TRINITY_NEUTRAL;
      stability   = OMEGA_TRINITY_NEUTRAL;
      confidence  = OMEGA_TRINITY_NEUTRAL;
      ZeroMemory(supporting);
      updated     = 0;
      tickCount   = 0;
      primed      = false;
      dirty       = false;
     }

   //--- The contract every later phase must satisfy:
   //    LifeScore folds force/ownership/chain/compression upward.
   //    StoryStability folds alignment/narrative/regime upward.
   //    StoryConfidence is updated independently by SelfObservation
   //    (Phase 6); we only clamp it here.
   //
   //    Weights here are sketches — the ACTUAL tuning happens against
   //    campaign memory in Phase 6. The shape, not the numbers, is
   //    what matters in Phase 1.
   void DeriveTrinity()
     {
      if(!primed)
        {
         //-- engine cannot yet perceive — anchor at neutral
         life       = OMEGA_TRINITY_NEUTRAL;
         stability  = OMEGA_TRINITY_NEUTRAL;
         confidence = OMEGA_TRINITY_NEUTRAL;
         return;
        }
      //-- Phase 4 onward: Story::Update() writes life/stability/confidence
      //    DIRECTLY using the canonical formulas. DeriveTrinity is the
      //    safety gate — it only clamps to [0,100].
      life       = OmegaMath::Clamp(life,       0.0, 100.0);
      stability  = OmegaMath::Clamp(stability,  0.0, 100.0);
      confidence = OmegaMath::Clamp(confidence, 0.0, 100.0);
     }

   //--- short snapshot for logs
   string Snapshot() const
     {
      return StringFormat("L=%.1f S=%.1f C=%.1f primed=%s tick=%I64d",
                          life, stability, confidence,
                          primed ? "YES" : "NO", tickCount);
     }
  };

#endif // __OMEGA_MEMORY_MQH__

//==================================================================
//= MODULE: CampaignDB
//= Source: Include/CampaignDB.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                   CampaignDB.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 2 — Memory.                                              |
//|                                                                  |
//|   Every campaign becomes immortal. JSON shards under             |
//|   MQL5/Files/F72_Omega/campaigns/<SYMBOL>/. A monotonic id       |
//|   generator persisted via GlobalVariable so it survives          |
//|   recompiles and restarts. The campaign schema mirrors the spec  |
//|   exactly: birth, death, parent, children, compression /         |
//|   convexity / force profiles, recursion depth, transition type,  |
//|   failure swing, time, session, news environment, FU             |
//|   interactions, terminal induction, P&L attribution.             |
//|                                                                  |
//|   Phase 1 implements: schema, JSON serialize, persistent next-id |
//|   counter, and Save(). Load/scan, statistical roll-ups, and the  |
//|   chain-memory rolling JSON live in Phase 2/3 once the engine    |
//|   actually opens campaigns.                                      |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CAMPAIGNDB_MQH__
#define __OMEGA_CAMPAIGNDB_MQH__


//=== Campaign lifecycle ===========================================
enum ENUM_CAMPAIGN_STATE
  {
   CAMPAIGN_BORN          = 0,
   CAMPAIGN_LIVE          = 1,
   CAMPAIGN_DYING         = 2,
   CAMPAIGN_DEAD          = 3,
   CAMPAIGN_TRANSFERRED   = 4
  };

//=== Death cause taxonomy =========================================
enum ENUM_CAMPAIGN_DEATH_CAUSE
  {
   DEATH_NONE                  = 0,
   DEATH_OWNERSHIP_TRANSFER    = 1,
   DEATH_TERMINAL_INDUCTION    = 2,
   DEATH_FAILURE_SWING         = 3,
   DEATH_CHAIN_DECAY           = 4,
   DEATH_LIQUIDATION           = 5,
   DEATH_REGIME_SHIFT          = 6,
   DEATH_TIMEOUT               = 7
  };

//=== Per-campaign immortal record =================================
struct OmegaCampaign
  {
   long        id;
   string      symbol;
   datetime    birth;
   datetime    death;
   long        parentId;
   int         direction;          // 1 long, -1 short
   //--- recursion
   int         recursionDepth;
   int         recursionBudget;
   //--- profiles (snapshots at lifecycle stages)
   double      compressionAtBirth;
   double      compressionAtPeak;
   double      compressionAtDeath;
   double      convexityAtBirth;
   double      convexityAtPeak;
   double      convexityAtDeath;
   double      forceAtBirth;
   double      forcePeak;
   double      forceAtDeath;
   //--- narrative
   string      transitionType;
   string      failureSwingType;
   int         fuCount;
   bool        terminalInduction;
   //--- context
   ENUM_OMEGA_SESSION sessionContext;
   string      newsEnvironment;
   //--- terminal state
   ENUM_CAMPAIGN_STATE       state;
   ENUM_CAMPAIGN_DEATH_CAUSE deathCause;
   double      finalLife;
   double      finalStability;
   double      finalConfidence;
   //--- P&L attribution
   double      realizedPnl;
   int         positionCount;
   double      maxOpenRisk;

                    OmegaCampaign() { Reset(); }

   void Reset()
     {
      id = 0;
      symbol = "";
      birth = 0;
      death = 0;
      parentId = 0;
      direction = 0;
      recursionDepth = 0;
      recursionBudget = 0;
      compressionAtBirth = 0; compressionAtPeak = 0; compressionAtDeath = 0;
      convexityAtBirth   = 0; convexityAtPeak   = 0; convexityAtDeath   = 0;
      forceAtBirth       = 0; forcePeak         = 0; forceAtDeath       = 0;
      transitionType   = "";
      failureSwingType = "";
      fuCount = 0;
      terminalInduction = false;
      sessionContext = SESSION_OFF;
      newsEnvironment = "";
      state = CAMPAIGN_BORN;
      deathCause = DEATH_NONE;
      finalLife = 0; finalStability = 0; finalConfidence = 0;
      realizedPnl = 0;
      positionCount = 0;
      maxOpenRisk = 0;
     }

   string ToJson() const
     {
      string j = "{";
      j += StringFormat("\"id\":%I64d,",    id);
      j += StringFormat("\"symbol\":\"%s\",", OmegaStr::EscapeJson(symbol));
      j += StringFormat("\"birth\":\"%s\",",  TimeToString(birth, TIME_DATE|TIME_SECONDS));
      j += StringFormat("\"death\":\"%s\",",  death > 0 ? TimeToString(death, TIME_DATE|TIME_SECONDS) : "");
      j += StringFormat("\"parentId\":%I64d,",         parentId);
      j += StringFormat("\"direction\":%d,",           direction);
      j += StringFormat("\"recursionDepth\":%d,",      recursionDepth);
      j += StringFormat("\"recursionBudget\":%d,",     recursionBudget);
      j += "\"compression\":{";
      j += StringFormat("\"birth\":%.4f,\"peak\":%.4f,\"death\":%.4f",
                        compressionAtBirth, compressionAtPeak, compressionAtDeath);
      j += "},";
      j += "\"convexity\":{";
      j += StringFormat("\"birth\":%.4f,\"peak\":%.4f,\"death\":%.4f",
                        convexityAtBirth, convexityAtPeak, convexityAtDeath);
      j += "},";
      j += "\"force\":{";
      j += StringFormat("\"birth\":%.4f,\"peak\":%.4f,\"death\":%.4f",
                        forceAtBirth, forcePeak, forceAtDeath);
      j += "},";
      j += StringFormat("\"transitionType\":\"%s\",",   OmegaStr::EscapeJson(transitionType));
      j += StringFormat("\"failureSwingType\":\"%s\",", OmegaStr::EscapeJson(failureSwingType));
      j += StringFormat("\"fuCount\":%d,",              fuCount);
      j += StringFormat("\"terminalInduction\":%s,",    terminalInduction?"true":"false");
      j += StringFormat("\"session\":\"%s\",",          OmegaStr::SessionToString(sessionContext));
      j += StringFormat("\"newsEnvironment\":\"%s\",",  OmegaStr::EscapeJson(newsEnvironment));
      j += StringFormat("\"state\":%d,",                (int)state);
      j += StringFormat("\"deathCause\":%d,",           (int)deathCause);
      j += "\"final\":{";
      j += StringFormat("\"life\":%.2f,\"stability\":%.2f,\"confidence\":%.2f",
                        finalLife, finalStability, finalConfidence);
      j += "},";
      j += "\"pnl\":{";
      j += StringFormat("\"realized\":%.5f,\"positions\":%d,\"maxOpenRisk\":%.5f",
                        realizedPnl, positionCount, maxOpenRisk);
      j += "}}";
      return j;
     }
  };

//=== CampaignDB ====================================================
class CampaignDB
  {
private:
   string m_root;
   long   m_nextId;
   string m_idVar;

   string CampaignPath(string sym, long id) const
     {
      MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
      return StringFormat("%s/%s/campaign_%04d_%06d.json",
                          OMEGA_CAMPAIGN_DIR, sym, dt.year, (int)id);
     }

public:
                     CampaignDB() : m_nextId(1) {}

   bool Init()
     {
      m_root  = OMEGA_FILES_ROOT;
      m_idVar = "F72_OMEGA_NEXT_CAMPAIGN_ID";
      if(GlobalVariableCheck(m_idVar))
         m_nextId = (long)GlobalVariableGet(m_idVar);
      if(m_nextId <= 0) m_nextId = 1;
      OmegaLogger::LogInfo("CAMPAIGNDB",
         StringFormat("Initialized · root=%s · nextId=%I64d", m_root, m_nextId));
      return true;
     }

   long AllocateId()
     {
      long id = m_nextId++;
      GlobalVariableSet(m_idVar, (double)m_nextId);
      return id;
     }

   bool Save(const OmegaCampaign &c)
     {
      string path = CampaignPath(c.symbol, c.id);
      int h = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_ANSI);
      if(h == INVALID_HANDLE)
        {
         OmegaLogger::LogException("CAMPAIGNDB", GetLastError(),
            StringFormat("Save failed: %s", path));
         return false;
        }
      FileWriteString(h, c.ToJson());
      FileClose(h);
      OmegaLogger::LogDebug("CAMPAIGNDB",
         StringFormat("Saved campaign #%I64d (%s) -> %s", c.id, c.symbol, path));
      return true;
     }

   long PeekNextId() const { return m_nextId; }
  };

#endif // __OMEGA_CAMPAIGNDB_MQH__

//==================================================================
//= MODULE: Session
//= Source: Include/Session.mqh
//==================================================================
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

//==================================================================
//= MODULE: News
//= Source: Include/News.mqh
//==================================================================
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

//==================================================================
//= MODULE: Capital
//= Source: Include/Capital.mqh
//==================================================================
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

//==================================================================
//= MODULE: Risk
//= Source: Include/Risk.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                         Risk.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Risk does NOT sit outside the narrative. It reads the trinity  |
//|   directly and emits a per-trade % risk plus the equivalent      |
//|   broker-normalized lot size. The only inputs that matter are    |
//|     - life       (is the story alive?)                           |
//|     - stability  (how stable?)                                   |
//|     - confidence (how much do I trust myself?)                   |
//|     - capital throttle (drawdown breath)                         |
//|                                                                  |
//|   Tiers (defaults, overridable from EA inputs):                  |
//|     base         0.25%   — engine perceives but is uncertain     |
//|     normal       0.50%   — coherent narrative                    |
//|     strong       1.00%   — strong narrative                      |
//|     exceptional  2.00%   — exceptional alignment                 |
//|                                                                  |
//|   Hard ceiling 2% per trade — never exceeded regardless of state.|
//+------------------------------------------------------------------+
#ifndef __OMEGA_RISK_MQH__
#define __OMEGA_RISK_MQH__


//=== Phase 5.1 — Equity tier classification ========================
//   Same engine, same intelligence, different operating envelope per
//   account size. MICRO mode is opt-in (forced over-risk acknowledged).
enum ENUM_OMEGA_TIER
  {
   TIER_MICRO         = 0,   // <$200 — broker min dominates, A+ only
   TIER_SMALL         = 1,   // $200..$1K — ALIVE-tier only, light pyramid
   TIER_STANDARD      = 2,   // $1K..$50K — production
   TIER_LARGE         = 3,   // $50K..$500K — production + notional caps
   TIER_INSTITUTIONAL = 4    // >$500K — bounded by aggregate leverage
  };

//=== Phase 5.1.1 — Undersized-trade behavior =======================
//   When raw lot < broker volume_min, the engine clamps to broker_min
//   which can FORCE actual risk above the tier ceiling. This enum
//   says how to handle that case per-tier.
enum ENUM_OMEGA_UNDERSIZED
  {
   UNDERSIZED_AUTO     = 0,   // SKIP for STANDARD+, PROCEED for MICRO/SMALL
   UNDERSIZED_SKIP     = 1,   // never proceed when actual risk > tier ceiling
   UNDERSIZED_PROCEED  = 2,   // always proceed at broker min, log oversized
   UNDERSIZED_STRICT   = 3    // skip even when actual == intended (paranoid)
  };

class OmegaRisk
  {
private:
   double m_base;
   double m_normal;
   double m_strong;
   double m_exceptional;
   double m_hardCeiling;

   // Phase 5.1 — global guard parameters
   double m_minStopAtrMult;        // legacy (overridden by per-tier mults)
   int    m_minStopAtrPeriod;
   double m_maxNotionalPct;
   double m_microThreshold;
   double m_smallThreshold;
   double m_largeThreshold;
   double m_instThreshold;
   bool   m_allowMicro;
   double m_marginUseMaxPct;

   // Phase 5.1.1 — per-tier behavior matrix (idx = ENUM_OMEGA_TIER value)
   double m_tierMaxRiskPct[5];     // ceiling  per tier (8 / 3 / 1 / 1 / 0.75)
   double m_tierMinLife[5];        // floor    per tier (75 / 60 / 45 / 45 / 45)
   double m_tierMinStab[5];        //                   (65 / 55 / 45 / 45 / 45)
   double m_tierMinConf[5];        //                   (60 / 50 / 40 / 40 / 40)
   int    m_tierMaxBudget[5];      // max pyramid adds (1 / 2 / 3 / 4 / 4)
   double m_tierStopAtrMult[5];    // ATR floor mult   (1.25 / 0.85 / 0.75 / 0.75 / 0.75)

   bool   m_centAccount;           // ÷100 displayed equity for tier/sizing
   int    m_undersizedBehavior;    // ENUM_OMEGA_UNDERSIZED value

public:
                     OmegaRisk()
     {
      m_base        = 0.25;
      m_normal      = 0.50;
      m_strong      = 1.00;
      m_exceptional = 2.00;
      m_hardCeiling = 2.00;
      // Phase 5.1 defaults
      m_minStopAtrMult    = 0.75;
      m_minStopAtrPeriod  = 14;
      m_maxNotionalPct    = 1000.0;
      m_microThreshold    = 200.0;
      m_smallThreshold    = 1000.0;
      m_largeThreshold    = 50000.0;
      m_instThreshold     = 500000.0;
      m_allowMicro        = false;
      m_marginUseMaxPct   = 80.0;
      // Phase 5.1.1 — per-tier matrix defaults (match the spec)
      m_tierMaxRiskPct[TIER_MICRO]         = 8.00;
      m_tierMaxRiskPct[TIER_SMALL]         = 3.00;
      m_tierMaxRiskPct[TIER_STANDARD]      = 1.00;
      m_tierMaxRiskPct[TIER_LARGE]         = 1.00;
      m_tierMaxRiskPct[TIER_INSTITUTIONAL] = 0.75;
      m_tierMinLife[TIER_MICRO]         = 75.0;
      m_tierMinLife[TIER_SMALL]         = 60.0;
      m_tierMinLife[TIER_STANDARD]      = 45.0;
      m_tierMinLife[TIER_LARGE]         = 45.0;
      m_tierMinLife[TIER_INSTITUTIONAL] = 45.0;
      m_tierMinStab[TIER_MICRO]         = 65.0;
      m_tierMinStab[TIER_SMALL]         = 55.0;
      m_tierMinStab[TIER_STANDARD]      = 45.0;
      m_tierMinStab[TIER_LARGE]         = 45.0;
      m_tierMinStab[TIER_INSTITUTIONAL] = 45.0;
      m_tierMinConf[TIER_MICRO]         = 60.0;
      m_tierMinConf[TIER_SMALL]         = 50.0;
      m_tierMinConf[TIER_STANDARD]      = 40.0;
      m_tierMinConf[TIER_LARGE]         = 40.0;
      m_tierMinConf[TIER_INSTITUTIONAL] = 40.0;
      m_tierMaxBudget[TIER_MICRO]         = 1;
      m_tierMaxBudget[TIER_SMALL]         = 2;
      m_tierMaxBudget[TIER_STANDARD]      = 3;
      m_tierMaxBudget[TIER_LARGE]         = 4;
      m_tierMaxBudget[TIER_INSTITUTIONAL] = 4;
      m_tierStopAtrMult[TIER_MICRO]         = 1.25;
      m_tierStopAtrMult[TIER_SMALL]         = 0.85;
      m_tierStopAtrMult[TIER_STANDARD]      = 0.75;
      m_tierStopAtrMult[TIER_LARGE]         = 0.75;
      m_tierStopAtrMult[TIER_INSTITUTIONAL] = 0.75;
      m_centAccount         = false;
      m_undersizedBehavior  = UNDERSIZED_AUTO;
     }

   void Init(double basePct, double normalPct, double strongPct, double excepPct, double ceilingPct = 2.0)
     {
      m_base        = basePct;
      m_normal      = normalPct;
      m_strong      = strongPct;
      m_exceptional = excepPct;
      m_hardCeiling = ceilingPct;
      OmegaLogger::LogInfo("RISK",
         StringFormat("Initialized · base=%.2f%% normal=%.2f%% strong=%.2f%% excep=%.2f%% ceiling=%.2f%%",
                      basePct, normalPct, strongPct, excepPct, ceilingPct));
     }

   //--- Phase 5.1 — install equity guards (called from EA OnInit after Init).
   void InitGuards(double minStopAtrMult, int minStopAtrPeriod,
                   double maxNotionalPct, double microThr, double smallThr,
                   double largeThr, double instThr, bool allowMicro,
                   double marginUseMaxPct)
     {
      m_minStopAtrMult    = minStopAtrMult;
      m_minStopAtrPeriod  = minStopAtrPeriod;
      m_maxNotionalPct    = maxNotionalPct;
      m_microThreshold    = microThr;
      m_smallThreshold    = smallThr;
      m_largeThreshold    = largeThr;
      m_instThreshold     = instThr;
      m_allowMicro        = allowMicro;
      m_marginUseMaxPct   = marginUseMaxPct;
      OmegaLogger::LogInfo("RISK",
         StringFormat("Guards · stopFloor=%.2f×ATR(%d) · notionalCap=%.0f%% equity · tiers MICRO<%.0f SMALL<%.0f LARGE<%.0f INST≥%.0f · allowMicro=%s · marginUseMax=%.0f%%",
                      minStopAtrMult, minStopAtrPeriod, maxNotionalPct,
                      microThr, smallThr, largeThr, instThr,
                      allowMicro ? "YES" : "NO", marginUseMaxPct));
     }

   //--- Phase 5.1.1 — install per-tier behavior matrix.
   //    Order: MICRO, SMALL, STANDARD, LARGE, INSTITUTIONAL.
   void InitTiers(double microMaxR, double smallMaxR, double stdMaxR, double largeMaxR, double instMaxR,
                  double microL, double microS, double microC,
                  double smallL, double smallS, double smallC,
                  int microBudget, int smallBudget, int stdBudget, int largeBudget, int instBudget,
                  double microStopAtr, double smallStopAtr, double stdStopAtr, double largeStopAtr, double instStopAtr,
                  bool centAccount, int undersizedBehavior)
     {
      m_tierMaxRiskPct[TIER_MICRO]         = microMaxR;
      m_tierMaxRiskPct[TIER_SMALL]         = smallMaxR;
      m_tierMaxRiskPct[TIER_STANDARD]      = stdMaxR;
      m_tierMaxRiskPct[TIER_LARGE]         = largeMaxR;
      m_tierMaxRiskPct[TIER_INSTITUTIONAL] = instMaxR;
      m_tierMinLife[TIER_MICRO] = microL; m_tierMinStab[TIER_MICRO] = microS; m_tierMinConf[TIER_MICRO] = microC;
      m_tierMinLife[TIER_SMALL] = smallL; m_tierMinStab[TIER_SMALL] = smallS; m_tierMinConf[TIER_SMALL] = smallC;
      m_tierMaxBudget[TIER_MICRO] = microBudget;
      m_tierMaxBudget[TIER_SMALL] = smallBudget;
      m_tierMaxBudget[TIER_STANDARD] = stdBudget;
      m_tierMaxBudget[TIER_LARGE] = largeBudget;
      m_tierMaxBudget[TIER_INSTITUTIONAL] = instBudget;
      m_tierStopAtrMult[TIER_MICRO]         = microStopAtr;
      m_tierStopAtrMult[TIER_SMALL]         = smallStopAtr;
      m_tierStopAtrMult[TIER_STANDARD]      = stdStopAtr;
      m_tierStopAtrMult[TIER_LARGE]         = largeStopAtr;
      m_tierStopAtrMult[TIER_INSTITUTIONAL] = instStopAtr;
      m_centAccount        = centAccount;
      m_undersizedBehavior = undersizedBehavior;
      OmegaLogger::LogInfo("RISK",
         StringFormat("Tiers · ceil M/S/T/L/I=%.2f/%.2f/%.2f/%.2f/%.2f%% · MICRO floor L%.0f S%.0f C%.0f · SMALL floor L%.0f S%.0f C%.0f · pyramid M/S/T/L/I=%d/%d/%d/%d/%d · stopATR M/S/T/L/I=%.2f/%.2f/%.2f/%.2f/%.2f · cent=%s · undersized=%s",
                      microMaxR, smallMaxR, stdMaxR, largeMaxR, instMaxR,
                      microL, microS, microC, smallL, smallS, smallC,
                      microBudget, smallBudget, stdBudget, largeBudget, instBudget,
                      microStopAtr, smallStopAtr, stdStopAtr, largeStopAtr, instStopAtr,
                      centAccount ? "YES" : "NO", UndersizedStr(undersizedBehavior)));
     }

   //--- Phase 5.1.1 — cent-aware effective equity. Use this everywhere
   //    we classify tier or compute notional caps.
   double EffectiveEquity(const OmegaCapital &cap) const
     {
      double raw = cap.Equity();
      return m_centAccount ? (raw / 100.0) : raw;
     }

   //--- Tier resolution (live equity → tier) — applies cent correction.
   ENUM_OMEGA_TIER TierFor(double equity) const
     {
      if(equity < m_microThreshold)  return TIER_MICRO;
      if(equity < m_smallThreshold)  return TIER_SMALL;
      if(equity < m_largeThreshold)  return TIER_STANDARD;
      if(equity < m_instThreshold)   return TIER_LARGE;
      return TIER_INSTITUTIONAL;
     }

   ENUM_OMEGA_TIER TierForCap(const OmegaCapital &cap) const
     {
      return TierFor(EffectiveEquity(cap));
     }

   string TierStr(ENUM_OMEGA_TIER t) const
     {
      switch(t)
        {
         case TIER_MICRO:         return "MICRO";
         case TIER_SMALL:         return "SMALL";
         case TIER_STANDARD:      return "STANDARD";
         case TIER_LARGE:         return "LARGE";
         case TIER_INSTITUTIONAL: return "INSTITUTIONAL";
        }
      return "?";
     }

   string UndersizedStr(int m) const
     {
      switch(m)
        {
         case UNDERSIZED_AUTO:    return "AUTO";
         case UNDERSIZED_SKIP:    return "SKIP";
         case UNDERSIZED_PROCEED: return "PROCEED";
         case UNDERSIZED_STRICT:  return "STRICT";
        }
      return "?";
     }

   //--- Per-tier accessors (used by CampaignPositions).
   double TierMaxRiskPct(ENUM_OMEGA_TIER t) const { return m_tierMaxRiskPct[(int)t]; }
   double TierMinLife(ENUM_OMEGA_TIER t)    const { return m_tierMinLife[(int)t]; }
   double TierMinStab(ENUM_OMEGA_TIER t)    const { return m_tierMinStab[(int)t]; }
   double TierMinConf(ENUM_OMEGA_TIER t)    const { return m_tierMinConf[(int)t]; }
   int    TierMaxBudget(ENUM_OMEGA_TIER t)  const { return m_tierMaxBudget[(int)t]; }
   double TierStopAtrMult(ENUM_OMEGA_TIER t) const { return m_tierStopAtrMult[(int)t]; }

   //--- Phase 5.6 — CANONICAL F72 RULE: components are CONTRIBUTORS,
   //    never gates. The only catastrophic vetoes left here are:
   //    (a) opt-in MICRO tier — the user must explicitly consent to
   //        broker-min-forced over-risk on tiny accounts, and
   //    (b) state.primed during cold-start (no perception yet → tiny
   //        size, never zero unless engine is fully unprimed).
   //
   //    Returns a CONTINUOUS conviction-weighted % risk. A weak
   //    Trinity produces a small size, NOT a refusal. Risk and
   //    DecisionEngine work together: DecisionEngine emits an action
   //    + conviction + EV; Risk turns conviction × EV × tier_cap
   //    into the actual size in % equity.
   double RiskPctFor(const OmegaState &s, ENUM_OMEGA_TIER tier) const
     {
      double cap = MathMin(TierMaxRiskPct(tier), m_hardCeiling);
      if(tier == TIER_MICRO && !m_allowMicro) return 0.0;       // catastrophic: opt-in
      if(!s.primed) return cap * 0.10;                          // small fallback during warmup
      //   Continuous conviction proxy when no explicit conviction is
      //   passed (DecisionEngine builds the proper one and uses
      //   RiskPctFromConviction below).
      double trinity = s.life * 0.30 + s.stability * 0.15 + s.confidence * 0.15;
      double naFactor = s.supporting.alignment * 0.40;
      double conv = MathMax(0.0, MathMin(100.0, trinity + naFactor));
      return cap * (conv / 100.0);
     }

   //--- Phase 5.6 — explicit conviction-from-DecisionEngine sizing.
   //    The recommended path. conviction in 0..100, evMult in 0..2,
   //    tier cap from TierMaxRiskPct. NO component-level vetoes.
   double RiskPctFromConviction(double conviction, double evMult, ENUM_OMEGA_TIER tier) const
     {
      if(tier == TIER_MICRO && !m_allowMicro) return 0.0;       // catastrophic: opt-in
      double cap = MathMin(TierMaxRiskPct(tier), m_hardCeiling);
      double pct = cap * (conviction / 100.0) * MathMax(0.1, evMult);
      return MathMax(0.0, MathMin(cap, pct));
     }

   //--- Backwards-compatible legacy entrypoint (no tier).
   double RiskPctFor(const OmegaState &s) const
     {
      return RiskPctFor(s, TIER_STANDARD);
     }

   //--- Phase 5.1.1 — per-tier ATR stop floor.
   double ResolveStopPoints(string symbol, double rawStopDistPoints, ENUM_OMEGA_TIER tier) const
     {
      double mult = TierStopAtrMult(tier);
      if(mult <= 0.0 || m_minStopAtrPeriod <= 0) return rawStopDistPoints;
      int handle = iATR(symbol, _Period, m_minStopAtrPeriod);
      if(handle == INVALID_HANDLE) return rawStopDistPoints;
      double buf[];
      ArraySetAsSeries(buf, true);
      int copied = CopyBuffer(handle, 0, 0, 1, buf);
      IndicatorRelease(handle);
      if(copied <= 0 || buf[0] <= 0) return rawStopDistPoints;
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0) return rawStopDistPoints;
      double atrPts   = buf[0] / point;
      double floorPts = atrPts * mult;
      return MathMax(rawStopDistPoints, floorPts);
     }

   //--- Backwards-compatible legacy entrypoint (no tier → STANDARD).
   double ResolveStopPoints(string symbol, double rawStopDistPoints) const
     {
      return ResolveStopPoints(symbol, rawStopDistPoints, TIER_STANDARD);
     }

   //--- Phase 5.1.1 — compute the actual risk % from the final lots
   //    after broker rounding. Used to detect "broker min forced
   //    actual > intended" undersized scenarios.
   double CalcActualRiskPct(string symbol, double lots, double stopDistPoints, double equity) const
     {
      if(lots <= 0 || stopDistPoints <= 0 || equity <= 0) return 0.0;
      double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(tickSize <= 0 || tickValue <= 0 || point <= 0) return 0.0;
      double lossPerLot = (stopDistPoints * point / tickSize) * tickValue;
      double lossMoney  = lossPerLot * lots;
      return (lossMoney / equity) * 100.0;
     }

   //--- Phase 5.1.1 — decide whether to proceed when broker-min forces
   //    actual > intended risk. Returns true to PROCEED, false to SKIP.
   bool ResolveUndersized(ENUM_OMEGA_TIER tier, double intendedPct, double actualPct) const
     {
      if(actualPct <= intendedPct + 0.01) return true;          // not actually over (epsilon)
      int mode = m_undersizedBehavior;
      if(mode == UNDERSIZED_STRICT)  return false;
      if(mode == UNDERSIZED_SKIP)    return false;
      if(mode == UNDERSIZED_PROCEED) return true;
      // AUTO: only MICRO and SMALL get to proceed at broker-min over-risk
      return (tier == TIER_MICRO || tier == TIER_SMALL);
     }

   //--- Convert risk% + stop distance to broker-normalized lots.
   //    Phase 5.1: applies notional cap, broker bounds, step rounding.
   double LotsFor(string symbol, double riskPct, double stopDistPoints, const OmegaCapital &cap) const
     {
      riskPct = OmegaMath::Clamp(riskPct, 0.0, m_hardCeiling);
      double throttle = cap.Throttle();
      double effectivePct = riskPct * throttle;
      if(effectivePct <= 0.0) return 0.0;

      double equity = EffectiveEquity(cap);
      double riskMoney = equity * effectivePct / 100.0;

      double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(tickSize <= 0 || tickValue <= 0 || point <= 0 || stopDistPoints <= 0) return 0.0;

      double lossPerLot = (stopDistPoints * point / tickSize) * tickValue;
      if(lossPerLot <= 0) return 0.0;

      double lots = riskMoney / lossPerLot;

      //--- notional cap (per-ticket lots ≤ N% of equity ÷ contract value).
      if(m_maxNotionalPct > 0.0)
        {
         double contract = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
         double askPx    = SymbolInfoDouble(symbol, SYMBOL_ASK);
         if(askPx <= 0) askPx = SymbolInfoDouble(symbol, SYMBOL_BID);
         if(contract > 0 && askPx > 0)
           {
            double notionalCap = (equity * m_maxNotionalPct / 100.0) / (askPx * contract);
            if(notionalCap > 0 && lots > notionalCap)
              {
               OmegaLogger::LogInfo("RISK",
                  StringFormat("%s · notional cap engaged · lots %.2f→%.2f (≤%.0f%% equity)",
                               symbol, lots, notionalCap, m_maxNotionalPct));
               lots = notionalCap;
              }
           }
        }

      double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      if(stepLot <= 0) stepLot = 0.01;
      lots = MathFloor(lots / stepLot) * stepLot;
      lots = OmegaMath::Clamp(lots, minLot, maxLot);
      return lots;
     }

   //--- Phase 5.1 — pre-trade margin precheck. Returns true if free
   //    margin can absorb the position at the configured ceiling.
   bool PassesMarginCheck(string symbol, int direction, double lots, double openPx) const
     {
      if(lots <= 0 || m_marginUseMaxPct <= 0.0) return true;
      double margin = 0.0;
      ENUM_ORDER_TYPE ot = (direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(!OrderCalcMargin(ot, symbol, lots, openPx, margin)) return true;
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(freeMargin <= 0) return false;
      bool ok = (margin <= freeMargin * (m_marginUseMaxPct / 100.0));
      if(!ok)
         OmegaLogger::LogWarning("RISK",
            StringFormat("%s · margin precheck FAIL · req=%.2f freeMargin=%.2f cap=%.0f%%",
                          symbol, margin, freeMargin, m_marginUseMaxPct));
      return ok;
     }

   //--- accessors
   double Base()        const { return m_base; }
   double Normal()      const { return m_normal; }
   double Strong()      const { return m_strong; }
   double Exceptional() const { return m_exceptional; }
   double HardCeiling() const { return m_hardCeiling; }
   bool   AllowMicro()  const { return m_allowMicro; }
   bool   CentAccount() const { return m_centAccount; }
   int    UndersizedBehavior() const { return m_undersizedBehavior; }
  };

#endif // __OMEGA_RISK_MQH__

//==================================================================
//= MODULE: PaperTrade
//= Source: Include/PaperTrade.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                  PaperTrade.mqh  |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Order shell. Wraps CTrade. In OBSERVER / COPILOT / PAPER /     |
//|   SHADOW modes intercepts every order call, logs it via the      |
//|   structured execution log, and returns success WITHOUT sending. |
//|   Only AUTONOMOUS mode passes through to the real CTrade.        |
//|                                                                  |
//|   This is the explainability barrier between the engine and the |
//|   broker — every Phase from 5 onward executes through here, so  |
//|   shadow / paper / live paths all share identical accounting.   |
//+------------------------------------------------------------------+
#ifndef __OMEGA_PAPER_MQH__
#define __OMEGA_PAPER_MQH__

#include <Trade/Trade.mqh>

class OmegaPaperTrade
  {
private:
   CTrade            m_trade;
   ENUM_OMEGA_MODE   m_mode;
   ulong             m_paperTicket;       // monotonic faux ticket for paper trades

   bool LiveMode() const { return (m_mode == OMEGA_MODE_AUTONOMOUS); }

public:
                     OmegaPaperTrade()
     {
      m_mode        = OMEGA_MODE_AUTONOMOUS;
      m_paperTicket = 1000000;
     }

   void Init(ENUM_OMEGA_MODE mode, ulong magic, int slippagePts = 20)
     {
      m_mode = mode;
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints((ulong)slippagePts);
      m_trade.SetTypeFillingBySymbol(_Symbol);
      m_trade.SetMarginMode();
      OmegaLogger::LogInfo("PAPER",
         StringFormat("Init · mode=%s · magic=%I64u · slippagePts=%d",
                      OmegaStr::ModeToString(mode), magic, slippagePts));
     }

   void SetMode(ENUM_OMEGA_MODE mode)
     {
      if(mode != m_mode)
        {
         OmegaLogger::LogWarning("PAPER",
            StringFormat("Mode changed %s -> %s",
                         OmegaStr::ModeToString(m_mode),
                         OmegaStr::ModeToString(mode)));
         m_mode = mode;
        }
     }
   ENUM_OMEGA_MODE Mode() const { return m_mode; }

   //--- BUY → returns broker ticket (or paper ticket); 0 = failure
   ulong Buy(string symbol, double lots, double sl, double tp, ENUM_OMEGA_REASON reason, string detail)
     {
      double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(LiveMode())
        {
         bool ok = m_trade.Buy(lots, symbol, price, sl, tp, detail);
         ulong tk = m_trade.ResultOrder();
         OmegaLogger::LogExecution(symbol, "BUY", tk,
                                    m_trade.ResultPrice(), lots, reason,
            StringFormat("live=%s ret=%u %s", ok?"true":"false",
                         m_trade.ResultRetcode(), detail));
         return ok ? tk : 0;
        }
      ulong ticket = ++m_paperTicket;
      OmegaLogger::LogExecution(symbol, "BUY-PAPER", ticket, price, lots, reason,
         StringFormat("sl=%.5f tp=%.5f %s", sl, tp, detail));
      return ticket;
     }

   //--- SELL → returns broker ticket (or paper ticket); 0 = failure
   ulong Sell(string symbol, double lots, double sl, double tp, ENUM_OMEGA_REASON reason, string detail)
     {
      double price = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(LiveMode())
        {
         bool ok = m_trade.Sell(lots, symbol, price, sl, tp, detail);
         ulong tk = m_trade.ResultOrder();
         OmegaLogger::LogExecution(symbol, "SELL", tk,
                                    m_trade.ResultPrice(), lots, reason,
            StringFormat("live=%s ret=%u %s", ok?"true":"false",
                         m_trade.ResultRetcode(), detail));
         return ok ? tk : 0;
        }
      ulong ticket = ++m_paperTicket;
      OmegaLogger::LogExecution(symbol, "SELL-PAPER", ticket, price, lots, reason,
         StringFormat("sl=%.5f tp=%.5f %s", sl, tp, detail));
      return ticket;
     }

   //--- CLOSE
   bool Close(ulong ticket, ENUM_OMEGA_REASON reason, string detail)
     {
      if(LiveMode())
        {
         bool ok = m_trade.PositionClose(ticket);
         OmegaLogger::LogExecution("-", "CLOSE", ticket, 0, 0, reason,
            StringFormat("live=%s ret=%u %s", ok?"true":"false",
                         m_trade.ResultRetcode(), detail));
         return ok;
        }
      OmegaLogger::LogExecution("-", "CLOSE-PAPER", ticket, 0, 0, reason, detail);
      return true;
     }

   //--- Modify SL/TP (used by PositionHealth in Phase 5)
   bool ModifySLTP(ulong ticket, double sl, double tp, ENUM_OMEGA_REASON reason, string detail)
     {
      if(LiveMode())
        {
         bool ok = m_trade.PositionModify(ticket, sl, tp);
         OmegaLogger::LogExecution("-", "MODIFY", ticket, 0, 0, reason,
            StringFormat("sl=%.5f tp=%.5f live=%s ret=%u %s",
                         sl, tp, ok?"true":"false", m_trade.ResultRetcode(), detail));
         return ok;
        }
      OmegaLogger::LogExecution("-", "MODIFY-PAPER", ticket, 0, 0, reason,
         StringFormat("sl=%.5f tp=%.5f %s", sl, tp, detail));
      return true;
     }
  };

#endif // __OMEGA_PAPER_MQH__

//==================================================================
//= MODULE: Curve/CurvePhysics
//= Source: Include/Curve/CurvePhysics.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                 CurvePhysics.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 0 → 4 — physics primitives.                              |
//|                                                                  |
//|   Direct MQL5 port of the Pine `f_phys` function: ATR, velocity, |
//|   acceleration, convexity, smoothed convexity, efficiency,       |
//|   displacement, plus the impulse / decay / convexity-shift /     |
//|   velocity-decay flags. Everything is computed on the LAST       |
//|   CLOSED bar (shift=1) for the symbol+timeframe instance owned   |
//|   by this object. New bar detection via iTime() change.          |
//|                                                                  |
//|   This is the smallest, fastest unit of perception. CurveState   |
//|   owns one CurvePhysics; the structure engine reads from it.     |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CURVE_PHYSICS_MQH__
#define __OMEGA_CURVE_PHYSICS_MQH__


class CurvePhysics
  {
public:
   //--- inputs
   string             symbol;
   ENUM_TIMEFRAMES    tf;
   int                atrLen;
   int                effLen;
   double             effT;       // efficiency threshold
   double             dispT;      // displacement threshold
   double             convM;      // convexity multiplier (x atr)

   //--- last-closed-bar derived values
   double             atr;
   double             vel;        // ema(close-close[1], 3) at this bar
   double             velPrev;    // ema at previous bar
   double             acc;        // vel - velPrev
   double             accPrev;
   double             cvx;        // acc - accPrev
   double             csm;        // ema(cvx, 3)
   double             csmPrev;
   double             eff;        // efficiency 0..1
   double             disp;       // (high-low)/atr
   double             cth;        // atr * convM (convexity threshold)
   //--- flags
   bool               bullImpulse, bearImpulse;
   bool               bullDecay,   bearDecay;
   bool               bullConvShift, bearConvShift;
   bool               velDec70, velDec50;

   //--- bookkeeping
   datetime           lastBarTime;
   bool               ready;       // false until at least 2 bars processed
   long               barsProcessed;

private:
   int                m_handleATR;

public:
                     CurvePhysics()
     {
      symbol = "";
      tf = PERIOD_CURRENT;
      atrLen = 14; effLen = 10;
      effT = 0.65; dispT = 1.5; convM = 0.01;
      m_handleATR = INVALID_HANDLE;
      Reset();
     }

   void Reset()
     {
      atr = 0; vel = 0; velPrev = 0; acc = 0; accPrev = 0;
      cvx = 0; csm = 0; csmPrev = 0;
      eff = 0; disp = 0; cth = 0;
      bullImpulse = bearImpulse = false;
      bullDecay   = bearDecay   = false;
      bullConvShift = bearConvShift = false;
      velDec70 = velDec50 = false;
      lastBarTime = 0;
      ready = false;
      barsProcessed = 0;
     }

   bool Init(string sym, ENUM_TIMEFRAMES timeframe,
             int atrL = 14, int effL = 10,
             double effThresh = 0.65, double dispThresh = 1.5, double convMult = 0.01)
     {
      symbol = sym;
      tf = timeframe;
      atrLen = atrL; effLen = effL;
      effT = effThresh; dispT = dispThresh; convM = convMult;
      m_handleATR = iATR(symbol, tf, atrLen);
      if(m_handleATR == INVALID_HANDLE)
        {
         OmegaLogger::LogException("PHYSICS", GetLastError(),
            StringFormat("iATR failed sym=%s tf=%d", symbol, (int)tf));
         return false;
        }
      return true;
     }

   void Deinit()
     {
      if(m_handleATR != INVALID_HANDLE)
        {
         IndicatorRelease(m_handleATR);
         m_handleATR = INVALID_HANDLE;
        }
     }

   //--- Process the latest closed bar if it's new since last call.
   //    Returns true when a new bar was processed (caller may chain
   //    structure-engine updates only on those).
   bool Update()
     {
      datetime barT = iTime(symbol, tf, 1);
      if(barT == 0) return false;          // history not ready
      if(barT == lastBarTime) return false;  // no new closed bar

      //--- need at least effLen+2 bars of history
      int rates_total = Bars(symbol, tf);
      if(rates_total < effLen + 4) return false;

      //--- ATR
      double atrBuf[];
      if(CopyBuffer(m_handleATR, 0, 1, 1, atrBuf) <= 0) return false;
      double newAtr = atrBuf[0];
      if(newAtr <= 0) return false;

      //--- pull bar series
      double close1 = iClose(symbol, tf, 1);
      double close2 = iClose(symbol, tf, 2);
      double open1  = iOpen(symbol,  tf, 1);
      double high1  = iHigh(symbol,  tf, 1);
      double low1   = iLow(symbol,   tf, 1);
      if(close1 == 0 || close2 == 0) return false;

      //--- velocity = ema(diff, 3)
      double diff   = close1 - close2;
      double alphaV = 2.0 / (3.0 + 1.0);
      double newVelEma;
      if(barsProcessed == 0)
         newVelEma = diff;
      else
         newVelEma = alphaV * diff + (1.0 - alphaV) * vel;

      double newVelPrev = vel;
      double newVel     = newVelEma;
      double newAcc     = newVel - newVelPrev;
      double newAccPrev = acc;
      double newCvx     = newAcc - newAccPrev;

      //--- csm = ema(cvx, 3)
      double alphaC = 2.0 / (3.0 + 1.0);
      double newCsmPrev = csm;
      double newCsm;
      if(barsProcessed == 0)
         newCsm = newCvx;
      else
         newCsm = alphaC * newCvx + (1.0 - alphaC) * csm;

      //--- efficiency
      double newEff = 0.0;
      if(effLen > 1 && rates_total >= effLen + 2)
        {
         double mv = MathAbs(close1 - iClose(symbol, tf, 1 + effLen));
         double ps = 0.0;
         for(int i = 1; i <= effLen; i++)
            ps += MathAbs(iClose(symbol, tf, i) - iClose(symbol, tf, i + 1));
         newEff = (ps > 1e-10) ? (mv / ps) : 0.0;
        }

      double newDisp = (high1 - low1) / MathMax(newAtr, 1e-10);
      double newCth  = newAtr * convM;

      //--- commit
      atr      = newAtr;
      velPrev  = newVelPrev;
      vel      = newVel;
      accPrev  = newAccPrev;
      acc      = newAcc;
      cvx      = newCvx;
      csmPrev  = newCsmPrev;
      csm      = newCsm;
      eff      = newEff;
      disp     = newDisp;
      cth      = newCth;

      bullImpulse   = eff > effT && vel > velPrev && acc > 0 && close1 > open1 && disp > dispT;
      bearImpulse   = eff > effT && vel < velPrev && acc < 0 && close1 < open1 && disp > dispT;
      bullDecay     = MathAbs(acc) < MathAbs(accPrev) * 0.8 && vel > 0;
      bearDecay     = MathAbs(acc) < MathAbs(accPrev) * 0.8 && vel < 0;
      bullConvShift = csm >  cth && csmPrev <=  cth;
      bearConvShift = csm < -cth && csmPrev >= -cth;
      velDec70      = MathAbs(vel) < MathAbs(velPrev) * 0.7;
      velDec50      = MathAbs(vel) < MathAbs(velPrev) * 0.5;

      lastBarTime    = barT;
      barsProcessed += 1;
      ready          = (barsProcessed >= 2);
      return true;
     }
  };

#endif // __OMEGA_CURVE_PHYSICS_MQH__

//==================================================================
//= MODULE: Curve/CurveState
//= Source: Include/Curve/CurveState.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                   CurveState.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 0–7 — the f_se port. Single-timeframe structure engine.  |
//|   The SOLE lifecycle authority for one curve on one TF.          |
//|                                                                  |
//|   What it owns:                                                  |
//|     - confirmed pivot highs / lows (lookback pivot detection)    |
//|     - swing memory (curSH/curSL/prSH/prSL + lastP/prevP)          |
//|     - BOS / CHoCH detection                                      |
//|     - SPAWN engine: when a wave is BORN (impulse / flip)         |
//|     - wave context: dir, flip zone (ft/fb), point4, invalidation |
//|       target, cycle high/low                                     |
//|     - inducement state machine (bos1/bos2, indOrig/indExt/indBrk)|
//|     - convexity / expansion / absorption scores                  |
//|     - compression index (0..100, high = squeezed)                |
//|     - wave progress %                                            |
//|     - direction-by-origin (close vs invalidation)                |
//|                                                                  |
//|   Owns one CurvePhysics. Updates are driven on closed bars only. |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CURVE_STATE_MQH__
#define __OMEGA_CURVE_STATE_MQH__


class CurveState
  {
public:
   //--- physics
   CurvePhysics      physics;

   //--- structure inputs
   int               pivotLen;
   int               structLen;
   double            impMult;
   double            chBufATR;

   //--- swing memory
   double            curSH;
   double            curSL;
   double            prSH;
   double            prSL;
   double            lastPivotPrice;
   int               lastPivotDir;
   double            prevPivotPrice;
   int               prevPivotDir;

   //--- wave context (the structure engine's outputs)
   int               dir;          // -1, 0, +1
   double            ft;           // flip zone top
   double            fb;           // flip zone bot
   double            p4h;          // point 4 high
   double            p4l;          // point 4 low
   double            inv;          // invalidation
   double            tgt;          // wave target
   double            cycH;         // running cycle high
   double            cycL;         // running cycle low

   //--- per-bar event flags
   bool              bullBOS, bearBOS;
   bool              bullCH,  bearCH;
   bool              spawnedThisBar;
   bool              isReversal;

   //--- inducement
   bool              bos1, bos2;
   double            protSw, protSw2;
   double            indOrig, indExt;
   bool              indBrk;
   int               lastDirSeen;

   //--- composite scores (read by helpers)
   double            convScore;     // 0..100
   double            expScore;      // 0..100
   double            absScore;      // 0..100
   double            compIdx;       // 0..100 (compression)
   double            waveProgress;  // 0..100
   double            waveModelFit;  // 0..100

   //--- bookkeeping
   string            symbol;
   ENUM_TIMEFRAMES   tf;
   bool              ready;
   long              barsProcessed;
   datetime          lastBarTime;

                     CurveState()
     {
      pivotLen = 5;
      structLen = 10;
      impMult = 1.5;
      chBufATR = 0.75;
      Reset();
     }

   void Reset()
     {
      curSH = curSL = prSH = prSL = 0.0;
      lastPivotPrice = 0.0; lastPivotDir = 0;
      prevPivotPrice = 0.0; prevPivotDir = 0;
      dir = 0;
      ft = fb = p4h = p4l = inv = tgt = 0.0;
      cycH = cycL = 0.0;
      bullBOS = bearBOS = bullCH = bearCH = false;
      spawnedThisBar = false; isReversal = false;
      bos1 = bos2 = false; protSw = protSw2 = 0.0;
      indOrig = indExt = 0.0; indBrk = false;
      lastDirSeen = 0;
      convScore = expScore = absScore = 0.0;
      compIdx = waveProgress = waveModelFit = 0.0;
      ready = false;
      barsProcessed = 0;
      lastBarTime = 0;
     }

   bool Init(string sym, ENUM_TIMEFRAMES timeframe,
             int pvLen = 5, int stLen = 10,
             double impulseMult = 1.5, double chochBufATR = 0.75,
             int atrL = 14, int effL = 10,
             double effThresh = 0.65, double dispThresh = 1.5, double convMult = 0.01)
     {
      symbol    = sym;
      tf        = timeframe;
      pivotLen  = pvLen;
      structLen = stLen;
      impMult   = impulseMult;
      chBufATR  = chochBufATR;
      return physics.Init(sym, timeframe, atrL, effL, effThresh, dispThresh, convMult);
     }

   void Deinit() { physics.Deinit(); }

   //--- Detects whether the bar at `candidateShift` is a confirmed pivot
   //    high (highest within 2*pivotLen+1 window centred on it).
   bool DetectPivotHigh(double &outPrice)
     {
      int candidate = 1 + pivotLen;
      int total = Bars(symbol, tf);
      if(total < candidate + pivotLen + 1) return false;
      int hiShift = iHighest(symbol, tf, MODE_HIGH, 2 * pivotLen + 1, 1);
      if(hiShift != candidate) return false;
      outPrice = iHigh(symbol, tf, candidate);
      return outPrice > 0;
     }
   bool DetectPivotLow(double &outPrice)
     {
      int candidate = 1 + pivotLen;
      int total = Bars(symbol, tf);
      if(total < candidate + pivotLen + 1) return false;
      int loShift = iLowest(symbol, tf, MODE_LOW, 2 * pivotLen + 1, 1);
      if(loShift != candidate) return false;
      outPrice = iLow(symbol, tf, candidate);
      return outPrice > 0;
     }

   //--- Spawn a new wave context (called when impulse or flip detected).
   void Spawn(int newDir)
     {
      double hi = MathMax(lastPivotPrice, prevPivotPrice);
      double lo = MathMin(lastPivotPrice, prevPivotPrice);
      double obT = hi;
      double obB = lo;
      dir = newDir;
      ft  = obT;
      fb  = obB;
      p4h = obT;
      p4l = obB;
      double bar1Hi = iHigh(symbol, tf, 1);
      double bar1Lo = iLow(symbol, tf, 1);
      cycH = bar1Hi;
      cycL = bar1Lo;
      inv  = (newDir == 1) ? lo : hi;
      double rng = (prSH > 0 && prSL > 0) ? MathAbs(prSH - prSL) : physics.atr * 5.0;
      tgt = (newDir == 1) ? (obT + rng) : (obB - rng);
      spawnedThisBar = true;
      OmegaLogger::LogDebug("CURVE", StringFormat(
         "%s/%d · SPAWN dir=%d ft=%.5f fb=%.5f inv=%.5f tgt=%.5f",
         symbol, (int)tf, newDir, ft, fb, inv, tgt));
     }

   //--- Main per-bar update.
   bool Update()
     {
      spawnedThisBar = false;
      bullBOS = bearBOS = bullCH = bearCH = false;
      isReversal = false;

      //-- only advance the structure engine when physics advanced
      if(!physics.Update()) return false;

      double bar1Close = iClose(symbol, tf, 1);
      double bar1High  = iHigh(symbol, tf, 1);
      double bar1Low   = iLow(symbol, tf, 1);
      double atr       = physics.atr;
      if(atr <= 0) return false;

      //-- 1. PIVOT detection (confirmed pivots, lagged by pivotLen)
      double pH = 0.0, pL = 0.0;
      bool foundPH = DetectPivotHigh(pH);
      bool foundPL = DetectPivotLow(pL);
      if(foundPH)
        {
         prSH  = (curSH == 0.0) ? pH : curSH;
         curSH = pH;
        }
      if(foundPL)
        {
         prSL  = (curSL == 0.0) ? pL : curSL;
         curSL = pL;
        }

      //-- track last/prev pivot (for impulse / flip math)
      double eP = 0.0;
      int    eD = 0;
      if(foundPH)      { eP = pH; eD = 1; }
      else if(foundPL) { eP = pL; eD = -1; }
      if(eD != 0)
        {
         prevPivotPrice = lastPivotPrice;
         prevPivotDir   = lastPivotDir;
         lastPivotPrice = eP;
         lastPivotDir   = eD;
        }

      //-- 2. BOS / CHoCH against PREVIOUS swings
      if(prSH > 0)
        {
         if(bar1Close > prSH)                        bullBOS = true;
         if(bar1Close > prSH + atr * chBufATR)       bullCH  = true;
        }
      if(prSL > 0)
        {
         if(bar1Close < prSL)                        bearBOS = true;
         if(bar1Close < prSL - atr * chBufATR)       bearCH  = true;
        }

      //-- 3. impulse spawns
      bool eLong  = foundPH && prevPivotDir == -1 && (pH - prevPivotPrice) > atr * impMult;
      bool eShort = foundPL && prevPivotDir ==  1 && (prevPivotPrice - pL) > atr * impMult;
      bool flipUp = (dir == -1) && bullCH;
      bool flipDn = (dir ==  1) && bearCH;

      bool hasCtx = (dir != 0 && ft != 0.0);
      isReversal  = (eLong && dir == -1) || (eShort && dir == 1) || flipUp || flipDn;
      bool spawn  = (eLong || eShort || flipUp || flipDn) && (!hasCtx || isReversal);

      if(spawn)
        {
         int newDir = eLong ? 1 : eShort ? -1 : flipUp ? 1 : -1;
         Spawn(newDir);
        }

      //-- 4. extend cycle high / low while wave runs
      if(dir == 1 && !spawnedThisBar)  cycH = MathMax((cycH == 0.0) ? bar1High : cycH, bar1High);
      if(dir == -1 && !spawnedThisBar) cycL = MathMin((cycL == 0.0) ? bar1Low  : cycL, bar1Low);

      //-- 5. inducement state machine (reset on direction change)
      if(dir != lastDirSeen)
        {
         bos1 = false; bos2 = false;
         protSw = protSw2 = 0.0;
         indOrig = indExt = 0.0;
         indBrk = false;
         lastDirSeen = dir;
        }
      if(dir == 1 && foundPL)  { protSw2 = protSw; protSw = pL; }
      if(dir == -1 && foundPH) { protSw2 = protSw; protSw = pH; }

      bool oppBOS = false;
      if(dir == 1  && protSw > 0 && bar1Close < protSw) oppBOS = true;
      if(dir == -1 && protSw > 0 && bar1Close > protSw) oppBOS = true;

      if(!bos1 && oppBOS)
        {
         bos1 = true;
         indOrig = (dir == 1) ? cycH : cycL;
        }
      if(bos1 && !bos2 && oppBOS && protSw2 > 0 &&
         ((dir == 1 && bar1Close < protSw2) || (dir == -1 && bar1Close > protSw2)))
         bos2 = true;
      if(bos1 && dir == 1)
         indExt = (indExt == 0.0) ? bar1Close : MathMin(indExt, bar1Close);
      if(bos1 && dir == -1)
         indExt = (indExt == 0.0) ? bar1Close : MathMax(indExt, bar1Close);
      if(bos2 && indOrig > 0)
        {
         if(dir == 1  && bar1Close > indOrig) indBrk = true;
         if(dir == -1 && bar1Close < indOrig) indBrk = true;
        }

      //-- 6. composite scores
      convScore = MathMin(MathAbs(physics.csm) / MathMax(atr * physics.convM, 1e-10) * 50.0, 100.0);
      expScore  = MathMin(physics.eff / MathMax(physics.effT, 1e-10) * 50.0
                          + physics.disp / MathMax(physics.dispT, 1e-10) * 50.0, 100.0);
      absScore  = (physics.eff < physics.effT * 0.7
                   && MathAbs(physics.vel) < MathAbs(physics.velPrev) * 0.6)
                   ? (60.0 + convScore * 0.4) : (convScore * 0.3);
      //-- compression index: HIGH when displacement & efficiency are LOW
      double dN = MathMin(physics.disp / MathMax(physics.dispT, 1e-10), 1.0);
      double eN = MathMin(physics.eff  / MathMax(physics.effT,  1e-10), 1.0);
      compIdx = OmegaMath::Clamp((1.0 - dN) * 60.0 + (1.0 - eN) * 40.0, 0.0, 100.0);

      //-- 7. wave progress (geometry-anchored)
      if(p4h > 0 && p4l > 0 && ft > 0 && fb > 0)
        {
         double origin  = (dir == 1) ? p4l : p4h;
         double extreme = (dir == 1) ? ((cycH == 0.0) ? bar1High : cycH)
                                     : ((cycL == 0.0) ? bar1Low  : cycL);
         double fzMid   = (ft + fb) / 2.0;
         double totalMv = MathAbs(extreme - origin);
         double toFzMid = MathAbs(extreme - fzMid);
         double expProg = (totalMv > 1e-10) ? MathMin(MathAbs(bar1Close - origin) / totalMv * 60.0, 60.0) : 30.0;
         double retrMv  = MathAbs(bar1Close - extreme);
         double retrProg = (toFzMid > 1e-10) ? MathMin(retrMv / toFzMid * 40.0, 40.0) : 0.0;
         waveProgress = OmegaMath::Clamp(expProg + retrProg * MathMin(absScore / 40.0, 1.0), 0.0, 100.0);
        }
      else waveProgress = 30.0;

      //-- 8. model fit confidence — used by Phase 4 for stability
      double geomConsistency = 0.0;
      if(MathAbs((dir == 1 ? cycH : cycL) - inv) > atr * 2.0) geomConsistency += 30.0;
      if(MathAbs(ft - fb) < atr * 4.0)                        geomConsistency += 25.0;
      if(cycH > 0 || cycL > 0)                                geomConsistency += 20.0;
      if(dir != 0)                                            geomConsistency += 25.0;
      waveModelFit = OmegaMath::Clamp(geomConsistency, 0.0, 100.0);

      lastBarTime = physics.lastBarTime;
      barsProcessed += 1;
      ready = (barsProcessed >= structLen);
      return true;
     }

   //--- direction by origin (matches the displayed wave direction)
   int DirByOrigin() const
     {
      if(inv == 0.0) return dir;
      double bar1Close = iClose(symbol, tf, 1);
      if(bar1Close > inv) return 1;
      if(bar1Close < inv) return -1;
      return dir;
     }
  };

#endif // __OMEGA_CURVE_STATE_MQH__

//==================================================================
//= MODULE: Curve/Compression
//= Source: Include/Curve/Compression.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                  Compression.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 5 — compression intelligence.                            |
//|                                                                  |
//|   Compression isn't local. It is tracked everywhere — at highs,  |
//|   lows, supply, demand, retracements, structure breaks, pullbacks|
//|                                                                  |
//|   Question: can price BREATHE? Or is it being SQUEEZED?          |
//|                                                                  |
//|   Compression Index (0..100):                                    |
//|     HIGH  → tight (failure swings, fast entries, violence)       |
//|     LOW   → wide  (large recursive transitions, room to breathe) |
//|                                                                  |
//|   Compression `tightening` (Δ over N bars) is just as important: |
//|     positive Δ → counter side suffocating (Principle 10)         |
//|     negative Δ → counter side getting room (force leaking)       |
//|                                                                  |
//|   This module reads from CurveState.compIdx (already computed    |
//|   from physics) and adds the rolling-tighten signal.             |
//+------------------------------------------------------------------+
#ifndef __OMEGA_COMPRESSION_MQH__
#define __OMEGA_COMPRESSION_MQH__


class CompressionTracker
  {
private:
   double m_history[];   // ring buffer of compIdx samples
   int    m_head;
   int    m_count;
   int    m_capacity;

public:
                     CompressionTracker()
     {
      m_capacity = 16;
      ArrayResize(m_history, m_capacity);
      Reset();
     }

   void Reset()
     {
      m_head = 0;
      m_count = 0;
      ArrayInitialize(m_history, 0.0);
     }

   void Push(double sample)
     {
      m_history[m_head] = sample;
      m_head = (m_head + 1) % m_capacity;
      if(m_count < m_capacity) m_count++;
     }

   //--- Δcompression over the last `lookback` samples.
   //    Positive ⇒ TIGHTENING; negative ⇒ BROADENING.
   double Tightening(int lookback = 5) const
     {
      if(m_count < 2) return 0.0;
      int span = MathMin(lookback, m_count - 1);
      int latest = (m_head - 1 + m_capacity) % m_capacity;
      int earlier = (m_head - 1 - span + m_capacity) % m_capacity;
      return m_history[latest] - m_history[earlier];
     }

   double Latest() const
     {
      if(m_count == 0) return 0.0;
      int latest = (m_head - 1 + m_capacity) % m_capacity;
      return m_history[latest];
     }

   //--- Phase 1 of Layer 5 — sample on each closed bar.
   void Sample(const CurveState &cs)
     {
      Push(cs.compIdx);
     }

   //--- Tier label used by the supporting story builder
   string Tier() const
     {
      double v = Latest();
      if(v >= 75.0) return "FAILURE_SWING";
      if(v >= 50.0) return "COMPRESSED";
      if(v >= 25.0) return "MEDIUM";
      return "WIDE";
     }
  };

#endif // __OMEGA_COMPRESSION_MQH__

//==================================================================
//= MODULE: Curve/Convexity
//= Source: Include/Curve/Convexity.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                    Convexity.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 0 — convexity primitive.                                 |
//|                                                                  |
//|   "Energy cannot travel infinitely in straight lines."           |
//|                                                                  |
//|   Convexity = the rate of change of acceleration. The derivative |
//|   of motion that reveals when a move is about to turn before     |
//|   the turn shows up in the high/low. CurvePhysics already        |
//|   computes the smoothed convexity (csm); this module adds the    |
//|   normalized `score` and the discrete shift events.              |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CONVEXITY_MQH__
#define __OMEGA_CONVEXITY_MQH__


class ConvexityHelper
  {
public:
   //--- 0..100 score — how convex the move currently is
   static double Score(const CurveState &cs)
     {
      return MathMin(MathAbs(cs.physics.csm) / MathMax(cs.physics.atr * cs.physics.convM, 1e-10) * 50.0,
                     100.0);
     }

   //--- shift sign: +1 = bull convex shift, -1 = bear, 0 = none
   static int ShiftSign(const CurveState &cs)
     {
      if(cs.physics.bullConvShift) return 1;
      if(cs.physics.bearConvShift) return -1;
      return 0;
     }

   //--- maturity (0..100) — how late is the curve in its convex life?
   //    Reads CurveState.waveProgress as the geometric anchor.
   static double Maturity(const CurveState &cs)
     {
      return OmegaMath::Clamp(cs.waveProgress, 0.0, 100.0);
     }
  };

#endif // __OMEGA_CONVEXITY_MQH__

//==================================================================
//= MODULE: Curve/Force
//= Source: Include/Curve/Force.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                        Force.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 5/7 — Compression Persistence.                           |
//|                                                                  |
//|   "After a break + pullback, the question is NOT 'how deep will  |
//|    it retrace?' but 'can the COUNTER side even generate room to  |
//|    build?'."                                                     |
//|                                                                  |
//|   Force composite (0..100):                                      |
//|     PERSISTING   → ≥ 60  · counter-side suffocating, hold        |
//|     NEUTRAL      → 35..60 · undecided                            |
//|     LEAKING      → ≤ 35  · origin in play, ownership transferring|
//|                                                                  |
//|   Inputs (Phase 2: compression + tightening only; Phase 3 will   |
//|   fold in residual energy and recursion depth from the curve     |
//|   tree):                                                         |
//|     compNow            (0..100, current compression)             |
//|     compTighten        (Δ compression over recent bars)          |
//|     residualEnergy     (0..100, Phase 4)                         |
//|     recursionDepth     (Phase 3)                                 |
//+------------------------------------------------------------------+
#ifndef __OMEGA_FORCE_MQH__
#define __OMEGA_FORCE_MQH__


enum ENUM_OMEGA_FORCE_STATE
  {
   FORCE_LEAKING     = 0,
   FORCE_NEUTRAL     = 1,
   FORCE_PERSISTING  = 2
  };

class ForceHelper
  {
public:
   //--- Composite force score (0..100). Phase 2 inputs only.
   static double Score(double compNow, double compTighten,
                       double residualEnergy = 0.0, int recursionDepth = 0)
     {
      double s = compNow * 0.50
               + residualEnergy * 0.20
               - (double)recursionDepth * 12.0
               + MathMax(0.0, compTighten) * 0.8
               + 8.0;
      return OmegaMath::Clamp(s, 0.0, 100.0);
     }

   static ENUM_OMEGA_FORCE_STATE State(double score)
     {
      if(score >= 60.0) return FORCE_PERSISTING;
      if(score <= 35.0) return FORCE_LEAKING;
      return FORCE_NEUTRAL;
     }

   static string StateString(ENUM_OMEGA_FORCE_STATE s)
     {
      switch(s)
        {
         case FORCE_PERSISTING: return "PERSISTING";
         case FORCE_LEAKING:    return "LEAKING";
         case FORCE_NEUTRAL:    return "NEUTRAL";
        }
      return "UNKNOWN";
     }

   static string TightenTrend(double compTighten)
     {
      if(compTighten >  3.0) return "TIGHTENING";
      if(compTighten < -3.0) return "BROADENING";
      return "STABLE";
     }
  };

#endif // __OMEGA_FORCE_MQH__

//==================================================================
//= MODULE: Tree/CurveNode
//= Source: Include/Tree/CurveNode.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                    CurveNode.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 4–8 — the atomic curve in the recursive tree.            |
//|                                                                  |
//|   A CurveNode is born from an EVENT, not from a timeframe:       |
//|   either the chart-TF wave engine spawns a fresh root (dir       |
//|   established, no living owner) OR a Phase-2 CHoCH against the   |
//|   current owner spawns a CHILD curve (same lifecycle, opposite   |
//|   orientation).                                                  |
//|                                                                  |
//|   Each node has:                                                 |
//|     id          — monotonic integer (set by CurveTree)           |
//|     parentId    — -1 for root, else id of parent                 |
//|     dir         — +1 long / -1 short                             |
//|     origin      — price where the curve was born                 |
//|     extreme     — best price the curve has reached so far        |
//|     energy      — 0..100, rises on progress, decays on stall     |
//|     alive       — false when energy <= 2 OR ownership released   |
//|     depth       — 0 = root, 1 = first child, etc.                |
//|     state       — emergent phase string (Principle 1 / 14)       |
//|     bar         — bar index at birth                             |
//|     comp        — compression at birth                           |
//|     mat         — maturity (waveProgress %) at birth             |
//|     srcTf       — 0=chart, 5=H1, 6=H4 (where the curve lives)    |
//|     forceAtBirth, forcePeak, forceAtDeath                        |
//|     birthTime, deathTime                                         |
//|     deathCause  — taxonomy (transfer / merge / decay / terminal) |
//|                                                                  |
//|   The state string is computed by f_nodeState() (below) — phases |
//|   EMERGE from the curve, not the legacy machine. Recursion       |
//|   depth > 0 means the node lives in the Transition family.       |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CURVE_NODE_MQH__
#define __OMEGA_CURVE_NODE_MQH__


//=== Node death taxonomy (mirrors campaign death cause) ============
enum ENUM_NODE_DEATH
  {
   NODE_ALIVE                   = 0,
   NODE_DEATH_DECAY             = 1,
   NODE_DEATH_TRANSFERRED       = 2,
   NODE_DEATH_MERGED            = 3,
   NODE_DEATH_TERMINAL_INDUCTION= 4,
   NODE_DEATH_REGIME_SHIFT      = 5
  };

//=== The node ======================================================
struct CurveNode
  {
   long             id;
   long             parentId;
   int              dir;
   double           origin;
   double           extreme;
   double           energy;
   bool             alive;
   int              depth;
   string           state;
   int              bar;
   double           comp;
   double           mat;
   int              srcTf;
   double           forceAtBirth;
   double           forcePeak;
   double           forceAtDeath;
   datetime         birthTime;
   datetime         deathTime;
   ENUM_NODE_DEATH  deathCause;
   long             campaignId;     // optional FK into CampaignDB

                     CurveNode() { Reset(); }

   void Reset()
     {
      id = 0; parentId = -1; dir = 0;
      origin = 0; extreme = 0; energy = 0;
      alive = false; depth = 0; state = "";
      bar = 0; comp = 0; mat = 0; srcTf = 0;
      forceAtBirth = forcePeak = forceAtDeath = 0;
      birthTime = 0; deathTime = 0;
      deathCause = NODE_ALIVE;
      campaignId = 0;
     }

   //--- Phase the curve OWNS — emergent from energy / depth / comp / mat
   string EmergentState() const
     {
      if(depth > 0)
        {
         if(energy >= 70.0) return "Transition · recursive expansion";
         if(energy >= 40.0) return "Transition · recursive induction";
         return "Transition · recursive liquidation";
        }
      if(mat < 12.0) return "Point 4 Origin";
      if(energy >= 78.0 && mat >= 70.0)
         return (dir == 1 ? "New High" : (dir == -1 ? "New Low" : "Climax"));
      if(mat < 35.0)        return "Expansion";
      if(mat < 55.0)        return "Expansion Pre-Convexity";
      if(energy >= 55.0)    return "Expansion Induction";
      if(energy >= 35.0)    return "Expansion Liquidity";
      if(comp >= 60.0)      return "Retracement Pre-Convexity";
      if(energy >= 18.0)    return "Retracement Induction";
      return "Retracement";
     }

   //--- progress test on the latest bar — feeds energy update
   bool Progressed(double barHigh, double barLow) const
     {
      if(!alive) return false;
      if(dir == 1)  return barHigh > extreme;
      if(dir == -1) return barLow  < extreme;
      return false;
     }

   //--- short snapshot for logs
   string Snapshot() const
     {
      return StringFormat("id=%I64d p=%I64d dir=%d depth=%d e=%.0f mat=%.0f comp=%.0f %s alive=%s",
                          id, parentId, dir, depth, energy, mat, comp, state, alive?"Y":"N");
     }
  };

#endif // __OMEGA_CURVE_NODE_MQH__

//==================================================================
//= MODULE: Tree/Ownership
//= Source: Include/Tree/Ownership.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                    Ownership.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 6 — Principle 8 ownership:                               |
//|   Ownership belongs to the SHALLOWEST curve that still holds     |
//|   energy. A child only takes over once the parent dissipates     |
//|   below the floor.                                               |
//|                                                                  |
//|   Inputs: array of CurveNode (whole tree)                        |
//|   Outputs: index of dominant owner, depth, direction, energy,    |
//|            and an "ownership stability" metric (0..100) used by  |
//|            the trinity supporting field.                         |
//+------------------------------------------------------------------+
#ifndef __OMEGA_OWNERSHIP_MQH__
#define __OMEGA_OWNERSHIP_MQH__


//=== Result struct =================================================
struct OwnershipResult
  {
   int       index;          // -1 if none
   int       depth;
   int       direction;
   double    energy;
   double    stability;      // 0..100

                     OwnershipResult()
     {
      index = -1; depth = 999; direction = 0;
      energy = 0; stability = OMEGA_TRINITY_NEUTRAL;
     }
  };

class Ownership
  {
public:
   //--- Pick the dominant owner. Threshold floor = ownMinE.
   //    Tie-breaker: deepest among shallow ties (shouldn't happen
   //    since we walk by depth ascending). Fallback: highest energy
   //    alive node if none crosses the floor.
   static OwnershipResult Pick(CurveNode &tree[], int count, double ownMinE = 12.0)
     {
      OwnershipResult r;

      //-- preferred: shallowest with energy >= floor; ties -> highest energy
      for(int i = 0; i < count; i++)
        {
         if(!tree[i].alive)               continue;
         if(tree[i].energy < ownMinE)     continue;
         if(tree[i].depth < r.depth ||
            (tree[i].depth == r.depth && tree[i].energy > r.energy))
           {
            r.index     = i;
            r.depth     = tree[i].depth;
            r.energy    = tree[i].energy;
            r.direction = tree[i].dir;
           }
        }

      //-- fallback: any alive, highest energy
      if(r.index < 0)
        {
         double best = -1.0;
         for(int i = 0; i < count; i++)
           {
            if(!tree[i].alive) continue;
            if(tree[i].energy > best)
              {
               best = tree[i].energy;
               r.index     = i;
               r.depth     = tree[i].depth;
               r.energy    = tree[i].energy;
               r.direction = tree[i].dir;
              }
           }
        }

      //-- stability: how far the dominant owner is above the floor,
      //   blended with the energy gap to second-best alive node.
      if(r.index >= 0)
        {
         double secondBest = 0.0;
         for(int i = 0; i < count; i++)
           {
            if(i == r.index || !tree[i].alive) continue;
            if(tree[i].energy > secondBest) secondBest = tree[i].energy;
           }
         double aboveFloor = OmegaMath::Clamp((r.energy - ownMinE) / (100.0 - ownMinE), 0.0, 1.0);
         double gap        = OmegaMath::Clamp((r.energy - secondBest) / 100.0, 0.0, 1.0);
         r.stability = OmegaMath::Clamp(aboveFloor * 60.0 + gap * 40.0, 0.0, 100.0);
        }
      else
        {
         r.stability = OMEGA_TRINITY_NEUTRAL;
        }

      return r;
     }
  };

#endif // __OMEGA_OWNERSHIP_MQH__

//==================================================================
//= MODULE: Tree/Transfer
//= Source: Include/Tree/Transfer.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                     Transfer.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 6/7 — ownership TRANSFER.                                |
//|                                                                  |
//|   "TRANSFERRED · new campaign" — a counter-direction child curve |
//|   has BROKEN the parent's protective structure and is now the    |
//|   dominant owner. The old campaign is dead; the trader's call is |
//|   to flip to the counter side.                                   |
//|                                                                  |
//|   Detection:                                                     |
//|     - candidate child has dir opposite to parent                 |
//|     - close has crossed the parent's ORIGIN (the protective      |
//|       extreme — beyond it, the parent's structure is invalidated)|
//|     - parent's energy is leaking (≤ 35 at the moment of break)   |
//|                                                                  |
//|   Transfer is a one-shot event; once detected we mark parent     |
//|   alive=false / deathCause=TRANSFERRED and bubble the campaign   |
//|   through CampaignDB.                                            |
//+------------------------------------------------------------------+
#ifndef __OMEGA_TRANSFER_MQH__
#define __OMEGA_TRANSFER_MQH__


class Transfer
  {
public:
   //--- Test whether `childIdx` represents a transfer break of `parentIdx`.
   //    `closeNow` is the latest closed-bar close of the chart TF.
   static bool IsTransferEvent(CurveNode &tree[], int count,
                                int childIdx, int parentIdx, double closeNow)
     {
      if(childIdx < 0 || childIdx >= count) return false;
      if(parentIdx < 0 || parentIdx >= count) return false;
      if(!tree[childIdx].alive)  return false;
      if(!tree[parentIdx].alive) return false;
      if(tree[childIdx].dir == 0 || tree[parentIdx].dir == 0) return false;
      if(tree[childIdx].dir == tree[parentIdx].dir) return false;       // child must be counter
      if(tree[parentIdx].energy > 35.0) return false;                   // parent must be leaking
      double parentOrigin = tree[parentIdx].origin;
      if(parentOrigin == 0.0) return false;
      //-- bull child against bear parent: close must rise ABOVE parent origin
      if(tree[childIdx].dir == 1  && closeNow > parentOrigin) return true;
      if(tree[childIdx].dir == -1 && closeNow < parentOrigin) return true;
      return false;
     }

   //--- Apply: mark parent as transferred. Returns true if it changed.
   static bool Apply(CurveNode &tree[], int count, int parentIdx, datetime now)
     {
      if(parentIdx < 0 || parentIdx >= count) return false;
      if(!tree[parentIdx].alive) return false;
      tree[parentIdx].alive       = false;
      tree[parentIdx].deathTime   = now;
      tree[parentIdx].deathCause  = NODE_DEATH_TRANSFERRED;
      tree[parentIdx].forceAtDeath= tree[parentIdx].energy;
      return true;
     }
  };

#endif // __OMEGA_TRANSFER_MQH__

//==================================================================
//= MODULE: Tree/Merge
//= Source: Include/Tree/Merge.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                        Merge.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 6/7 — child→parent MERGE.                                |
//|                                                                  |
//|   "MERGED → parent (B → A)" — a counter-direction child curve    |
//|   FAILED to break the parent's structure and DIED while still    |
//|   inside the parent's range. The parent's campaign continues —   |
//|   the child was a recursive dissipation event, not a handoff.    |
//|                                                                  |
//|   Detection (called when a child node is about to die from       |
//|   energy decay):                                                 |
//|     - child has dir opposite to parent                           |
//|     - child died WITHOUT breaking parent origin                  |
//|     - parent is still alive at the moment of child death         |
//|                                                                  |
//|   On merge: child's deathCause = MERGED, parent.energy gets a    |
//|   small REINFORCEMENT (+5, capped 100) — the campaign survived a |
//|   probe and is healthier for it.                                 |
//+------------------------------------------------------------------+
#ifndef __OMEGA_MERGE_MQH__
#define __OMEGA_MERGE_MQH__


class Merge
  {
public:
   //--- Test whether `childIdx` should merge back into `parentIdx`.
   //    Called at the moment a child's energy <= 2.
   static bool IsMergeEvent(CurveNode &tree[], int count,
                             int childIdx, int parentIdx, double closeNow)
     {
      if(childIdx < 0 || childIdx >= count) return false;
      if(parentIdx < 0 || parentIdx >= count) return false;
      if(!tree[parentIdx].alive) return false;
      if(tree[childIdx].dir == tree[parentIdx].dir) return false;
      double parentOrigin = tree[parentIdx].origin;
      if(parentOrigin == 0.0) return false;
      //-- child died WITHOUT crossing parent origin (parent's structure intact)
      if(tree[parentIdx].dir == 1  && closeNow > parentOrigin) return true;
      if(tree[parentIdx].dir == -1 && closeNow < parentOrigin) return true;
      return false;
     }

   //--- Apply the merge: child becomes MERGED, parent gets reinforcement.
   //    Returns true if it changed state.
   static bool Apply(CurveNode &tree[], int count,
                      int childIdx, int parentIdx, datetime now)
     {
      if(childIdx < 0 || childIdx >= count) return false;
      if(parentIdx < 0 || parentIdx >= count) return false;
      tree[childIdx].alive        = false;
      tree[childIdx].deathTime    = now;
      tree[childIdx].deathCause   = NODE_DEATH_MERGED;
      tree[childIdx].forceAtDeath = tree[childIdx].energy;
      //-- reinforcement: campaign survived a probe
      tree[parentIdx].energy   = OmegaMath::Clamp(tree[parentIdx].energy + 5.0, 0.0, 100.0);
      if(tree[parentIdx].energy > tree[parentIdx].forcePeak)
         tree[parentIdx].forcePeak = tree[parentIdx].energy;
      return true;
     }
  };

#endif // __OMEGA_MERGE_MQH__

//==================================================================
//= MODULE: Tree/ChainHealth
//= Source: Include/Tree/ChainHealth.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                  ChainHealth.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 8 — Chain Vitality.                                      |
//|                                                                  |
//|   Three scopes of danger, distinguished:                         |
//|     - current CURVE in trouble (life low) but the chain is fine  |
//|     - current CHAIN weakening (life trending down across last N) |
//|     - the WHOLE chain decaying (life bled out across the lineage)|
//|                                                                  |
//|   Tracks two scalars:                                            |
//|     chainVitality   — 50 + (latestLife - firstLife) over recent  |
//|                       lives, clamped 0..100                      |
//|     wholeChainLife  — slow EMA of every life sample seen, 0..100 |
//|                                                                  |
//|   And rolls up into one of four labels for the supporting story. |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CHAIN_HEALTH_MQH__
#define __OMEGA_CHAIN_HEALTH_MQH__


enum ENUM_CHAIN_SCOPE
  {
   CHAIN_HEALTHY                 = 0,
   CHAIN_CURVE_ONLY              = 1,
   CHAIN_WEAKENING               = 2,
   CHAIN_WHOLE_DECAYING          = 3
  };

class ChainHealth
  {
private:
   double m_lifeSeq[];
   int    m_seqHead;
   int    m_seqCount;
   int    m_seqCapacity;
   double m_wholeChainLife;

public:
                     ChainHealth()
     {
      m_seqCapacity = 8;
      ArrayResize(m_lifeSeq, m_seqCapacity);
      Reset();
     }

   void Reset()
     {
      m_seqHead = 0;
      m_seqCount = 0;
      m_wholeChainLife = OMEGA_TRINITY_NEUTRAL;
      ArrayInitialize(m_lifeSeq, 0.0);
     }

   //--- Sample a new life value (called when a curve dies, OR each bar
   //    on the dominant owner). The slow EMA tracks the WHOLE history.
   void Sample(double life)
     {
      m_lifeSeq[m_seqHead] = life;
      m_seqHead = (m_seqHead + 1) % m_seqCapacity;
      if(m_seqCount < m_seqCapacity) m_seqCount++;
      m_wholeChainLife = m_wholeChainLife + 0.02 * (life - m_wholeChainLife);
     }

   //--- 0..100 — recent life trajectory anchored at 50
   double Vitality() const
     {
      if(m_seqCount < 2) return m_wholeChainLife;
      int latestIdx  = (m_seqHead - 1 + m_seqCapacity) % m_seqCapacity;
      int earliestIdx = (m_seqHead - m_seqCount + m_seqCapacity) % m_seqCapacity;
      double v = OMEGA_TRINITY_NEUTRAL + (m_lifeSeq[latestIdx] - m_lifeSeq[earliestIdx]);
      return OmegaMath::Clamp(v, 0.0, 100.0);
     }

   //--- 0..100 — slow EMA of every life ever sampled
   double WholeChainLife() const { return m_wholeChainLife; }

   //--- Composite label
   ENUM_CHAIN_SCOPE Scope(double currentLife) const
     {
      if(currentLife >= 50.0)            return CHAIN_HEALTHY;
      if(Vitality()  >= 50.0)            return CHAIN_CURVE_ONLY;
      if(WholeChainLife() >= 45.0)       return CHAIN_WEAKENING;
      return CHAIN_WHOLE_DECAYING;
     }

   static string ScopeString(ENUM_CHAIN_SCOPE s)
     {
      switch(s)
        {
         case CHAIN_HEALTHY:           return "HEALTHY";
         case CHAIN_CURVE_ONLY:        return "CURVE_ONLY";
         case CHAIN_WEAKENING:         return "CHAIN_WEAKENING";
         case CHAIN_WHOLE_DECAYING:    return "WHOLE_DECAYING";
        }
      return "UNKNOWN";
     }

   //--- 0..100 score for the trinity supporting field
   double Score(double currentLife) const
     {
      ENUM_CHAIN_SCOPE s = Scope(currentLife);
      switch(s)
        {
         case CHAIN_HEALTHY:        return OmegaMath::Clamp(60.0 + currentLife * 0.4, 0.0, 100.0);
         case CHAIN_CURVE_ONLY:     return OmegaMath::Clamp(50.0 + Vitality() * 0.3, 0.0, 100.0);
         case CHAIN_WEAKENING:      return OmegaMath::Clamp(35.0 + WholeChainLife() * 0.2, 0.0, 100.0);
         case CHAIN_WHOLE_DECAYING: return OmegaMath::Clamp(WholeChainLife() * 0.6, 0.0, 100.0);
        }
      return OMEGA_TRINITY_NEUTRAL;
     }
  };

#endif // __OMEGA_CHAIN_HEALTH_MQH__

//==================================================================
//= MODULE: Tree/CurveTree
//= Source: Include/Tree/CurveTree.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                    CurveTree.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 4–8 — the recursive curve tree.                          |
//|                                                                  |
//|   Owns a fixed-capacity array of CurveNode. Drives the lifecycle |
//|   on each closed bar:                                            |
//|                                                                  |
//|     1. spawn root if no owner exists and chart curve has direction|
//|     2. spawn child on Phase-2 CHoCH against owner (if budget left)|
//|     3. update each alive node's energy from progress / decay     |
//|     4. detect TRANSFER / MERGE events                            |
//|     5. recompute ownership                                       |
//|     6. update ChainHealth                                        |
//|     7. rotate dead nodes out (cap = 32)                          |
//|                                                                  |
//|   Outputs (consumed by Curve.mqh / supporting fields):           |
//|     ownerIndex, ownerDir, ownerEnergy, ownerStability             |
//|     treeDepth, recursionBudget, treeAlive                        |
//|     chainHealth.Score(), chainHealth.Vitality()                  |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CURVE_TREE_MQH__
#define __OMEGA_CURVE_TREE_MQH__


#define OMEGA_TREE_CAPACITY    32
#define OMEGA_OWN_MIN_ENERGY   12.0

class OmegaCurveTree
  {
public:
   CurveNode         tree[OMEGA_TREE_CAPACITY];
   int               count;            // current number of nodes (alive + recently dead)
   long              nextNodeId;
   ChainHealth       chain;

   //--- last-update outputs
   int               ownerIndex;
   int               ownerDir;
   int               ownerDepth;
   double            ownerEnergy;
   double            ownerStability;
   double            ownerLife;        // proxy = ownerEnergy until Phase 4 wires real Life
   int               treeAlive;
   int               treeDepth;
   int               recursionBudget;

   //--- transfer / merge counters (for explainability)
   long              transfersCount;
   long              mergesCount;
   long              spawnsCount;
   long              decaysCount;

   //--- bookkeeping
   string            symbol;
   ENUM_TIMEFRAMES   chartTf;
   datetime          lastBarTime;
   long              barsProcessed;

private:
   //--- find first free slot (or -1 if full); when full we evict the
   //    oldest dead node to make room.
   int FindFreeSlot()
     {
      for(int i = 0; i < count; i++)
         if(tree[i].id == 0) return i;
      if(count < OMEGA_TREE_CAPACITY) return count++;
      //-- full: evict oldest dead node by deathTime asc
      int evict = -1;
      datetime oldest = D'2099.01.01';
      for(int i = 0; i < count; i++)
        {
         if(tree[i].alive) continue;
         if(tree[i].deathTime > 0 && tree[i].deathTime < oldest)
           {
            oldest = tree[i].deathTime;
            evict = i;
           }
        }
      if(evict >= 0)
        {
         tree[evict].Reset();
         return evict;
        }
      //-- absolutely full of alive nodes — evict lowest-energy alive
      double minE = 1e9;
      for(int i = 0; i < count; i++)
         if(tree[i].alive && tree[i].energy < minE) { minE = tree[i].energy; evict = i; }
      if(evict >= 0) { tree[evict].Reset(); return evict; }
      return -1;
     }

   int IndexOfId(long id) const
     {
      if(id <= 0) return -1;
      for(int i = 0; i < count; i++)
         if(tree[i].id == id) return i;
      return -1;
     }

public:
                     OmegaCurveTree()
     {
      count = 0;
      nextNodeId = 1;
      ownerIndex = -1; ownerDir = 0; ownerDepth = 999;
      ownerEnergy = 0; ownerStability = OMEGA_TRINITY_NEUTRAL; ownerLife = 0;
      treeAlive = 0; treeDepth = 0; recursionBudget = 1;
      transfersCount = mergesCount = spawnsCount = decaysCount = 0;
      symbol = ""; chartTf = PERIOD_CURRENT;
      lastBarTime = 0; barsProcessed = 0;
     }

   void Init(string sym, ENUM_TIMEFRAMES chart_tf)
     {
      symbol = sym;
      chartTf = chart_tf;
      OmegaLogger::LogInfo("TREE",
         StringFormat("Init %s tf=%d capacity=%d ownFloor=%.0f",
                      sym, (int)chart_tf, OMEGA_TREE_CAPACITY, OMEGA_OWN_MIN_ENERGY));
     }

   void Reset()
     {
      for(int i = 0; i < count; i++) tree[i].Reset();
      count = 0;
      nextNodeId = 1;
      chain.Reset();
      ownerIndex = -1; ownerDir = 0; ownerDepth = 999;
      ownerEnergy = 0; ownerStability = OMEGA_TRINITY_NEUTRAL; ownerLife = 0;
      treeAlive = 0; treeDepth = 0; recursionBudget = 1;
      transfersCount = mergesCount = spawnsCount = decaysCount = 0;
     }

   //--- Spawn a new root from the chart curve's wave context.
   //    Called when no living owner exists and the chart curve has dir.
   void SpawnRoot(const CurveState &cs)
     {
      int slot = FindFreeSlot();
      if(slot < 0) return;
      tree[slot].Reset();
      tree[slot].id          = nextNodeId++;
      tree[slot].parentId    = -1;
      tree[slot].dir         = cs.dir;
      tree[slot].origin      = (cs.dir == 1) ? cs.p4l : cs.p4h;
      tree[slot].extreme     = (cs.dir == 1) ? MathMax(cs.cycH, iHigh(symbol, chartTf, 1))
                                              : MathMin(cs.cycL, iLow(symbol, chartTf, 1));
      tree[slot].energy      = MathMax(40.0, MathMin(60.0 + cs.expScore * 0.4, 90.0));
      tree[slot].alive       = true;
      tree[slot].depth       = 0;
      tree[slot].bar         = (int)Bars(symbol, chartTf);
      tree[slot].comp        = cs.compIdx;
      tree[slot].mat         = cs.waveProgress;
      tree[slot].srcTf       = 0;
      tree[slot].forceAtBirth= tree[slot].energy;
      tree[slot].forcePeak   = tree[slot].energy;
      tree[slot].birthTime   = TimeCurrent();
      tree[slot].state       = tree[slot].EmergentState();
      spawnsCount++;
      OmegaLogger::LogInfo("TREE",
         StringFormat("ROOT spawn · %s · %s", symbol, tree[slot].Snapshot()));
     }

   //--- Spawn a child counter-curve from a CHoCH against the owner.
   //    Pre: owner exists, dir != newChildDir, recursion budget allows.
   void SpawnChild(int parentIdx, int newDir, const CurveState &cs)
     {
      if(parentIdx < 0 || parentIdx >= count) return;
      if(tree[parentIdx].depth + 1 > recursionBudget) return;
      int slot = FindFreeSlot();
      if(slot < 0) return;
      double bar1Close = iClose(symbol, chartTf, 1);
      tree[slot].Reset();
      tree[slot].id          = nextNodeId++;
      tree[slot].parentId    = tree[parentIdx].id;
      tree[slot].dir         = newDir;
      tree[slot].origin      = bar1Close;
      tree[slot].extreme     = bar1Close;
      tree[slot].energy      = MathMax(25.0, MathMin(50.0 + cs.expScore * 0.25, 70.0));
      tree[slot].alive       = true;
      tree[slot].depth       = tree[parentIdx].depth + 1;
      tree[slot].bar         = (int)Bars(symbol, chartTf);
      tree[slot].comp        = cs.compIdx;
      tree[slot].mat         = 0.0;
      tree[slot].srcTf       = 0;
      tree[slot].forceAtBirth= tree[slot].energy;
      tree[slot].forcePeak   = tree[slot].energy;
      tree[slot].birthTime   = TimeCurrent();
      tree[slot].state       = tree[slot].EmergentState();
      spawnsCount++;
      OmegaLogger::LogInfo("TREE",
         StringFormat("CHILD spawn · %s · parent=%I64d · %s",
                      symbol, tree[parentIdx].id, tree[slot].Snapshot()));
     }

   //--- Compute recursion budget (1..4) from compression tier.
   static int BudgetFromCompression(double compNow)
     {
      return (int)MathMax(1, MathMin(4, 1 + (int)MathRound(compNow / 33.0)));
     }

   //--- Walk the tree once on each closed bar.
   //    `cs` is the chart-TF CurveState (driver of spawn events).
   bool Update(CurveState &cs)
     {
      if(!cs.physics.ready) return false;
      datetime curBarT = cs.lastBarTime;
      if(curBarT == 0) return false;
      if(curBarT == lastBarTime) return false;
      lastBarTime = curBarT;
      barsProcessed++;

      double bar1Close = iClose(symbol, chartTf, 1);
      double bar1High  = iHigh(symbol, chartTf, 1);
      double bar1Low   = iLow(symbol, chartTf, 1);

      //--- 1. recursion budget (compression-derived)
      recursionBudget = BudgetFromCompression(cs.compIdx);

      //--- 2. find current owner
      OwnershipResult own = Ownership::Pick(tree, count, OMEGA_OWN_MIN_ENERGY);

      //--- 3. spawn root if none / spawn child on CHoCH against owner
      bool noOwner = (own.index < 0);
      if(noOwner && cs.dir != 0 && cs.p4h != 0.0 && cs.p4l != 0.0)
        {
         SpawnRoot(cs);
         own = Ownership::Pick(tree, count, OMEGA_OWN_MIN_ENERGY);
        }
      else if(own.index >= 0)
        {
         int ownIdx = own.index;
         int ownDir = tree[ownIdx].dir;
         //-- CHoCH against owner direction triggers child spawn
         if((ownDir == 1 && cs.bearCH) || (ownDir == -1 && cs.bullCH))
            SpawnChild(ownIdx, -ownDir, cs);
        }

      //--- 4. update each alive node's energy / extreme
      for(int i = 0; i < count; i++)
        {
         if(!tree[i].alive) continue;
         //-- Root (depth 0): track chart-TF cycle extreme so origin/extreme
         //   stay aligned with the wave engine. Children: track their own
         //   extension extreme.
         if(tree[i].depth == 0)
           {
            tree[i].dir     = cs.DirByOrigin();
            tree[i].origin  = cs.inv == 0.0 ? tree[i].origin : cs.inv;
            double e1 = (tree[i].dir == 1) ? ((cs.cycH == 0.0) ? bar1High : cs.cycH)
                                            : ((cs.cycL == 0.0) ? bar1Low  : cs.cycL);
            if(tree[i].dir == 1)  tree[i].extreme = MathMax(tree[i].extreme, e1);
            if(tree[i].dir == -1) tree[i].extreme = (tree[i].extreme == 0.0) ? e1 : MathMin(tree[i].extreme, e1);
           }
         else
           {
            if(tree[i].dir == 1)  tree[i].extreme = MathMax(tree[i].extreme, bar1High);
            if(tree[i].dir == -1) tree[i].extreme = (tree[i].extreme == 0.0) ? bar1Low : MathMin(tree[i].extreme, bar1Low);
           }

         bool prog = tree[i].Progressed(bar1High, bar1Low);
         if(prog) tree[i].energy = MathMin(100.0, tree[i].energy + 7.0);
         else     tree[i].energy = MathMax(0.0,   tree[i].energy - 2.0);
         if(tree[i].energy > tree[i].forcePeak) tree[i].forcePeak = tree[i].energy;
         tree[i].mat   = (tree[i].depth == 0) ? cs.waveProgress : tree[i].mat;
         tree[i].comp  = cs.compIdx;
         tree[i].state = tree[i].EmergentState();
        }

      //--- 5. detect death: energy <= 2 OR transfer break
      datetime now = TimeCurrent();
      for(int i = 0; i < count; i++)
        {
         if(!tree[i].alive) continue;
         //-- TRANSFER? — counter child has crossed parent origin
         if(tree[i].depth > 0)
           {
            int pIdx = IndexOfId(tree[i].parentId);
            if(pIdx >= 0 && Transfer::IsTransferEvent(tree, count, i, pIdx, bar1Close))
              {
               Transfer::Apply(tree, count, pIdx, now);
               transfersCount++;
               OmegaLogger::LogWarning("TREE",
                  StringFormat("TRANSFER · child #%I64d broke parent #%I64d · close=%.5f origin=%.5f",
                               tree[i].id, tree[pIdx].id, bar1Close, tree[pIdx].origin));
               chain.Sample(tree[pIdx].forceAtDeath);
              }
           }
         //-- DEATH BY DECAY? — and merge if applicable
         if(tree[i].energy <= 2.0)
           {
            ENUM_NODE_DEATH cause = NODE_DEATH_DECAY;
            int pIdx = IndexOfId(tree[i].parentId);
            if(tree[i].depth > 0 && pIdx >= 0
               && Merge::IsMergeEvent(tree, count, i, pIdx, bar1Close))
              {
               Merge::Apply(tree, count, i, pIdx, now);
               mergesCount++;
               OmegaLogger::LogInfo("TREE",
                  StringFormat("MERGE · child #%I64d -> parent #%I64d (campaign survived probe)",
                               tree[i].id, tree[pIdx].id));
               cause = NODE_DEATH_MERGED;
              }
            else
              {
               tree[i].alive       = false;
               tree[i].deathTime   = now;
               tree[i].deathCause  = cause;
               tree[i].forceAtDeath= tree[i].energy;
               decaysCount++;
              }
            chain.Sample(tree[i].forcePeak * 0.6); // sample at-death life proxy
           }
        }

      //--- 6. recompute ownership AFTER deaths
      own = Ownership::Pick(tree, count, OMEGA_OWN_MIN_ENERGY);
      ownerIndex     = own.index;
      ownerDir       = own.direction;
      ownerDepth     = own.depth;
      ownerEnergy    = own.energy;
      ownerStability = own.stability;
      ownerLife      = own.energy;       // Phase 4 will replace with real Life

      //--- 7. tree summary
      treeAlive = 0; treeDepth = 0;
      for(int i = 0; i < count; i++)
        {
         if(!tree[i].alive) continue;
         treeAlive++;
         if(tree[i].depth > treeDepth) treeDepth = tree[i].depth;
        }

      //--- 8. sample chain on the dominant owner (smooth signal)
      if(ownerIndex >= 0)
         chain.Sample(ownerEnergy);

      return true;
     }

   //--- Snapshot for heartbeat / explainability
   string Snapshot() const
     {
      return StringFormat(
         "owner=%d ownDir=%d ownE=%.0f ownStab=%.0f depth=%d/%d alive=%d trans=%I64d merge=%I64d decay=%I64d spawn=%I64d chain=%s(v=%.0f w=%.0f)",
         ownerIndex, ownerDir, ownerEnergy, ownerStability,
         treeDepth, recursionBudget, treeAlive,
         transfersCount, mergesCount, decaysCount, spawnsCount,
         ChainHealth::ScopeString(chain.Scope(ownerLife)),
         chain.Vitality(), chain.WholeChainLife());
     }
  };

#endif // __OMEGA_CURVE_TREE_MQH__

//==================================================================
//= MODULE: Curve/Curve
//= Source: Include/Curve/Curve.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                        Curve.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 4 — multi-timeframe curve orchestrator.                  |
//|                                                                  |
//|   Holds six CurveState instances (M1, M3, M5, M15, H1, H4) and   |
//|   the compression tracker for the chart timeframe (the "owner    |
//|   curve" anchor in Phase 2; Phase 3 will pick the owner by       |
//|   energy from the curve tree).                                   |
//|                                                                  |
//|   Init() returns true once at least the chart-TF curve is fully  |
//|   ready (`ready=true`); from that moment forward the engine is   |
//|   PRIMED and every supporting field is populated, the trinity    |
//|   becomes live, and Risk gets to see real values.                |
//|                                                                  |
//|   Single source of truth for OmegaSupporting in Phase 2.         |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CURVE_MQH__
#define __OMEGA_CURVE_MQH__


class OmegaCurve
  {
public:
   //--- six TFs (Pine ladder, fixed for now; Phase 7 will adapt)
   CurveState         tfM1;
   CurveState         tfM3;
   CurveState         tfM5;
   CurveState         tfM15;
   CurveState         tfH1;
   CurveState         tfH4;

   //--- compression history (chart TF)
   CompressionTracker compress;

   //--- recursive curve tree (Phase 3) — owner / transfer / merge / chain
   OmegaCurveTree     tree;

   //--- composite (the gCurve object)
   int                gDir;
   double             gForce;
   double             gCompression;
   double             gConvexity;
   double             gMaturity;
   ENUM_OMEGA_FORCE_STATE gForceState;
   string             gForceTrend;

   //--- bookkeeping
   string             symbol;
   ENUM_TIMEFRAMES    chartTf;
   bool               primed;
   long               updates;

                     OmegaCurve()
     {
      symbol = "";
      chartTf = PERIOD_CURRENT;
      gDir = 0; gForce = 0; gCompression = 0; gConvexity = 0; gMaturity = 0;
      gForceState = FORCE_NEUTRAL;
      gForceTrend = "STABLE";
      primed = false;
      updates = 0;
     }

   bool Init(string sym, ENUM_TIMEFRAMES chart_tf,
             int pivotLen = 5, int structLen = 10,
             double impulseMult = 1.5, double chochBufATR = 0.75,
             int atrLen = 14, int effLen = 10,
             double effThresh = 0.65, double dispThresh = 1.5, double convMult = 0.01)
     {
      symbol = sym;
      chartTf = chart_tf;
      bool ok = true;
      ok = ok && tfM1.Init (sym, PERIOD_M1,  pivotLen, structLen, impulseMult, chochBufATR, atrLen, effLen, effThresh, dispThresh, convMult);
      ok = ok && tfM3.Init (sym, PERIOD_M3,  pivotLen, structLen, impulseMult, chochBufATR, atrLen, effLen, effThresh, dispThresh, convMult);
      ok = ok && tfM5.Init (sym, PERIOD_M5,  pivotLen, structLen, impulseMult, chochBufATR, atrLen, effLen, effThresh, dispThresh, convMult);
      ok = ok && tfM15.Init(sym, PERIOD_M15, pivotLen, structLen, impulseMult, chochBufATR, atrLen, effLen, effThresh, dispThresh, convMult);
      ok = ok && tfH1.Init (sym, PERIOD_H1,  pivotLen, structLen, impulseMult, chochBufATR, atrLen, effLen, effThresh, dispThresh, convMult);
      ok = ok && tfH4.Init (sym, PERIOD_H4,  pivotLen, structLen, impulseMult, chochBufATR, atrLen, effLen, effThresh, dispThresh, convMult);
      compress.Reset();
      tree.Init(sym, chart_tf);
      OmegaLogger::LogInfo("CURVE",
         StringFormat("Init %s · ladder=M1/M3/M5/M15/H1/H4 · ok=%s", sym, ok?"true":"false"));
      return ok;
     }

   void Deinit()
     {
      tfM1.Deinit();  tfM3.Deinit();  tfM5.Deinit();
      tfM15.Deinit(); tfH1.Deinit();  tfH4.Deinit();
     }

   //--- Pick the chart-TF state for the canonical compression / dir.
   CurveState* ChartTfState()
     {
      switch(chartTf)
        {
         case PERIOD_M1:  return GetPointer(tfM1);
         case PERIOD_M3:  return GetPointer(tfM3);
         case PERIOD_M5:  return GetPointer(tfM5);
         case PERIOD_M15: return GetPointer(tfM15);
         case PERIOD_H1:  return GetPointer(tfH1);
         case PERIOD_H4:  return GetPointer(tfH4);
        }
      //-- default to M5 if user is on an off-ladder TF
      return GetPointer(tfM5);
     }

   //--- Drive every TF to consume its latest closed bar.
   //    Returns true if at least one TF advanced this call.
   bool Update()
     {
      bool any = false;
      any = tfM1.Update()  || any;
      any = tfM3.Update()  || any;
      any = tfM5.Update()  || any;
      any = tfM15.Update() || any;
      any = tfH1.Update()  || any;
      any = tfH4.Update()  || any;
      if(!any) return false;

      CurveState *chart = ChartTfState();
      if(chart == NULL) return false;

      compress.Sample(chart);
      double tighten = compress.Tightening(5);

      //--- Phase 3: feed the tree from the chart-TF curve state.
      //    Tree updates own ownership / transfer / merge / chain health.
      tree.Update(chart);

      gDir         = chart.DirByOrigin();
      gCompression = chart.compIdx;
      gConvexity   = ConvexityHelper::Score(chart);
      gMaturity    = ConvexityHelper::Maturity(chart);
      //-- force composite now folds in residual energy + recursion depth from tree
      double residualEnergy = (tree.ownerIndex >= 0) ? tree.tree[tree.ownerIndex].energy : 50.0;
      gForce       = ForceHelper::Score(gCompression, tighten, residualEnergy, tree.treeDepth);
      gForceState  = ForceHelper::State(gForce);
      gForceTrend  = ForceHelper::TightenTrend(tighten);

      primed = chart.ready;
      updates += 1;
      return true;
     }

   //--- Fold curve outputs into the trinity's supporting fields.
   //    This is the contract Phase 1 set up — Phase 2 fulfils it for
   //    physics + structure. Phase 3 will overwrite ownershipStability
   //    / chainHealth / recursionDepth from the curve tree.
   void DeriveSupporting(OmegaSupporting &supp) const
     {
      supp.forceScore         = gForce;
      supp.compression        = gCompression;
      supp.convexity          = gConvexity;
      //-- Phase 3 wires these from the tree
      supp.ownershipStability = tree.ownerStability;
      supp.chainHealth        = tree.chain.Score(tree.ownerLife);
      supp.recursionDepth     = tree.treeDepth;
      supp.recursionBudget    = tree.recursionBudget;
      //-- Phase 5.5.3: alignment is computed by the Story engine
      //   from RELATIONSHIPS (NarrativeAlignment::Compute), NOT from
      //   counting TF directions. Leave neutral here — Story overwrites
      //   on every closed bar with the canonical narrative score.
      supp.alignment    = OMEGA_TRINITY_NEUTRAL;
      supp.narrative    = OMEGA_TRINITY_NEUTRAL; // Phase 4
      supp.regime       = OMEGA_TRINITY_NEUTRAL; // Phase 6
      supp.pContinuation= 0; supp.pTerminal = 0; supp.pTransfer = 0; // Phase 6
     }

   //--- short snapshot for heartbeat
   string Snapshot() const
     {
      return StringFormat(
         "dir=%d F=%.0f(%s/%s) C=%.0f X=%.0f mat=%.0f tf-info=M1:%d M3:%d M5:%d M15:%d H1:%d H4:%d · tree[%s]",
         gDir, gForce, ForceHelper::StateString(gForceState), gForceTrend,
         gCompression, gConvexity, gMaturity,
         tfM1.DirByOrigin(),  tfM3.DirByOrigin(),  tfM5.DirByOrigin(),
         tfM15.DirByOrigin(), tfH1.DirByOrigin(),  tfH4.DirByOrigin(),
         tree.Snapshot());
     }
  };

#endif // __OMEGA_CURVE_MQH__

//==================================================================
//= MODULE: Participant/ParticipantZone
//= Source: Include/Participant/ParticipantZone.mqh
//==================================================================
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

//==================================================================
//= MODULE: Participant/ParticipantEngine
//= Source: Include/Participant/ParticipantEngine.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                            ParticipantEngine.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 13 — Fibonacci participant zones (0.618 / 0.70 / 0.786). |
//|                                                                  |
//|   "Everything leaves footprints — not because indicators work,   |
//|    because participants work."                                   |
//|                                                                  |
//|   The owner curve's leg (origin → extreme) defines three         |
//|   participant retracement levels. Each level is a zone that gets |
//|   touched / reacts / gets violated. The engine tracks them all:  |
//|                                                                  |
//|     0.618  — Fibonacci participants (textbook entry crowd)       |
//|     0.70   — interference (between Fib and 0.786)                |
//|     0.786  — heavy (deep retracement; ICT / aggressive swing)    |
//|                                                                  |
//|   When the owner curve flips direction, the old zones expire and |
//|   three new ones are constructed on the new leg.                 |
//|                                                                  |
//|   Outputs ParticipantState:                                      |
//|     activeCount       — zones currently alive                    |
//|     stability         — composite defence score 0..100           |
//|     reactionRate      — fraction of touches that became reactions|
//|     deepestActive     — deepest zone still active (0.618 / .70 / |
//|                         .786 / NONE) — informs decision engine   |
//|     manipulationFlag  — set when 0.70 violated AND 0.786 reacted |
//|                         (classic "stop hunt then continuation")  |
//+------------------------------------------------------------------+
#ifndef __OMEGA_PARTICIPANT_ENGINE_MQH__
#define __OMEGA_PARTICIPANT_ENGINE_MQH__


#define OMEGA_PART_ZONE_AGE_MAX 200

class ParticipantEngine
  {
private:
   //--- the three Fibonacci zones for the current owner leg
   ParticipantZone  m_fib618;
   ParticipantZone  m_fib70;
   ParticipantZone  m_fib786;

   //--- last leg context (so we know when to re-spawn)
   int              m_lastOwnerDir;
   double           m_lastLegOrigin;
   double           m_lastLegExtreme;
   long             m_legSpawns;

   //--- composite state
   double           m_stability;       // 0..100
   double           m_reactionRate;    // 0..1
   ENUM_ZONE_TYPE   m_deepestActive;
   bool             m_manipulationFlag;

   //--- bookkeeping
   string           m_symbol;
   datetime         m_lastBarTime;

   //--- spawn the three zones from a fresh leg
   void SpawnZones(int dir, double origin, double extreme, double atr)
     {
      double leg = MathAbs(extreme - origin);
      if(leg < atr * 1.5) return;   // leg too small to bother

      double px618 = (dir == 1) ? extreme - leg * 0.618 : extreme + leg * 0.618;
      double px70  = (dir == 1) ? extreme - leg * 0.70  : extreme + leg * 0.70;
      double px786 = (dir == 1) ? extreme - leg * 0.786 : extreme + leg * 0.786;
      double tol = atr * 0.25;

      m_fib618.Init(ZONE_TYPE_FIB_618, dir, px618, tol);
      m_fib70 .Init(ZONE_TYPE_FIB_70 , dir, px70 , tol);
      m_fib786.Init(ZONE_TYPE_FIB_786, dir, px786, tol);
      m_legSpawns++;
      OmegaLogger::LogInfo("PART",
         StringFormat("ZONES spawn · dir=%d leg=%.5f · 618=%.5f 70=%.5f 786=%.5f tol=%.5f",
                       dir, leg, px618, px70, px786, tol));
     }

   //--- evaluate composite stability + manipulation flag
   void Recompute()
     {
      int active   = 0;
      int touches  = 0;
      int reacts   = 0;
      int violates = 0;
      double scoreSum = 0.0;
      //-- accumulate from all three zones (no pointers — MQL5 forbids
      //   pointers to struct types).
      touches  += m_fib618.touchCount    + m_fib70.touchCount    + m_fib786.touchCount;
      reacts   += m_fib618.reactionCount + m_fib70.reactionCount + m_fib786.reactionCount;
      violates += m_fib618.violationCount+ m_fib70.violationCount+ m_fib786.violationCount;
      if(m_fib618.active) { active++; scoreSum += m_fib618.DefenceScore(); }
      if(m_fib70 .active) { active++; scoreSum += m_fib70 .DefenceScore(); }
      if(m_fib786.active) { active++; scoreSum += m_fib786.DefenceScore(); }
      m_stability    = (active > 0) ? (scoreSum / active) : OMEGA_TRINITY_NEUTRAL;
      m_reactionRate = (touches > 0) ? ((double)reacts / touches) : 0.0;

      //--- deepest active zone
      m_deepestActive = ZONE_TYPE_NONE;
      if(m_fib618.active) m_deepestActive = ZONE_TYPE_FIB_618;
      if(m_fib70 .active) m_deepestActive = ZONE_TYPE_FIB_70;
      if(m_fib786.active) m_deepestActive = ZONE_TYPE_FIB_786;

      //--- manipulation: 0.70 was VIOLATED and 0.786 then REACTED
      m_manipulationFlag = (m_fib70.state == ZONE_VIOLATED) &&
                            (m_fib786.state == ZONE_REACTED);
     }

public:
                     ParticipantEngine()
     {
      Reset();
      m_symbol = "";
     }

   void Reset()
     {
      m_fib618.Reset(); m_fib70.Reset(); m_fib786.Reset();
      m_lastOwnerDir   = 0;
      m_lastLegOrigin  = 0; m_lastLegExtreme = 0;
      m_legSpawns      = 0;
      m_stability      = OMEGA_TRINITY_NEUTRAL;
      m_reactionRate   = 0;
      m_deepestActive  = ZONE_TYPE_NONE;
      m_manipulationFlag = false;
      m_lastBarTime = 0;
     }

   void Init(string sym)
     {
      Reset();
      m_symbol = sym;
      OmegaLogger::LogInfo("PART", StringFormat("Init %s", sym));
     }

   //--- per closed bar
   bool Update(OmegaCurve &curve)
     {
      CurveState *chart = curve.ChartTfState();
      if(chart == NULL || !chart.physics.ready) return false;
      datetime t = chart.lastBarTime;
      if(t == 0 || t == m_lastBarTime) return false;
      m_lastBarTime = t;

      double atr = chart.physics.atr;
      if(atr <= 0) return false;

      //--- resolve leg from owner
      int idx = curve.tree.ownerIndex;
      int    ownerDir     = (idx >= 0) ? curve.tree.tree[idx].dir     : 0;
      double ownerOrigin  = (idx >= 0) ? curve.tree.tree[idx].origin  : 0.0;
      double ownerExtreme = (idx >= 0) ? curve.tree.tree[idx].extreme : 0.0;

      //--- re-spawn when direction changes OR when the leg has materially shifted
      bool dirChanged   = (ownerDir != m_lastOwnerDir);
      bool legShifted   = (MathAbs(ownerExtreme - m_lastLegExtreme) > atr * 2.0)
                       || (MathAbs(ownerOrigin  - m_lastLegOrigin)  > atr * 2.0);
      if(ownerDir != 0 && (dirChanged || (legShifted && m_legSpawns == 0)))
        {
         SpawnZones(ownerDir, ownerOrigin, ownerExtreme, atr);
         m_lastOwnerDir   = ownerDir;
         m_lastLegOrigin  = ownerOrigin;
         m_lastLegExtreme = ownerExtreme;
        }

      //--- update each active zone with the just-closed bar
      double bar1H = iHigh(m_symbol,  chart.tf, 1);
      double bar1L = iLow(m_symbol,   chart.tf, 1);
      double bar1C = iClose(m_symbol, chart.tf, 1);
      m_fib618.Update(bar1H, bar1L, bar1C, atr);
      m_fib70 .Update(bar1H, bar1L, bar1C, atr);
      m_fib786.Update(bar1H, bar1L, bar1C, atr);
      m_fib618.ExpireIfOld(OMEGA_PART_ZONE_AGE_MAX);
      m_fib70 .ExpireIfOld(OMEGA_PART_ZONE_AGE_MAX);
      m_fib786.ExpireIfOld(OMEGA_PART_ZONE_AGE_MAX);

      Recompute();
      return true;
     }

   //--- accessors
   double Stability()         const { return m_stability; }
   double ReactionRate()      const { return m_reactionRate; }
   int    ActiveCount()       const
     {
      int n = 0;
      if(m_fib618.active) n++;
      if(m_fib70 .active) n++;
      if(m_fib786.active) n++;
      return n;
     }
   ENUM_ZONE_TYPE DeepestActive() const { return m_deepestActive; }
   bool   ManipulationFlag()  const { return m_manipulationFlag; }
   long   SpawnCount()        const { return m_legSpawns; }

   //--- price queries (for DecisionEngine to use as protective levels)
   double PriceFor(ENUM_ZONE_TYPE t) const
     {
      switch(t)
        {
         case ZONE_TYPE_FIB_618:  return m_fib618.active ? m_fib618.price : 0.0;
         case ZONE_TYPE_FIB_70:   return m_fib70 .active ? m_fib70 .price : 0.0;
         case ZONE_TYPE_FIB_786:  return m_fib786.active ? m_fib786.price : 0.0;
        }
      return 0.0;
     }

   string DeepestString() const
     {
      switch(m_deepestActive)
        {
         case ZONE_TYPE_FIB_618: return "0.618";
         case ZONE_TYPE_FIB_70:  return "0.70";
         case ZONE_TYPE_FIB_786: return "0.786";
        }
      return "none";
     }

   string Snapshot() const
     {
      return StringFormat("part[stab=%.0f rr=%.0f%% deepest=%s active=%d spawns=%I64d %s] · %s · %s · %s",
                          m_stability, m_reactionRate * 100.0, DeepestString(),
                          ActiveCount(), m_legSpawns,
                          m_manipulationFlag ? "MANIP" : "—",
                          m_fib618.Snapshot(),
                          m_fib70 .Snapshot(),
                          m_fib786.Snapshot());
     }
  };

#endif // __OMEGA_PARTICIPANT_ENGINE_MQH__

//==================================================================
//= MODULE: Participant/FlipEngine
//= Source: Include/Participant/FlipEngine.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                   FlipEngine.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 14 — FU candle / flip zone engine.                       |
//|                                                                  |
//|   Detects FU spikes (dominant rejection wicks at local extremes) |
//|   on the chart timeframe and tracks each as a flip zone.         |
//|   Mirrors the Pine `f_fuPool` logic.                             |
//|                                                                  |
//|   Zone lifecycle:                                                |
//|     1. spike detected → zone TOUCHED at birth                    |
//|     2. price returns within tolerance → REACTED if it reverses,  |
//|        VIOLATED if close breaks past the wick tip                |
//|     3. age > maxAge → EXPIRED                                    |
//|                                                                  |
//|   "True induction" is the LOWEST active flip zone in the         |
//|   current owner direction with the strongest reaction count.     |
//|   The DecisionEngine will read it as a high-conviction protective|
//|   level.                                                         |
//+------------------------------------------------------------------+
#ifndef __OMEGA_FLIP_ENGINE_MQH__
#define __OMEGA_FLIP_ENGINE_MQH__


#define OMEGA_FLIP_CAP        24
#define OMEGA_FLIP_AGE_MAX   300
#define OMEGA_FLIP_WICK_FRAC 0.30   // wick / range threshold

class FlipEngine
  {
private:
   ParticipantZone m_zones[OMEGA_FLIP_CAP];
   int             m_count;
   long            m_detectedTotal;

   //--- detection state
   double          m_prevHigh;
   double          m_prevLow;
   datetime        m_lastBarTime;
   string          m_symbol;

   //--- composite outputs
   double          m_quality;          // 0..100 average defence score
   int             m_trueInductionIdx; // index of "lowest" active flip in owner dir
   double          m_truePx;
   int             m_truePxDir;

   int FindFreeSlot()
     {
      for(int i = 0; i < m_count; i++)
         if(!m_zones[i].active && m_zones[i].state == ZONE_EXPIRED) return i;
      if(m_count < OMEGA_FLIP_CAP) return m_count++;
      //-- evict oldest
      int evict = 0;
      datetime oldest = m_zones[0].born;
      for(int i = 1; i < m_count; i++)
         if(m_zones[i].born < oldest) { oldest = m_zones[i].born; evict = i; }
      return evict;
     }

   void MaybeRecord(double tip, int dir, double atr, double bodyHi, double bodyLo)
     {
      int slot = FindFreeSlot();
      if(slot < 0) return;
      double midPx = (dir == -1) ? (bodyHi + (tip - bodyHi) * 0.5)
                                 : (tip + (bodyLo - tip) * 0.5);
      double tol = atr * 0.30;
      m_zones[slot].Init(ZONE_TYPE_FU_FLIP, dir, midPx, tol);
      m_detectedTotal++;
      OmegaLogger::LogInfo("FLIP",
         StringFormat("FU detected · dir=%d tip=%.5f mid=%.5f tol=%.5f", dir, tip, midPx, tol));
     }

public:
                     FlipEngine()
     {
      Reset();
      m_symbol = "";
     }

   void Reset()
     {
      for(int i = 0; i < OMEGA_FLIP_CAP; i++) m_zones[i].Reset();
      m_count          = 0;
      m_detectedTotal  = 0;
      m_prevHigh = m_prevLow = 0;
      m_lastBarTime    = 0;
      m_quality        = OMEGA_TRINITY_NEUTRAL;
      m_trueInductionIdx = -1;
      m_truePx         = 0; m_truePxDir = 0;
     }

   void Init(string sym)
     {
      Reset();
      m_symbol = sym;
      OmegaLogger::LogInfo("FLIP", StringFormat("Init %s · cap=%d wickFrac=%.2f age=%d",
                            sym, OMEGA_FLIP_CAP, OMEGA_FLIP_WICK_FRAC, OMEGA_FLIP_AGE_MAX));
     }

   //--- per closed bar
   bool Update(OmegaCurve &curve)
     {
      CurveState *chart = curve.ChartTfState();
      if(chart == NULL || !chart.physics.ready) return false;
      datetime t = chart.lastBarTime;
      if(t == 0 || t == m_lastBarTime) return false;
      m_lastBarTime = t;

      double atr = chart.physics.atr;
      if(atr <= 0) return false;

      double h1 = iHigh(m_symbol,  chart.tf, 1);
      double l1 = iLow(m_symbol,   chart.tf, 1);
      double o1 = iOpen(m_symbol,  chart.tf, 1);
      double c1 = iClose(m_symbol, chart.tf, 1);

      //--- detect FU spike at local extreme
      double rng = MathMax(h1 - l1, 1e-10);
      double upperWick = h1 - MathMax(o1, c1);
      double lowerWick = MathMin(o1, c1) - l1;
      bool localTop = (m_prevHigh > 0 && h1 >= m_prevHigh);
      bool localBot = (m_prevLow  > 0 && l1 <= m_prevLow);
      bool bearFu   = (upperWick / rng) >= OMEGA_FLIP_WICK_FRAC && (localTop || c1 < o1);
      bool bullFu   = (lowerWick / rng) >= OMEGA_FLIP_WICK_FRAC && (localBot || c1 > o1);

      if(bearFu)
         MaybeRecord(h1, -1, atr, MathMax(o1, c1), MathMin(o1, c1));
      if(bullFu)
         MaybeRecord(l1, +1, atr, MathMax(o1, c1), MathMin(o1, c1));

      m_prevHigh = h1; m_prevLow = l1;

      //--- update existing zones
      double scoreSum = 0; int activeN = 0;
      for(int i = 0; i < m_count; i++)
        {
         if(m_zones[i].active)
           {
            m_zones[i].Update(h1, l1, c1, atr);
            m_zones[i].ExpireIfOld(OMEGA_FLIP_AGE_MAX);
           }
         if(m_zones[i].active) { activeN++; scoreSum += m_zones[i].DefenceScore(); }
        }
      m_quality = (activeN > 0) ? (scoreSum / activeN) : OMEGA_TRINITY_NEUTRAL;

      //--- pick the "true induction" — strongest defence at the most-protective price
      //    in the OWNER's direction.
      int    ownerDir = curve.tree.ownerDir;
      m_trueInductionIdx = -1;
      if(ownerDir != 0)
        {
         double bestScore = -1.0;
         double bestPx    = 0.0;
         for(int i = 0; i < m_count; i++)
           {
            if(!m_zones[i].active) continue;
            if(m_zones[i].direction != ownerDir) continue;
            double s = m_zones[i].DefenceScore();
            //-- prefer zones with reactions; tie-break by extremity (lowest for bull / highest for bear)
            if(s > bestScore || (MathAbs(s - bestScore) < 1e-6 &&
               ((ownerDir == 1 && m_zones[i].price < bestPx) ||
                (ownerDir == -1 && m_zones[i].price > bestPx))))
              {
               bestScore = s;
               bestPx    = m_zones[i].price;
               m_trueInductionIdx = i;
              }
           }
         if(m_trueInductionIdx >= 0)
           {
            m_truePx    = m_zones[m_trueInductionIdx].price;
            m_truePxDir = ownerDir;
           }
        }
      return true;
     }

   //--- accessors
   double Quality()      const { return m_quality; }
   int    Active()       const
     {
      int n = 0;
      for(int i = 0; i < m_count; i++) if(m_zones[i].active) n++;
      return n;
     }
   long   DetectedTotal() const { return m_detectedTotal; }
   bool   HasTrueInduction() const { return m_trueInductionIdx >= 0; }
   double TrueInductionPrice() const { return m_truePx; }
   int    TrueInductionDir()   const { return m_truePxDir; }

   string Snapshot() const
     {
      return StringFormat("flip[q=%.0f active=%d detected=%I64d ind=%s%s]",
                          m_quality, Active(), m_detectedTotal,
                          HasTrueInduction() ? "Y" : "N",
                          HasTrueInduction()
                            ? StringFormat(" px=%.5f", m_truePx)
                            : "");
     }
  };

#endif // __OMEGA_FLIP_ENGINE_MQH__

//==================================================================
//= MODULE: Participant/Participants
//= Source: Include/Participant/Participants.mqh
//==================================================================
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

//==================================================================
//= MODULE: Narrative/LifeScore
//= Source: Include/Narrative/LifeScore.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                    LifeScore.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 7 — "Is the trade alive?" The single judgement the art   |
//|   compresses to. Direct port of the Pine `_life` formula.        |
//|                                                                  |
//|   Composite of:                                                  |
//|     +0.45 × cpForce            — compression persistence force   |
//|     +0.30 × residualEnergy     — owner curve's energy            |
//|     +12   if compression tightening (counter side suffocating)   |
//|     -25   if recursion budget complete and not progressing       |
//|     -20   if force leaking and not progressing                   |
//|     +28   if progressing (price attacking owner extreme NOW)     |
//|     ±retrX bonus by retrace depth (shallow=healthy, deep=danger) |
//|     +10   base anchor                                            |
//|                                                                  |
//|   Output: 0..100. Used directly as the LifeScore in the Trinity. |
//|   Above 60 = ALIVE / HOLD. Below 32 = DEAD / FLIP. Middle =      |
//|   WEAKENING / MANAGE.                                            |
//+------------------------------------------------------------------+
#ifndef __OMEGA_NARRATIVE_LIFESCORE_MQH__
#define __OMEGA_NARRATIVE_LIFESCORE_MQH__


//=== Inputs to the Life formula ====================================
struct LifeInputs
  {
   double  cpForce;             // 0..100, from Force composite
   double  residualEnergy;      // 0..100, owner curve's energy
   double  cmpTighten;          // signed Δ compression
   double  retrX;               // 0..100, retrace from owner extreme toward origin
   bool    progressing;         // owner extreme is being attacked this bar
   bool    recursionComplete;   // tree depth has spent the budget
   bool    forceLeaking;        // ForceState == LEAKING

                     LifeInputs()
     {
      cpForce = 50.0; residualEnergy = 50.0; cmpTighten = 0.0; retrX = 50.0;
      progressing = false; recursionComplete = false; forceLeaking = false;
     }
  };

//=== The aliveness verdict =========================================
enum ENUM_LIFE_VERDICT
  {
   LIFE_DEAD       = 0,   // life ≤ 32 → FLIP to counter side
   LIFE_WEAKENING  = 1,   // 32 < life < 45 → MANAGE
   LIFE_HOLDING    = 2,   // 45 ≤ life < 60 → HOLD with caution
   LIFE_ALIVE      = 3    // life ≥ 60 → HOLD with conviction
  };

class LifeScore
  {
public:
   //--- Compute the life score from the formula above.
   static double Compute(const LifeInputs &in)
     {
      double life = in.cpForce * 0.45
                  + in.residualEnergy * 0.30
                  + (in.cmpTighten > 0.0 ? 12.0 : 0.0)
                  - (in.recursionComplete && !in.progressing ? 25.0 : 0.0)
                  - (in.forceLeaking      && !in.progressing ? 20.0 : 0.0)
                  + (in.progressing ? 28.0 : 0.0)
                  + (in.retrX < 25.0 ?  16.0 :
                     in.retrX < 45.0 ?   6.0 :
                     in.retrX > 75.0 ? -12.0 : 0.0)
                  + 10.0;
      return OmegaMath::Clamp(life, 0.0, 100.0);
     }

   //--- Verdict bucket
   static ENUM_LIFE_VERDICT Verdict(double life)
     {
      if(life >= 60.0) return LIFE_ALIVE;
      if(life >= 45.0) return LIFE_HOLDING;
      if(life >  32.0) return LIFE_WEAKENING;
      return LIFE_DEAD;
     }

   static string VerdictString(ENUM_LIFE_VERDICT v)
     {
      switch(v)
        {
         case LIFE_DEAD:      return "DEAD";
         case LIFE_WEAKENING: return "WEAKENING";
         case LIFE_HOLDING:   return "HOLDING";
         case LIFE_ALIVE:     return "ALIVE";
        }
      return "UNKNOWN";
     }
  };

#endif // __OMEGA_NARRATIVE_LIFESCORE_MQH__

//==================================================================
//= MODULE: Narrative/Alignment
//= Source: Include/Narrative/Alignment.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                    Alignment.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 4 — Fractal Consciousness · cross-TF agreement.          |
//|                                                                  |
//|   Reads each timeframe's direction-by-origin from the multi-TF   |
//|   curve ladder and emits a coherent alignment score plus a       |
//|   plain-English Cross-TF story label that mirrors what the Pine  |
//|   indicator's MTF Curve Map shows.                               |
//+------------------------------------------------------------------+
#ifndef __OMEGA_NARRATIVE_ALIGNMENT_MQH__
#define __OMEGA_NARRATIVE_ALIGNMENT_MQH__


//=== Phase 5.5.3 — CANONICAL ALIGNMENT (per F72 spec) =============
//
//   THIS REPLACES THE FORBIDDEN TIMEFRAME-COUNT MODEL.
//
//   Per the canonical spec: alignment measures NARRATIVE COHERENCE
//   (the quality of relationships between curves), NOT directional
//   agreement (counting how many TFs point the same way).
//
//   Children are EXPECTED to oppose parents. Lower curves rotating
//   against higher curves IS the curve tree at work — not noise to
//   filter. The forbidden patterns:
//
//      aligned_tf_count                FORBIDDEN
//      same_direction_count            FORBIDDEN
//      "4/6 timeframes agree"          FORBIDDEN
//
//   Alignment is computed from the seven RELATIONSHIP signals plus a
//   contradiction penalty. Weights match the spec exactly:
//
//      Ownership Support       15%
//      Compression Persistence 15%
//      Force Quality           10%
//      Chain Vitality          15%
//      Parent Campaign Health  15%
//      Progression Support     15%
//      Transfer Probability    10%   (inverted: low risk = high score)
//      Contradiction          neg.   (subtracted from total)
//
//   Outputs the seven component scores PLUS the weighted total. The
//   HUD shows each component's pass/fail (≥50) so the trader can see
//   which relationship is dragging the story.
//==================================================================
class NarrativeAlignment
  {
public:
   struct Components
     {
      double ownership;        // 0..100
      double compression;      // 0..100
      double force;            // 0..100
      double chain;            // 0..100
      double parent;           // 0..100
      double progression;      // 0..100
      double transfer;         // 0..100 (high = low transfer risk)
      double contradiction;    // 0..100 (subtracted from total)
      double total;            // 0..100 final narrative alignment
     };

   //--- Compute the seven relationship scores plus contradiction.
   //    `narrScore` is the narrative-progression score from the
   //    NarrativeScore module (so we don't double-iterate the lineage).
   static Components Compute(const OmegaState &state, const OmegaCurve &curve, double narrScore)
     {
      Components c;

      //=== 1. Ownership Support (15%) ============================
      //   Current owner alive, energy strong, no recent transfer.
      c.ownership = 25.0;  // baseline if no owner
      int oi = curve.tree.ownerIndex;
      if(oi >= 0)
        {
         if(curve.tree.tree[oi].alive)
           {
            c.ownership = 30.0 + curve.tree.tree[oi].energy * 0.7;  // 30..100
            //-- penalise recent ownership churn
            if(curve.tree.transfersCount > 0)
               c.ownership -= MathMin(20.0, (double)curve.tree.transfersCount * 4.0);
           }
         else
            c.ownership = 12.0;  // owner dead — relationship broken
        }

      //=== 2. Compression Persistence (15%) =====================
      //   The retracement compressing tighter == narrative supports
      //   continuation. Already 0..100 in supporting.compression.
      c.compression = state.supporting.compression;

      //=== 3. Force Quality (10%) ===============================
      c.force = state.supporting.forceScore;

      //=== 4. Chain Vitality (15%) ==============================
      c.chain = state.supporting.chainHealth;

      //=== 5. Parent Campaign Health (15%) ======================
      //   Find the owner's parent in the tree; score by parent.energy.
      //   If owner IS the root, parent-equivalent = own life (the
      //   owner's energy reflects parent-campaign health by proxy).
      c.parent = 50.0;
      if(oi >= 0)
        {
         long pid = curve.tree.tree[oi].parentId;
         if(pid < 0)
           {
            //-- owner is root; parent health == its own life
            c.parent = 35.0 + curve.tree.tree[oi].energy * 0.65;
           }
         else
           {
            for(int j = 0; j < curve.tree.count; j++)
              {
               if(curve.tree.tree[j].id == pid)
                 {
                  if(curve.tree.tree[j].alive)
                     c.parent = 30.0 + curve.tree.tree[j].energy * 0.7;
                  else
                     c.parent = 15.0;  // parent dead — child orphaned
                  break;
                 }
              }
           }
        }

      //=== 6. Progression Support (15%) =========================
      //   Successive curves supporting continuation? Use the
      //   narrative score (positive direction of campaign building).
      c.progression = OmegaMath::Clamp(narrScore, 0.0, 100.0);

      //=== 7. Transfer Probability (10%) — INVERTED =============
      //   Low transfer probability == high relationship support.
      double transferRisk = state.supporting.pTransfer;
      c.transfer = 100.0 - OmegaMath::Clamp(transferRisk, 0.0, 100.0);

      //=== 8. Contradiction (negative weight) ===================
      //   Structural contradictions that undermine narrative
      //   coherence — these REDUCE total alignment.
      c.contradiction = 0.0;
      //-- ownership weak AND life dropping
      if(state.life < 35.0 && oi >= 0)              c.contradiction += 18.0;
      //-- engine primed but no owning curve
      if(state.primed && oi < 0)                    c.contradiction += 22.0;
      //-- chain decaying
      if(state.supporting.chainHealth < 30.0)       c.contradiction += 14.0;
      //-- transfer probability dominating
      if(transferRisk > 60.0)                       c.contradiction += 14.0;
      //-- owner dead (already partly captured but emphasise)
      if(oi >= 0 && !curve.tree.tree[oi].alive)     c.contradiction += 16.0;

      //=== weighted sum ==========================================
      double sum =
           c.ownership   * 0.15
         + c.compression * 0.15
         + c.force       * 0.10
         + c.chain       * 0.15
         + c.parent      * 0.15
         + c.progression * 0.15
         + c.transfer    * 0.10
         - c.contradiction;
      c.total = OmegaMath::Clamp(sum, 0.0, 100.0);
      return c;
     }

   //--- Just the score (when components aren't needed).
   static double Score(const OmegaState &state, const OmegaCurve &curve, double narrScore)
     {
      Components c = Compute(state, curve, narrScore);
      return c.total;
     }

   //--- Narrative-coherence story label (replaces TF-count Story).
   static string Story(double na, int ownerDir)
     {
      if(ownerDir == 0)        return "no owning curve";
      if(na >= 80.0)           return "story coherent · curve alignment supports continuation";
      if(na >= 65.0)           return "story holding · relationships supportive";
      if(na >= 50.0)           return "story mixed · some relationships dragging";
      if(na >= 35.0)           return "story weakening · structural contradiction building";
      return "story incoherent · relationships broken";
     }

   //--- Per-TF dir snapshot for INFO display only (HUD MTF map).
   //    This is rendering data, never a gate. Use to draw arrows in
   //    the MTF panel — children opposing parents is normal.
   static string TfRow(const OmegaCurve &curve)
     {
      return StringFormat("M1:%d M3:%d M5:%d M15:%d H1:%d H4:%d",
                          curve.tfM1.DirByOrigin(),  curve.tfM3.DirByOrigin(),
                          curve.tfM5.DirByOrigin(),  curve.tfM15.DirByOrigin(),
                          curve.tfH1.DirByOrigin(),  curve.tfH4.DirByOrigin());
     }

   //--- INFORMATIONAL TF count — exposed only for display rendering
   //    (e.g., HUD shows "3 of 6 same dir as owner — child rotation").
   //    NEVER USED FOR DECISIONS. Calling it from any gate path is
   //    a violation of the canonical alignment spec.
   static int InfoTfCountSameDir(const OmegaCurve &curve, int refDir)
     {
      if(refDir == 0) return 0;
      int n = 0;
      if(curve.tfM1.DirByOrigin()  == refDir) n++;
      if(curve.tfM3.DirByOrigin()  == refDir) n++;
      if(curve.tfM5.DirByOrigin()  == refDir) n++;
      if(curve.tfM15.DirByOrigin() == refDir) n++;
      if(curve.tfH1.DirByOrigin()  == refDir) n++;
      if(curve.tfH4.DirByOrigin()  == refDir) n++;
      return n;
     }
  };

//=== legacy alias removed — Alignment class deleted (TF-count) ====

#endif // __OMEGA_NARRATIVE_ALIGNMENT_MQH__

//==================================================================
//= MODULE: Narrative/NarrativeScore
//= Source: Include/Narrative/NarrativeScore.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                              NarrativeScore.mqh  |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 8 — Sequence Intelligence · narrative LINEAGE.           |
//|                                                                  |
//|   Tracks the SEQUENCE of entry curves born within the owner's    |
//|   direction:                                                     |
//|                                                                  |
//|     origin curve → entry curve → progress curve → entry curve →  |
//|     progress curve → terminal curve                              |
//|                                                                  |
//|   Each completed pullback within the owner's direction VOTES:    |
//|     SUPPORT (shallow retrace + tightening) → narrative builds    |
//|     DEGRADE (deep retrace + broadening)    → narrative fades     |
//|     NEUTRAL (in between)                   → no shift            |
//|                                                                  |
//|   A converging sequence (shallower retraces, rising compression) |
//|   ⇒ STRENGTHENING; diverging ⇒ WEAKENING.                        |
//|                                                                  |
//|   This is "can I keep holding?" answered by lineage, not by the  |
//|   current curve alone.                                           |
//+------------------------------------------------------------------+
#ifndef __OMEGA_NARRATIVE_TRACKER_MQH__
#define __OMEGA_NARRATIVE_TRACKER_MQH__


#define OMEGA_NARR_SEQ_CAP   8

enum ENUM_NARRATIVE_VOTE
  {
   NARR_VOTE_NONE     = 0,
   NARR_VOTE_NEUTRAL  = 1,
   NARR_VOTE_SUPPORT  = 2,
   NARR_VOTE_DEGRADE  = 3
  };

enum ENUM_NARRATIVE_STATE
  {
   NARR_STATE_HOLDING        = 0,
   NARR_STATE_STRENGTHENING  = 1,
   NARR_STATE_WEAKENING      = 2
  };

class NarrativeTracker
  {
private:
   //--- direction tracking
   int     m_narrDir;
   double  m_legExtreme;        // current leg's running extreme price
   double  m_legPullbackDepth;  // running max % pullback in this leg

   //--- score state
   double  m_score;             // 0..100
   ENUM_NARRATIVE_VOTE m_lastVote;
   int     m_supVotes;
   int     m_degVotes;

   //--- recent retrace sequence
   double  m_seqRetr[OMEGA_NARR_SEQ_CAP];
   int     m_seqHead;
   int     m_seqCount;

   void PushRetr(double pct)
     {
      m_seqRetr[m_seqHead] = pct;
      m_seqHead = (m_seqHead + 1) % OMEGA_NARR_SEQ_CAP;
      if(m_seqCount < OMEGA_NARR_SEQ_CAP) m_seqCount++;
     }

public:
                     NarrativeTracker() { Reset(); }

   void Reset()
     {
      m_narrDir = 0;
      m_legExtreme = 0.0;
      m_legPullbackDepth = 0.0;
      m_score = OMEGA_TRINITY_NEUTRAL;
      m_lastVote = NARR_VOTE_NONE;
      m_supVotes = 0;
      m_degVotes = 0;
      m_seqHead = 0;
      m_seqCount = 0;
      ArrayInitialize(m_seqRetr, 0.0);
     }

   //--- Per-bar update.
   //    `ownerDir`: -1/0/+1 from the curve tree's dominant owner
   //    `ownerOrigin`: parent curve origin price
   //    `barHigh/Low/Close`: the just-closed bar
   //    `cmpTighten`: Δ compression over recent bars (see Compression module)
   void Update(int ownerDir, double ownerOrigin,
                double barHigh, double barLow, double barClose,
                double cmpTighten)
     {
      //-- ownership direction change → reset lineage
      if(ownerDir != m_narrDir)
        {
         m_narrDir = ownerDir;
         m_legExtreme = (ownerDir == 1) ? barHigh : (ownerDir == -1 ? barLow : 0.0);
         m_legPullbackDepth = 0.0;
         m_score = OMEGA_TRINITY_NEUTRAL;
         m_supVotes = m_degVotes = 0;
         m_lastVote = NARR_VOTE_NONE;
         m_seqHead = 0;
         m_seqCount = 0;
         ArrayInitialize(m_seqRetr, 0.0);
         return;
        }
      if(ownerDir == 0 || ownerOrigin == 0.0) return;

      //-- did the leg extend to a new extreme?
      bool newLegX = false;
      if(ownerDir == 1)  newLegX = (m_legExtreme == 0.0) || (barHigh > m_legExtreme);
      if(ownerDir == -1) newLegX = (m_legExtreme == 0.0) || (barLow  < m_legExtreme);

      if(newLegX)
        {
         //-- vote on the JUST-COMPLETED pullback (if it was real)
         if(m_legPullbackDepth > 6.0)
           {
            bool sup = (m_legPullbackDepth <= 50.0) && (cmpTighten >= -1.0);
            bool deg = (m_legPullbackDepth >= 62.0) || (cmpTighten <  -3.0);
            ENUM_NARRATIVE_VOTE v = NARR_VOTE_NEUTRAL;
            int delta = 0;
            if(sup) { v = NARR_VOTE_SUPPORT; delta =  1; m_supVotes++; }
            else if(deg) { v = NARR_VOTE_DEGRADE; delta = -1; m_degVotes++; }
            m_lastVote = v;
            m_score = OmegaMath::Clamp(
               m_score + delta * 12.0 + (cmpTighten > 0.0 ? 3.0 : -3.0),
               0.0, 100.0);
            PushRetr(m_legPullbackDepth);
           }
         m_legExtreme = (ownerDir == 1) ? barHigh : barLow;
         m_legPullbackDepth = 0.0;
        }
      else
        {
         //-- still pulling back: track running max pullback %
         double legSpan = MathAbs(m_legExtreme - ownerOrigin);
         if(legSpan > 1e-9)
           {
            double pbd = MathAbs(m_legExtreme - barClose) / legSpan * 100.0;
            if(pbd > m_legPullbackDepth) m_legPullbackDepth = pbd;
           }
        }
     }

   //--- accessors
   double Score() const { return m_score; }
   int    SupportVotes() const  { return m_supVotes; }
   int    DegradeVotes() const  { return m_degVotes; }
   int    Direction() const     { return m_narrDir; }
   ENUM_NARRATIVE_VOTE LastVote() const { return m_lastVote; }
   double LegPullbackDepth() const  { return m_legPullbackDepth; }

   //--- HOLDING / STRENGTHENING / WEAKENING
   ENUM_NARRATIVE_STATE State() const
     {
      if(m_score >= 65.0) return NARR_STATE_STRENGTHENING;
      if(m_score <= 35.0) return NARR_STATE_WEAKENING;
      return NARR_STATE_HOLDING;
     }

   static string StateString(ENUM_NARRATIVE_STATE s)
     {
      switch(s)
        {
         case NARR_STATE_STRENGTHENING: return "STRENGTHENING";
         case NARR_STATE_WEAKENING:     return "WEAKENING";
         case NARR_STATE_HOLDING:       return "HOLDING";
        }
      return "UNKNOWN";
     }

   static string VoteString(ENUM_NARRATIVE_VOTE v)
     {
      switch(v)
        {
         case NARR_VOTE_SUPPORT:  return "SUPPORT";
         case NARR_VOTE_DEGRADE:  return "DEGRADE";
         case NARR_VOTE_NEUTRAL:  return "NEUTRAL";
         case NARR_VOTE_NONE:     return "NONE";
        }
      return "?";
     }

   //--- last 2 retrace samples → converging if newest < previous
   bool Converging() const
     {
      if(m_seqCount < 2) return false;
      int latest   = (m_seqHead - 1 + OMEGA_NARR_SEQ_CAP) % OMEGA_NARR_SEQ_CAP;
      int previous = (m_seqHead - 2 + OMEGA_NARR_SEQ_CAP) % OMEGA_NARR_SEQ_CAP;
      return m_seqRetr[latest] < m_seqRetr[previous];
     }

   //--- short snapshot for heartbeat
   string Snapshot() const
     {
      return StringFormat("%s narr=%.0f S/D=%d/%d last=%s pb=%.0f%% conv=%s",
                          StateString(State()), m_score,
                          m_supVotes, m_degVotes,
                          VoteString(m_lastVote), m_legPullbackDepth,
                          Converging() ? "Y" : "N");
     }
  };

#endif // __OMEGA_NARRATIVE_TRACKER_MQH__

//==================================================================
//= MODULE: Narrative/Confidence
//= Source: Include/Narrative/Confidence.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                   Confidence.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 14 — StoryConfidence · "How much do I trust myself?"     |
//|                                                                  |
//|   Phase 4 baseline: confidence is a slow-moving composite of the |
//|   ENGINE's current internal coherence:                           |
//|                                                                  |
//|     ownership certainty   — is one curve clearly dominant?       |
//|     chain-life agreement  — does life agree with chain scope?    |
//|     compression clarity   — is compression NOT oscillating?      |
//|     narrative consistency — votes one-sided or balanced?         |
//|     alignment             — fractal stack agreement              |
//|                                                                  |
//|   Phase 6 (SelfObservation) will OVERWRITE this with rolling     |
//|   hit-rate / contradiction / regime-stability metrics derived    |
//|   from decision_log.csv. This module's API stays the same so     |
//|   the upgrade is transparent to upstream.                        |
//+------------------------------------------------------------------+
#ifndef __OMEGA_NARRATIVE_CONFIDENCE_MQH__
#define __OMEGA_NARRATIVE_CONFIDENCE_MQH__


//=== Inputs ========================================================
struct ConfidenceInputs
  {
   double  ownershipStability;   // 0..100, from tree
   double  chainHealthScore;     // 0..100, from chain
   double  life;                 // 0..100, from LifeScore
   double  compression;          // 0..100, raw
   double  compTighten;          // signed Δ
   double  alignment;            // 0..100, from Alignment
   int     supVotes;             // narrative
   int     degVotes;             // narrative
   bool    primed;
  };

class ConfidenceTracker
  {
private:
   double m_score;       // 0..100, slow-moving
   double m_alpha;       // EMA smoothing factor

public:
                     ConfidenceTracker() { Reset(); }

   void Reset()
     {
      m_score = OMEGA_TRINITY_NEUTRAL;
      m_alpha = 0.10;       // ~10-bar half-life
     }

   void Update(const ConfidenceInputs &in)
     {
      if(!in.primed)
        {
         //-- not perceiving yet → no claim of confidence
         m_score = m_score + m_alpha * (OMEGA_TRINITY_NEUTRAL - m_score);
         return;
        }

      //-- 1. Ownership certainty: directly from stability score
      double cOwn = in.ownershipStability;

      //-- 2. Chain-life agreement: chain health and life should AGREE.
      //     Penalize divergence.
      double diff = MathAbs(in.chainHealthScore - in.life);
      double cChain = OmegaMath::Clamp(100.0 - diff, 0.0, 100.0);

      //-- 3. Compression clarity: tightening is more "readable" than oscillation.
      //     Reward compression movement (either direction); penalize zero/random.
      double cComp = OmegaMath::Clamp(50.0 + MathAbs(in.compTighten) * 5.0, 0.0, 100.0);

      //-- 4. Narrative consistency: votes one-sided gives confidence,
      //     balanced votes erodes it.
      int totVotes = in.supVotes + in.degVotes;
      double cNarr = OMEGA_TRINITY_NEUTRAL;
      if(totVotes > 0)
        {
         double dom = MathMax(in.supVotes, in.degVotes) / (double)totVotes;
         cNarr = OmegaMath::Clamp(dom * 100.0, 0.0, 100.0);
        }

      //-- 5. Alignment: directly from the fractal stack
      double cAlign = in.alignment;

      //-- weighted blend (Phase 6 will tune via SelfObservation)
      double composite = cOwn   * 0.25
                       + cChain * 0.20
                       + cComp  * 0.15
                       + cNarr  * 0.15
                       + cAlign * 0.25;
      composite = OmegaMath::Clamp(composite, 0.0, 100.0);

      //-- slow EMA (confidence shouldn't whip around)
      m_score = m_score + m_alpha * (composite - m_score);
     }

   double Score() const { return m_score; }
  };

#endif // __OMEGA_NARRATIVE_CONFIDENCE_MQH__

//==================================================================
//= MODULE: Narrative/Story
//= Source: Include/Narrative/Story.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                        Story.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 3 → 14 — the Narrative orchestrator.                     |
//|                                                                  |
//|   Sits BELOW the Curve+Tree perception and ABOVE Risk/Capital.   |
//|   On each closed bar it:                                         |
//|                                                                  |
//|     1. Reads the chart-TF curve + tree state                     |
//|     2. Computes LifeScore from the canonical formula             |
//|     3. Updates the NarrativeTracker (lineage votes)              |
//|     4. Computes Alignment + cross-TF story                       |
//|     5. Updates ConfidenceTracker                                 |
//|     6. Writes life / stability / confidence DIRECTLY into        |
//|        OmegaState (Memory's DeriveTrinity becomes a clamp guard) |
//|     7. Emits a plain-English "story" string for the heartbeat    |
//|                                                                  |
//|   This is where the Trinity goes fully live. After Phase 4 the   |
//|   engine has continuous awareness of the life of the story.      |
//+------------------------------------------------------------------+
#ifndef __OMEGA_NARRATIVE_STORY_MQH__
#define __OMEGA_NARRATIVE_STORY_MQH__


class OmegaStory
  {
public:
   //--- subcomponents
   NarrativeTracker  narrative;
   ConfidenceTracker confidence;

   //--- last-update outputs (exposed for snapshot / explainability)
   double            lastLife;
   double            lastStability;
   double            lastConfidence;
   int               bias;             // -1 / 0 / +1
   //--- Phase 5.5.3 — narrative alignment (replaces TF-count alignedCount)
   //    The full component breakdown is exposed so the HUD can show
   //    each relationship's pass/fail. naScore is the weighted total.
   NarrativeAlignment::Components naComp;
   double            naScore;
   //    InfoTfCount is the per-TF dir count vs owner — INFO ONLY,
   //    rendered in HUD/log but never used for decisions.
   int               infoTfCount;
   string            crossTfStory;
   ENUM_LIFE_VERDICT lifeVerdict;
   double            retrX;
   bool              progressing;
   bool              recursionComplete;

   //--- bookkeeping
   string            symbol;
   long              barsProcessed;
   datetime          lastBarTime;

                     OmegaStory()
     {
      lastLife = lastStability = lastConfidence = OMEGA_TRINITY_NEUTRAL;
      bias = 0; naScore = 0.0; infoTfCount = 0; ZeroMemory(naComp);
      crossTfStory = "—";
      lifeVerdict = LIFE_DEAD;
      retrX = 50.0;
      progressing = false; recursionComplete = false;
      symbol = ""; barsProcessed = 0; lastBarTime = 0;
     }

   void Init(string sym)
     {
      symbol = sym;
      narrative.Reset();
      confidence.Reset();
      OmegaLogger::LogInfo("STORY",
         StringFormat("Init %s · LifeScore + NarrativeTracker + ConfidenceTracker", sym));
     }

   void Reset()
     {
      narrative.Reset();
      confidence.Reset();
      lastLife = lastStability = lastConfidence = OMEGA_TRINITY_NEUTRAL;
      bias = 0; naScore = 0.0; infoTfCount = 0; ZeroMemory(naComp);
      crossTfStory = "—";
      lifeVerdict = LIFE_DEAD;
      retrX = 50.0;
      progressing = false; recursionComplete = false;
      barsProcessed = 0; lastBarTime = 0;
     }

   //--- Main per-bar narrative update. Writes directly to OmegaState.
   bool Update(OmegaState &state, OmegaCurve &curve)
     {
      if(!curve.primed) return false;
      CurveState *chart = curve.ChartTfState();
      if(chart == NULL) return false;
      if(!chart.physics.ready) return false;
      datetime t = chart.lastBarTime;
      if(t == 0 || t == lastBarTime) return false;
      lastBarTime = t;
      barsProcessed++;

      //=== 1. resolve owner state ===================================
      int idx = curve.tree.ownerIndex;
      int ownerDir = (idx >= 0) ? curve.tree.tree[idx].dir     : 0;
      double ownerOrigin  = (idx >= 0) ? curve.tree.tree[idx].origin  : 0.0;
      double ownerExtreme = (idx >= 0) ? curve.tree.tree[idx].extreme : 0.0;
      double ownerEnergy  = (idx >= 0) ? curve.tree.tree[idx].energy  : 0.0;

      double bar1Close = iClose(symbol, chart.tf, 1);
      double bar1High  = iHigh(symbol,  chart.tf, 1);
      double bar1Low   = iLow(symbol,   chart.tf, 1);

      //=== 2. derived life inputs ===================================
      progressing = false;
      if(ownerDir == 1  && ownerExtreme > 0.0) progressing = (bar1High >= ownerExtreme);
      if(ownerDir == -1 && ownerExtreme > 0.0) progressing = (bar1Low  <= ownerExtreme);

      retrX = 50.0;
      if(ownerOrigin != 0.0 && ownerExtreme != 0.0 && ownerOrigin != ownerExtreme)
        {
         retrX = MathMin(100.0,
                  MathAbs(ownerExtreme - bar1Close) /
                  MathAbs(ownerExtreme - ownerOrigin) * 100.0);
        }

      recursionComplete = (curve.tree.recursionBudget > 0
                           && curve.tree.treeDepth >= curve.tree.recursionBudget);

      LifeInputs li;
      li.cpForce           = curve.gForce;
      li.residualEnergy    = ownerEnergy;
      li.cmpTighten        = curve.compress.Tightening(5);
      li.retrX             = retrX;
      li.progressing       = progressing;
      li.recursionComplete = recursionComplete;
      li.forceLeaking      = (curve.gForceState == FORCE_LEAKING);

      double life = LifeScore::Compute(li);
      lifeVerdict = LifeScore::Verdict(life);

      //=== 3. narrative tracker =====================================
      narrative.Update(ownerDir, ownerOrigin, bar1High, bar1Low, bar1Close, li.cmpTighten);
      double narrScore = narrative.Score();

      //=== 4. alignment — NARRATIVE COHERENCE (Phase 5.5.3) =========
      //   Replaces the deleted TF-count Alignment. Computes weighted
      //   relationship score from ownership / compression / force /
      //   chain / parent / progression / transfer-risk minus
      //   contradiction. TF DIRECTION COUNTING IS FORBIDDEN here per
      //   the canonical alignment spec — children rotating against
      //   parents is the curve tree at work, not noise.
      bias = ownerDir;
      naComp = NarrativeAlignment::Compute(state, curve, narrScore);
      double alignScore = naComp.total;
      naScore = alignScore;
      crossTfStory = NarrativeAlignment::Story(alignScore, bias);
      //   Informational only — what the per-TF directions LOOK like
      //   right now (rendered in HUD MTF panel). Never gates a trade.
      infoTfCount = NarrativeAlignment::InfoTfCountSameDir(curve, bias);

      //=== 5. stability (Layer 3 fold: alignment + narrative + regime) =====
      //   Phase 4: regime stays neutral (Phase 6 will populate).
      double regime = OMEGA_TRINITY_NEUTRAL;
      double stability = OmegaMath::Clamp(
         alignScore  * 0.40 +
         narrScore   * 0.40 +
         regime      * 0.20,
         0.0, 100.0);

      //=== 6. confidence ============================================
      ConfidenceInputs ci;
      ci.ownershipStability = curve.tree.ownerStability;
      ci.chainHealthScore   = curve.tree.chain.Score(life);
      ci.life               = life;
      ci.compression        = curve.gCompression;
      ci.compTighten        = li.cmpTighten;
      ci.alignment          = alignScore;
      ci.supVotes           = narrative.SupportVotes();
      ci.degVotes           = narrative.DegradeVotes();
      ci.primed             = state.primed;
      confidence.Update(ci);

      //=== 7. write into the trinity ================================
      state.life       = life;
      state.stability  = stability;
      state.confidence = confidence.Score();

      //--- supporting fields (alignment + narrative live now)
      state.supporting.alignment = alignScore;
      state.supporting.narrative = narrScore;

      //=== bookkeeping outputs ======================================
      lastLife       = life;
      lastStability  = stability;
      lastConfidence = state.confidence;
      return true;
     }

   //--- short snapshot for heartbeat
   string Snapshot() const
     {
      return StringFormat(
         "L=%.1f(%s) S=%.1f C=%.1f bias=%d narr-align=%.0f%% (own=%.0f cmp=%.0f frc=%.0f chn=%.0f par=%.0f prg=%.0f xfer=%.0f cnt=%.0f) info-tf=%d/6 retrX=%.0f%% prog=%s budget=%s · %s · cross=\"%s\"",
         lastLife, LifeScore::VerdictString(lifeVerdict),
         lastStability, lastConfidence,
         bias, naScore,
         naComp.ownership, naComp.compression, naComp.force, naComp.chain,
         naComp.parent, naComp.progression, naComp.transfer, naComp.contradiction,
         infoTfCount, retrX,
         progressing ? "Y" : "N",
         recursionComplete ? "DONE" : "LEFT",
         narrative.Snapshot(), crossTfStory);
     }

   //--- one-line trader voice (extends Snapshot for richer logging)
   string Voice() const
     {
      string lifeStr = LifeScore::VerdictString(lifeVerdict);
      string biasStr = (bias == 1 ? "BULL" : bias == -1 ? "BEAR" : "NEUTRAL");
      return StringFormat("%s curve · %s · L=%.0f S=%.0f C=%.0f · %s",
                          biasStr, lifeStr, lastLife, lastStability, lastConfidence,
                          crossTfStory);
     }
  };

#endif // __OMEGA_NARRATIVE_STORY_MQH__
//==================================================================
//= MODULE: Chart  (Phase 5.5 — On-chart diagnostics)
//= Source: Include/Chart.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                        Chart.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|  See what the engine is seeing and doing — directly on the chart |
//|  it's attached to. Every visual is a native MT5 chart object     |
//|  (OBJ_RECTANGLE_LABEL, OBJ_LABEL, OBJ_RECTANGLE, OBJ_TREND,      |
//|  OBJ_ARROW, OBJ_TEXT). All names share a magic-prefix so cleanup |
//|  on Deinit is bulletproof.                                       |
//|                                                                  |
//|  The chart layer reads the same Trinity + curve tree + per-tier  |
//|  state that the trading engine reads — it is a pure observer.    |
//|  It can never affect a decision.                                 |
//|                                                                  |
//|  Layout:                                                         |
//|    HUD panel (top-left)         — Trinity bars · tier · verdict  |
//|    MTF map (top-right)          — per-TF direction + state       |
//|    Owner-curve box (price)      — origin→extreme rectangle       |
//|    Budget-target arrow (price)  — current px → owner.extreme     |
//|    FU spike marks (chart bars)  — rejection-wick detector        |
//|    Position labels (entry bars) — tier · int · act risk          |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CHART_MQH__
#define __OMEGA_CHART_MQH__

class OmegaChart
  {
private:
   string  m_prefix;
   bool    m_enabled;
   bool    m_drawHUD;
   bool    m_drawMTF;
   bool    m_drawOwner;
   bool    m_drawFlip;
   bool    m_drawBudget;
   bool    m_drawFU;
   bool    m_drawPositions;
   int     m_hudCorner;          // CORNER_LEFT_UPPER etc.
   int     m_hudX, m_hudY;
   int     m_mtfCorner;
   int     m_mtfX, m_mtfY;
   int     m_lineHeight;         // pixels per HUD row
   int     m_hudWidth;           // px
   int     m_mtfWidth;           // px
   color   m_bg;
   color   m_fg;
   color   m_dim;
   color   m_bull;
   color   m_bear;
   color   m_warn;
   double  m_fuWickFrac;
   int     m_fuLookback;
   int     m_minAlign;            // legacy — kept for an info-only TF count row
   double  m_narrAlignMin;        // 65 — canonical gate threshold
   long    m_lastOwnerId;
   datetime m_lastOwnerTime;
   int     m_posCounter;         // monotonic for position-marker names

   //--- Object name helpers
   string N(string sub) const { return m_prefix + "_" + sub; }

   void DelByPrefix(string sub)
     {
      string match = m_prefix + "_" + sub;
      int total = ObjectsTotal(0, -1, -1);
      for(int i = total - 1; i >= 0; i--)
        {
         string name = ObjectName(0, i, -1, -1);
         if(StringFind(name, match) == 0) ObjectDelete(0, name);
        }
     }

   //--- Pixel-anchored label (HUD/MTF). Always set ANCHOR + corner so
   //    the panel sticks to the configured corner regardless of zoom.
   void EnsureLabel(string name, int corner, int x, int y, string txt,
                    color clr, int sz = 9, string font = "Consolas")
     {
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER,    corner);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR,    ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString (0, name, OBJPROP_TEXT,      txt);
      ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  sz);
      ObjectSetString (0, name, OBJPROP_FONT,      font);
      ObjectSetInteger(0, name, OBJPROP_BACK,      false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN,    true);
     }

   //--- Pixel-anchored rectangle background (HUD frame).
   void EnsureRectLabel(string name, int corner, int x, int y, int w, int h,
                         color bg, color border)
     {
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER,    corner);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR,    ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE,     w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE,     h);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR,   bg);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_COLOR,     border);
      ObjectSetInteger(0, name, OBJPROP_BACK,      true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN,    true);
     }

   //--- Generic 0..100 ASCII bar (10 cells) — visible without unicode tricks.
   string GaugeBar(double v) const
     {
      v = MathMax(0.0, MathMin(100.0, v));
      int filled = (int)MathRound(v / 10.0);
      string s = "[";
      for(int i = 0; i < 10; i++) s += (i < filled) ? "#" : ".";
      s += "]";
      return s;
     }

   //--- TF arrow glyph
   string DirArrow(int d) const { return d == 1 ? "^" : d == -1 ? "v" : "-"; }
   color  DirColor(int d) const { return d == 1 ? m_bull : d == -1 ? m_bear : m_dim; }

public:
                     OmegaChart()
     {
      m_prefix = "OMEGA";
      m_enabled = true;
      m_drawHUD = true;
      m_drawMTF = true;
      m_drawOwner = true;
      m_drawFlip = true;
      m_drawBudget = true;
      m_drawFU = true;
      m_drawPositions = true;
      m_hudCorner = CORNER_LEFT_UPPER;
      m_hudX = 8;  m_hudY = 24;
      m_mtfCorner = CORNER_RIGHT_UPPER;
      m_mtfX = 8;  m_mtfY = 24;
      m_lineHeight = 14;
      m_hudWidth = 280;
      m_mtfWidth = 220;
      m_bg   = (color)0x0A0E27;
      m_fg   = (color)0xD7FAFF;
      m_dim  = (color)0x94A3B8;
      m_bull = (color)0x34D399;
      m_bear = (color)0x6285FB;     // BGR for #FB7185
      m_warn = (color)0x24BFFB;     // BGR for #FBBF24
      m_fuWickFrac = 0.30;
      m_fuLookback = 5;
      m_minAlign   = 4;
      m_narrAlignMin = 65.0;
      m_lastOwnerId = -1;
      m_lastOwnerTime = 0;
      m_posCounter = 0;
     }

   void Init(string prefix, bool enabled,
             bool drawHUD, bool drawMTF, bool drawOwner, bool drawFlip, bool drawBudget,
             bool drawFU,  bool drawPositions,
             double fuWickFrac = 0.30, int fuLookback = 5)
     {
      m_prefix         = (StringLen(prefix) > 0) ? prefix : "OMEGA";
      m_enabled        = enabled;
      m_drawHUD        = drawHUD;
      m_drawMTF        = drawMTF;
      m_drawOwner      = drawOwner;
      m_drawFlip       = drawFlip;
      m_drawBudget     = drawBudget;
      m_drawFU         = drawFU;
      m_drawPositions  = drawPositions;
      m_fuWickFrac     = fuWickFrac;
      m_fuLookback     = fuLookback;
      OmegaLogger::LogInfo("CHART",
         StringFormat("Init · enabled=%s · HUD=%s MTF=%s owner=%s flip=%s budget=%s FU=%s pos=%s · prefix=%s",
                      enabled ? "YES" : "NO",
                      drawHUD ? "Y" : "N", drawMTF ? "Y" : "N", drawOwner ? "Y" : "N",
                      drawFlip ? "Y" : "N", drawBudget ? "Y" : "N",
                      drawFU ? "Y" : "N", drawPositions ? "Y" : "N",
                      m_prefix));
     }

   void Deinit()
     {
      // sweep every object whose name starts with the magic prefix
      string match = m_prefix + "_";
      int total = ObjectsTotal(0, -1, -1);
      for(int i = total - 1; i >= 0; i--)
        {
         string name = ObjectName(0, i, -1, -1);
         if(StringFind(name, match) == 0) ObjectDelete(0, name);
        }
      ChartRedraw(0);
     }

   //--- Phase 5.5 — wire the entry-alignment gate from EA inputs so the
   //    HUD's gate line stays in sync with the decision engine.
   void SetEntryGates(int minAlign) { m_minAlign = minAlign; }

   //--- Phase 5.5.3 — wire the canonical narrative-coherence floor.
   //    The gate line lights green only when state.supporting.alignment
   //    (NarrativeAlignment::Compute total) is >= this threshold.
   void SetNarrativeAlignMin(double v) { m_narrAlignMin = v; }

   //--- Per-tick update (called from EA OnTick).
   //    Phase 5.5.4: kept narrow — does not reference the late-declared
   //    Phase 5.2/9/10/11/12/13/14 classes. The EA passes their
   //    pre-formatted status as a string array to UpdatePhasesPanel.
   void Update(const OmegaState &state, OmegaCurve &curve,
               OmegaRisk &risk, OmegaCapital &capital,
               OmegaStory &story,
               ENUM_OMEGA_DECISION lastDec, ENUM_OMEGA_REASON lastReason)
     {
      if(!m_enabled) return;

      ENUM_OMEGA_TIER tier = risk.TierForCap(capital);
      double effEq = risk.EffectiveEquity(capital);

      if(m_drawHUD)    UpdateHUD(state, curve, story, tier, risk, effEq, lastDec, lastReason);
      if(m_drawMTF)    UpdateMTFMap(curve);
      if(m_drawOwner)  UpdateOwnerBox(curve);
      if(m_drawFlip)   UpdateFlipZone(curve);
      if(m_drawBudget) UpdateBudgetTarget(curve);
      if(m_drawFU)     UpdateFUMarks();

      ChartRedraw(0);
     }

   //--- Phase 5.5.4 — Phases status panel. Takes pre-formatted lines so
   //    the chart class doesn't depend on the new phase types. EA's
   //    OnTick builds the lines from each phase module.
   void UpdatePhasesPanel(string fundedLine, string memLine, string attLine,
                           string portLine, string metaLine, string evolLine,
                           string lastDecLine, color portColor = (color)0x000000,
                           color metaColor = (color)0x000000, color attColor = (color)0x000000,
                           color fundedColor = (color)0x000000)
     {
      if(!m_enabled) return;
      int corner = CORNER_LEFT_LOWER;
      int X = 8, Y = 8;
      int W = 360;
      int rows = 8;
      int H = m_lineHeight * rows + 14;
      EnsureRectLabel(N("PH_BG"), corner, X, Y + H - 14, W, H, m_bg, m_dim);
      int rx = X + 8;
      int ry = Y + 8;
      EnsureLabel(N("PH_TITLE"), corner, rx, ry + (rows - 1) * m_lineHeight,
                   "PHASES STATUS", m_fg, 10, "Consolas");
      EnsureLabel(N("PH_FUNDED"), corner, rx, ry + (rows - 2) * m_lineHeight, fundedLine,
                   fundedColor != (color)0x000000 ? fundedColor : m_dim);
      EnsureLabel(N("PH_MEM"),    corner, rx, ry + (rows - 3) * m_lineHeight, memLine,    m_dim);
      EnsureLabel(N("PH_ATT"),    corner, rx, ry + (rows - 4) * m_lineHeight, attLine,
                   attColor != (color)0x000000 ? attColor : m_dim);
      EnsureLabel(N("PH_PORT"),   corner, rx, ry + (rows - 5) * m_lineHeight, portLine,
                   portColor != (color)0x000000 ? portColor : m_dim);
      EnsureLabel(N("PH_MC"),     corner, rx, ry + (rows - 6) * m_lineHeight, metaLine,
                   metaColor != (color)0x000000 ? metaColor : m_dim);
      EnsureLabel(N("PH_EV"),     corner, rx, ry + (rows - 7) * m_lineHeight, evolLine,    m_dim);
      EnsureLabel(N("PH_EX"),     corner, rx, ry + 0,                           lastDecLine, m_dim);
     }

   //--- Called from CampaignPositions::Open after a successful entry.
   //    Drops a marker arrow + label at the bar where the trade fired.
   void OnPositionOpen(string symbol, ulong ticket, int direction,
                        double openPx, double sl,
                        ENUM_OMEGA_TIER tier, double intendedPct, double actualPct,
                        double lots, string detail)
     {
      if(!m_enabled || !m_drawPositions) return;
      m_posCounter++;
      string an = N("POS_ARR_" + IntegerToString(m_posCounter));
      string ln = N("POS_LBL_" + IntegerToString(m_posCounter));
      datetime t = TimeCurrent();
      color c = (direction == 1) ? m_bull : m_bear;

      if(ObjectFind(0, an) < 0) ObjectCreate(0, an, OBJ_ARROW, 0, t, openPx);
      ObjectSetInteger(0, an, OBJPROP_ARROWCODE, direction == 1 ? 233 : 234);  // up/down arrows
      ObjectSetInteger(0, an, OBJPROP_COLOR, c);
      ObjectSetInteger(0, an, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, an, OBJPROP_BACK,  false);
      ObjectSetInteger(0, an, OBJPROP_HIDDEN,true);
      ObjectSetString (0, an, OBJPROP_TOOLTIP,
         StringFormat("%s #%I64u · %.2f lots @ %.5f · SL %.5f · int %.2f%% act %.2f%%",
                       direction == 1 ? "BUY" : "SELL", ticket, lots, openPx, sl,
                       intendedPct, actualPct));

      string txt = StringFormat("%s %.2f", direction == 1 ? "B" : "S", lots);
      if(ObjectFind(0, ln) < 0) ObjectCreate(0, ln, OBJ_TEXT, 0, t, openPx);
      ObjectSetString (0, ln, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, ln, OBJPROP_COLOR, c);
      ObjectSetInteger(0, ln, OBJPROP_FONTSIZE, 8);
      ObjectSetString (0, ln, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, ln, OBJPROP_ANCHOR,
                        direction == 1 ? ANCHOR_UPPER : ANCHOR_LOWER);
      ObjectSetInteger(0, ln, OBJPROP_HIDDEN, true);
     }

private:
   //=== HUD =========================================================
   //  Phase 5.6 — CANONICAL F72 RULE: "Components are CONTRIBUTORS,
   //  never gates." This HUD shows every signal as a continuous value
   //  with a horizontal bar — NOT pass/fail. The only red bar at
   //  the bottom is for actual catastrophic vetoes (margin / capital
   //  state / funded trip / portfolio cap), and even those merely
   //  read "PAUSED" — never "BLOCKED" by a component score.
   //
   //  The trinity floors that USED to gate (life/stab/conf per tier)
   //  are kept as informational reference levels only. The narrative
   //  alignment threshold likewise — informational only.
   //
   void UpdateHUD(const OmegaState &s, OmegaCurve &curve, OmegaStory &story,
                  ENUM_OMEGA_TIER tier, OmegaRisk &risk, double effEq,
                  ENUM_OMEGA_DECISION lastDec, ENUM_OMEGA_REASON lastReason)
     {
      int rows = 19;
      int W = m_hudWidth;
      int H = m_lineHeight * rows + 14;
      int X = m_hudX;
      int Y = m_hudY;
      EnsureRectLabel(N("HUD_BG"), m_hudCorner, X, Y, W, H, m_bg, m_dim);

      int row = 0;
      int rx = X + 8;
      int ry = Y + 8;

      // Title
      EnsureLabel(N("HUD_TITLE"), m_hudCorner, rx, ry + row * m_lineHeight,
                   "F72 OMEGA  ·  v" + OMEGA_VERSION, m_fg, 10, "Consolas");
      row++;

      // Tier line
      string tierLine = StringFormat("Tier %s  ·  eq %.2f  ·  cap %.2f%%  ·  pyr %d",
                                     risk.TierStr(tier), effEq,
                                     risk.TierMaxRiskPct(tier),
                                     risk.TierMaxBudget(tier));
      color tcol = (tier == TIER_MICRO) ? m_warn :
                   (tier == TIER_SMALL) ? m_warn : m_fg;
      EnsureLabel(N("HUD_TIER"), m_hudCorner, rx, ry + row * m_lineHeight,
                   tierLine, tcol);
      row++;

      // Trinity bars — INFO display only. Color tinted by value but
      // NO "X" / "OK" gate marks. Components contribute, they don't gate.
      string lifeStr = StringFormat("life  %s %5.1f", GaugeBar(s.life), s.life);
      string stabStr = StringFormat("stab  %s %5.1f", GaugeBar(s.stability), s.stability);
      string confStr = StringFormat("conf  %s %5.1f", GaugeBar(s.confidence), s.confidence);
      EnsureLabel(N("HUD_LIFE"), m_hudCorner, rx, ry + row * m_lineHeight,
                   lifeStr, s.life >= 60 ? m_bull : s.life >= 35 ? m_warn : m_bear);
      row++;
      EnsureLabel(N("HUD_STAB"), m_hudCorner, rx, ry + row * m_lineHeight,
                   stabStr, s.stability >= 60 ? m_bull : s.stability >= 35 ? m_warn : m_bear);
      row++;
      EnsureLabel(N("HUD_CONF"), m_hudCorner, rx, ry + row * m_lineHeight,
                   confStr, s.confidence >= 55 ? m_bull : s.confidence >= 30 ? m_warn : m_bear);
      row++;

      // Narrative components — pure display, no gates. Each row is a
      // contributor with its own bar. Shown as a single block.
      double naScore = s.supporting.alignment;
      string naLine = StringFormat("Narrative      %s %5.1f", GaugeBar(naScore), naScore);
      EnsureLabel(N("HUD_NA"), m_hudCorner, rx, ry + row * m_lineHeight,
                   naLine, naScore >= 60 ? m_bull : naScore >= 35 ? m_warn : m_bear);
      row++;
      WriteValueLine(N("HUD_C_OWN"), rx, ry, row, "  Ownership      ", story.naComp.ownership);    row++;
      WriteValueLine(N("HUD_C_CMP"), rx, ry, row, "  Compression    ", story.naComp.compression);  row++;
      WriteValueLine(N("HUD_C_FRC"), rx, ry, row, "  Force          ", story.naComp.force);        row++;
      WriteValueLine(N("HUD_C_CHN"), rx, ry, row, "  Chain Vitality ", story.naComp.chain);        row++;
      WriteValueLine(N("HUD_C_PAR"), rx, ry, row, "  Parent Health  ", story.naComp.parent);       row++;
      WriteValueLine(N("HUD_C_PRG"), rx, ry, row, "  Progression    ", story.naComp.progression);  row++;
      WriteValueLine(N("HUD_C_XFR"), rx, ry, row, "  Transfer Risk  ", story.naComp.transfer);     row++;
      string ctxt = StringFormat("  Contradiction  %5.1f", story.naComp.contradiction);
      EnsureLabel(N("HUD_C_CON"), m_hudCorner, rx, ry + row * m_lineHeight,
                   ctxt, story.naComp.contradiction <= 20.0 ? m_bull :
                          story.naComp.contradiction <= 40.0 ? m_warn : m_bear);
      row++;

      // Probability cloud — the EV input
      string probLine = StringFormat("p(cont/term/trans) %3.0f / %3.0f / %3.0f",
                                      s.supporting.pContinuation,
                                      s.supporting.pTerminal,
                                      s.supporting.pTransfer);
      EnsureLabel(N("HUD_PROB"), m_hudCorner, rx, ry + row * m_lineHeight,
                   probLine, m_dim);
      row++;

      // Owner curve
      int oidx = curve.tree.ownerIndex;
      int oDir = (oidx >= 0) ? curve.tree.tree[oidx].dir : 0;
      double oNrg = (oidx >= 0) ? curve.tree.tree[oidx].energy : 0.0;
      string oState = (oidx >= 0) ? curve.tree.tree[oidx].state : "—";
      int oDepth   = (oidx >= 0) ? curve.tree.tree[oidx].depth : 0;
      string ownLine = StringFormat("owner %s  d%d  e%4.1f  %s",
                                     DirArrow(oDir), oDepth, oNrg, oState);
      EnsureLabel(N("HUD_OWNER"), m_hudCorner, rx, ry + row * m_lineHeight,
                   ownLine, DirColor(oDir));
      row++;

      // Verdict (last decision) + reason
      string verdict = OmegaStr::DecisionToString(lastDec);
      color vcol = (lastDec == OMEGA_DEC_ENTER_LONG || lastDec == OMEGA_DEC_ENTER_SHORT
                     || lastDec == OMEGA_DEC_ADD || lastDec == OMEGA_DEC_REVERSE) ? m_bull
                  : (lastDec == OMEGA_DEC_EXIT || lastDec == OMEGA_DEC_REDUCE) ? m_warn
                  : m_dim;
      string vline = "verdict " + verdict + "  ·  " + OmegaStr::ReasonToString(lastReason);
      EnsureLabel(N("HUD_VERD"), m_hudCorner, rx, ry + row * m_lineHeight,
                   vline, vcol);
      row++;

      // Story label
      string storyLine = "story  " + story.crossTfStory;
      EnsureLabel(N("HUD_STORY"), m_hudCorner, rx, ry + row * m_lineHeight,
                   storyLine, m_dim);
      row++;

      // Catastrophic-only veto line. ONLY shows if a catastrophic
      // condition is active — never blocked by component thresholds.
      // "Catastrophic" = capital state SUSPENDED, funded mode trip,
      // portfolio cap exceeded. Component scores never appear here.
      bool   primed = s.primed;
      string vetoLine;
      color  vetoCol;
      if(!primed)        { vetoLine = "WARMUP — perception not primed yet"; vetoCol = m_warn; }
      else               { vetoLine = "ORGANISM SPEAKING — risk decides loudness"; vetoCol = m_bull; }
      EnsureLabel(N("HUD_VETO"), m_hudCorner, rx, ry + row * m_lineHeight,
                   vetoLine, vetoCol);
      row++;
     }

   //--- Helper for component VALUE rows (never pass/fail).
   void WriteValueLine(string name, int rx, int ry, int row, string label, double value)
     {
      string s = StringFormat("%s%s %5.1f", label, GaugeBar(value), value);
      color c = (value >= 65) ? m_bull : (value >= 35) ? m_warn : m_bear;
      EnsureLabel(name, m_hudCorner, rx, ry + row * m_lineHeight, s, c);
     }

   //--- Helper for narrative-component rows. Pass/fail at >=50.
   //    KEPT for backwards-compat with any caller; new HUD uses
   //    WriteValueLine instead so values display without OK/X.
   void WriteComponent(string name, int rx, int ry, int row, string label, double value)
     {
      bool ok = (value >= 50.0);
      string s = StringFormat("%s%5.1f  %s", label, value, ok ? "OK" : "X");
      EnsureLabel(name, m_hudCorner, rx, ry + row * m_lineHeight,
                   s, ok ? m_bull : m_bear);
     }

   //=== MTF Map =====================================================
   void UpdateMTFMap(OmegaCurve &curve)
     {
      int rows = 8;
      int W = m_mtfWidth;
      int H = m_lineHeight * rows + 14;
      int X = m_mtfX;
      int Y = m_mtfY;
      EnsureRectLabel(N("MTF_BG"), m_mtfCorner, X, Y, W, H, m_bg, m_dim);

      int row = 0;
      int rx = X + 8;
      int ry = Y + 8;

      EnsureLabel(N("MTF_TITLE"), m_mtfCorner, rx, ry + row * m_lineHeight,
                   "MTF CURVE MAP", m_fg, 10, "Consolas");
      row++;

      // Per-TF row helper. CurveState exposes its direction via .currentDir
      // and the emergent state via .narrative or similar — we use the
      // public Snapshot() string fallback if needed.
      WriteTFRow(N("MTF_M1"),  curve.tfM1,  "M1",  rx, ry, row); row++;
      WriteTFRow(N("MTF_M5"),  curve.tfM5,  "M5",  rx, ry, row); row++;
      WriteTFRow(N("MTF_M15"), curve.tfM15, "M15", rx, ry, row); row++;
      WriteTFRow(N("MTF_H1"),  curve.tfH1,  "H1",  rx, ry, row); row++;
      WriteTFRow(N("MTF_H4"),  curve.tfH4,  "H4",  rx, ry, row); row++;

      // Alignment summary
      int a = AlignmentCount(curve);
      string al = StringFormat("aligned %d / 5", a);
      color  ac = (a >= 4) ? m_bull : (a <= 2) ? m_bear : m_warn;
      EnsureLabel(N("MTF_ALIGN"), m_mtfCorner, rx, ry + row * m_lineHeight,
                   al, ac);
     }

   void WriteTFRow(string name, CurveState &tf, string lbl, int rx, int ry, int row)
     {
      int d = tf.dir;
      // Inline emergent state name from CurveState's composite scores.
      string ph;
      if(!tf.ready)                         ph = "warmup";
      else if(tf.compIdx     >= 60.0)       ph = "compress";
      else if(tf.absScore    >= 60.0)       ph = "absorb";
      else if(tf.expScore    >= 60.0)       ph = "expand";
      else if(tf.convScore   >= 60.0)       ph = "convex";
      else if(tf.waveProgress >= 75.0)      ph = "mature";
      else                                  ph = "forming";
      string s = StringFormat("%-3s %s  %s", lbl, DirArrow(d), ph);
      EnsureLabel(name, m_mtfCorner, rx, ry + row * m_lineHeight,
                   s, DirColor(d));
     }

   int AlignmentCount(OmegaCurve &curve)
     {
      // Count TFs whose direction matches the chart-TF direction.
      CurveState *chart = curve.ChartTfState();
      if(chart == NULL) return 0;
      int ref = chart.dir;
      if(ref == 0) return 0;
      int n = 0;
      if(curve.tfM1.dir  == ref) n++;
      if(curve.tfM5.dir  == ref) n++;
      if(curve.tfM15.dir == ref) n++;
      if(curve.tfH1.dir  == ref) n++;
      if(curve.tfH4.dir  == ref) n++;
      return n;
     }

   //=== Owner curve box =============================================
   void UpdateOwnerBox(OmegaCurve &curve)
     {
      int oidx = curve.tree.ownerIndex;
      string name = N("OWNERBOX");
      string lblName = N("OWNERLBL");
      if(oidx < 0)
        {
         if(ObjectFind(0, name)    >= 0) ObjectDelete(0, name);
         if(ObjectFind(0, lblName) >= 0) ObjectDelete(0, lblName);
         return;
        }
      CurveNode owner = curve.tree.tree[oidx];
      if(!owner.alive || owner.origin <= 0 || owner.extreme <= 0) return;

      datetime t1 = (owner.birthTime > 0) ? owner.birthTime : TimeCurrent() - 3600 * 24;
      datetime t2 = TimeCurrent();
      double hi = MathMax(owner.origin, owner.extreme);
      double lo = MathMin(owner.origin, owner.extreme);
      color  c  = (owner.dir == 1) ? m_bull : (owner.dir == -1) ? m_bear : m_dim;

      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, hi, t2, lo);
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
      ObjectSetDouble (0, name, OBJPROP_PRICE, 0, hi);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
      ObjectSetDouble (0, name, OBJPROP_PRICE, 1, lo);
      ObjectSetInteger(0, name, OBJPROP_COLOR, c);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, owner.depth > 0 ? 1 : 2);
      ObjectSetInteger(0, name, OBJPROP_STYLE, owner.depth > 0 ? STYLE_DASH : STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_FILL,  false);
      ObjectSetInteger(0, name, OBJPROP_BACK,  true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

      // Label at the extreme
      string txt = StringFormat("OWNER %s  %s  e%.1f",
                                  owner.dir == 1 ? "^" : "v",
                                  owner.state, owner.energy);
      if(ObjectFind(0, lblName) < 0)
         ObjectCreate(0, lblName, OBJ_TEXT, 0, t2, owner.extreme);
      ObjectSetInteger(0, lblName, OBJPROP_TIME, 0, t2);
      ObjectSetDouble (0, lblName, OBJPROP_PRICE, 0, owner.extreme);
      ObjectSetString (0, lblName, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, c);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 9);
      ObjectSetString (0, lblName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
     }

   //=== Flip Zone box ===============================================
   //   Use the chart-TF CurveState's ft/fb (flip zone top/bottom) —
   //   the structural pivot the wave defends. Right-extended so the
   //   trader sees the level price will react to.
   void UpdateFlipZone(OmegaCurve &curve)
     {
      string name = N("FLIPZONE");
      string lbl  = N("FLIPZONELBL");
      CurveState *cs = curve.ChartTfState();
      if(cs == NULL || cs.ft <= 0 || cs.fb <= 0)
        {
         if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
         if(ObjectFind(0, lbl)  >= 0) ObjectDelete(0, lbl);
         return;
        }
      datetime t1 = TimeCurrent() - PeriodSeconds(_Period) * 60;
      datetime t2 = TimeCurrent() + PeriodSeconds(_Period) * 12;
      double hi = MathMax(cs.ft, cs.fb);
      double lo = MathMin(cs.ft, cs.fb);
      color  c  = (cs.dir == 1) ? m_bull : (cs.dir == -1) ? m_bear : (color)0xC084FC;

      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, hi, t2, lo);
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
      ObjectSetDouble (0, name, OBJPROP_PRICE, 0, hi);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
      ObjectSetDouble (0, name, OBJPROP_PRICE, 1, lo);
      ObjectSetInteger(0, name, OBJPROP_COLOR, c);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

      if(ObjectFind(0, lbl) < 0)
         ObjectCreate(0, lbl, OBJ_TEXT, 0, t2, (hi + lo) / 2.0);
      ObjectSetInteger(0, lbl, OBJPROP_TIME, 0, t2);
      ObjectSetDouble (0, lbl, OBJPROP_PRICE, 0, (hi + lo) / 2.0);
      ObjectSetString (0, lbl, OBJPROP_TEXT, "FLIP ZONE");
      ObjectSetInteger(0, lbl, OBJPROP_COLOR, c);
      ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 8);
      ObjectSetString (0, lbl, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, lbl, OBJPROP_HIDDEN, true);
     }

   //=== Budget target ===============================================
   void UpdateBudgetTarget(OmegaCurve &curve)
     {
      int oidx = curve.tree.ownerIndex;
      string lineName = N("BUDGET_LINE");
      string lblName  = N("BUDGET_LBL");
      if(oidx < 0)
        {
         if(ObjectFind(0, lineName) >= 0) ObjectDelete(0, lineName);
         if(ObjectFind(0, lblName)  >= 0) ObjectDelete(0, lblName);
         return;
        }
      CurveNode owner = curve.tree.tree[oidx];
      if(!owner.alive || owner.extreme <= 0) return;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0) return;

      datetime t1 = TimeCurrent();
      datetime t2 = t1 + PeriodSeconds(_Period) * 12;
      color  c  = (owner.dir == 1) ? m_warn : (owner.dir == -1) ? m_bear : m_dim;

      if(ObjectFind(0, lineName) < 0)
         ObjectCreate(0, lineName, OBJ_TREND, 0, t1, bid, t2, owner.extreme);
      ObjectSetInteger(0, lineName, OBJPROP_TIME, 0, t1);
      ObjectSetDouble (0, lineName, OBJPROP_PRICE, 0, bid);
      ObjectSetInteger(0, lineName, OBJPROP_TIME, 1, t2);
      ObjectSetDouble (0, lineName, OBJPROP_PRICE, 1, owner.extreme);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, c);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, true);

      string txt = StringFormat(">> BUDGET TGT  %.5f  d%d/%d",
                                  owner.extreme, owner.depth, 4);
      if(ObjectFind(0, lblName) < 0)
         ObjectCreate(0, lblName, OBJ_TEXT, 0, t2, owner.extreme);
      ObjectSetInteger(0, lblName, OBJPROP_TIME, 0, t2);
      ObjectSetDouble (0, lblName, OBJPROP_PRICE, 0, owner.extreme);
      ObjectSetString (0, lblName, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, c);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 9);
      ObjectSetString (0, lblName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
     }

   //=== FU spike marks ==============================================
   //   Wick-fraction detector identical to the Pine indicator's f_fuPool
   //   shape — runs on chart bars, marks with up/down arrow + barcolor.
   void UpdateFUMarks()
     {
      // Only mark the most-recent confirmed bar to keep object count low.
      // (The chart accumulates one mark per FU bar over time as bars close.)
      MqlRates r[];
      ArraySetAsSeries(r, true);
      if(CopyRates(_Symbol, _Period, 0, MathMax(m_fuLookback + 2, 6), r) <= 0) return;
      // r[0] = forming bar, r[1] = last closed bar
      if(ArraySize(r) < 2) return;
      MqlRates b = r[1];

      double rng = MathMax(b.high - b.low, _Point);
      double upperW = (b.high - MathMax(b.open, b.close)) / rng;
      double lowerW = (MathMin(b.open, b.close) - b.low)  / rng;

      // Highest/lowest among the prior lookback bars (excluding b itself)
      double pHi = 0, pLo = 0;
      bool   pOk = false;
      if(ArraySize(r) >= 2 + m_fuLookback)
        {
         pHi = r[2].high;
         pLo = r[2].low;
         for(int i = 3; i < 2 + m_fuLookback && i < ArraySize(r); i++)
           {
            if(r[i].high > pHi) pHi = r[i].high;
            if(r[i].low  < pLo) pLo = r[i].low;
           }
         pOk = true;
        }

      bool bear = (upperW >= m_fuWickFrac) && pOk &&
                  ((b.high >= pHi && b.close < pHi) || (b.close < b.open && b.high >= pHi));
      bool bull = (lowerW >= m_fuWickFrac) && pOk &&
                  ((b.low  <= pLo && b.close > pLo) || (b.close > b.open && b.low  <= pLo));
      if(!bear && !bull) return;

      string id = N("FU_" + IntegerToString((int)b.time));
      if(ObjectFind(0, id) >= 0) return;  // already marked

      ObjectCreate(0, id, OBJ_ARROW, 0, b.time, bull ? b.low : b.high);
      ObjectSetInteger(0, id, OBJPROP_ARROWCODE, bull ? 233 : 234);
      ObjectSetInteger(0, id, OBJPROP_COLOR, bull ? m_bull : m_warn);
      ObjectSetInteger(0, id, OBJPROP_ANCHOR, bull ? ANCHOR_TOP : ANCHOR_BOTTOM);
      ObjectSetInteger(0, id, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, id, OBJPROP_HIDDEN, true);
      ObjectSetString (0, id, OBJPROP_TOOLTIP, bull ? "FU bull" : "FU bear");
     }
  };

#endif // __OMEGA_CHART_MQH__

//-- Phase 5.5: chart instance is a single global (declared early so any
//   class method below can reference it). Init/Update/Deinit are wired
//   from the EA lifecycle handlers.
OmegaChart g_chart;
//-- Phase 5.5: track last decision so the HUD can show what the engine just did
ENUM_OMEGA_DECISION g_lastDecision = OMEGA_DEC_OBSERVE;
ENUM_OMEGA_REASON   g_lastReason   = REASON_PHASE_NOT_BUILT;
//==================================================================
//= MODULE: Position/PositionHealth
//= Source: Include/Position/PositionHealth.mqh
//==================================================================
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

//==================================================================
//= MODULE: Position/CampaignPositions
//= Source: Include/Position/CampaignPositions.mqh
//==================================================================
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
   //  Phase 5.6: continuous-allocation entry. The decision engine has
   //  already emitted a conviction + EV. Risk turns those into a
   //  conviction-driven size. Catastrophic vetoes (margin, opt-in
   //  MICRO, broker-min undersized) still apply — those are physics
   //  and broker rules, not component thresholds. There is no "tier
   //  conviction floor" skip here anymore.
   ulong Open(int direction, ENUM_POSITION_ROLE role,
              double stopDistPoints, long campaignId,
              ENUM_OMEGA_REASON reason, string detail,
              const OmegaState &state,
              double conviction = -1.0,    // Phase 5.6 — pass through from DecisionEngine
              double evMult     = 1.0)
     {
      if(m_trade == NULL || m_risk == NULL || m_capital == NULL)
        {
         OmegaLogger::LogException("POSITIONS", -1, "Open: dependencies not wired");
         return 0;
        }
      ENUM_OMEGA_TIER tier = m_risk.TierForCap(m_capital);
      double effEquity = m_risk.EffectiveEquity(m_capital);

      //--- Pyramid budget gate (catastrophic — tier-bounded, not a
      //    component veto). Refuses to add when same-side count hit.
      int sideCount = CountActive(direction);
      int tierBudget = m_risk.TierMaxBudget(tier);
      if(sideCount >= tierBudget)
        {
         OmegaLogger::LogWarning("POSITIONS",
            StringFormat("%s · pyramid budget exhausted · tier=%s · open=%d / max=%d",
                          m_symbol, m_risk.TierStr(tier), sideCount, tierBudget));
         return 0;
        }

      //--- Phase 5.6 — conviction-driven sizing. If the caller didn't
      //    pass an explicit conviction (legacy path), Risk derives a
      //    proxy from the trinity + narrative alignment. Either way
      //    NO component value can return 0 alone.
      double riskPct;
      if(conviction >= 0.0)
         riskPct = m_risk.RiskPctFromConviction(conviction, evMult, tier);
      else
         riskPct = m_risk.RiskPctFor(state, tier);

      if(riskPct <= 0.0)
        {
         //   Only catastrophic conditions reach here (MICRO opt-out,
         //   tier cap zero, etc.). Log and return.
         OmegaLogger::LogWarning("POSITIONS",
            StringFormat("%s · skipped (catastrophic) · tier=%s conv=%.0f EV=%.2f → riskPct=0.0",
                          m_symbol, m_risk.TierStr(tier), conviction, evMult));
         return 0;
        }
      //--- Apply per-tier ATR floor to the stop BEFORE sizing & SL placement.
      double rawStop = stopDistPoints;
      stopDistPoints = m_risk.ResolveStopPoints(m_symbol, stopDistPoints, tier);
      double lots    = m_risk.LotsFor(m_symbol, riskPct, stopDistPoints, m_capital);
      if(lots <= 0)
        {
         OmegaLogger::LogWarning("POSITIONS",
            StringFormat("%s · zero lots · tier=%s risk=%.2f%% sd=%.0f (raw %.0f)",
                          m_symbol, m_risk.TierStr(tier), riskPct, stopDistPoints, rawStop));
         return 0;
        }

      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double askPx = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bidPx = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double openPx = (direction == 1) ? askPx : bidPx;
      double slDist = stopDistPoints * point;
      double sl     = (direction == 1) ? (openPx - slDist) : (openPx + slDist);

      //--- Actual-vs-intended risk after broker rounding.
      double actualPct = m_risk.CalcActualRiskPct(m_symbol, lots, stopDistPoints, effEquity);
      bool   oversized = (actualPct > riskPct + 0.01);
      if(oversized && !m_risk.ResolveUndersized(tier, riskPct, actualPct))
        {
         OmegaLogger::LogWarning("POSITIONS",
            StringFormat("%s · skipped (broker-min over-risk) · tier=%s · actual %.2f%% > intended %.2f%% (undersized=%s)",
                          m_symbol, m_risk.TierStr(tier),
                          actualPct, riskPct,
                          m_risk.UndersizedStr(m_risk.UndersizedBehavior())));
         return 0;
        }

      //--- Catastrophic: pre-trade margin precheck.
      if(!m_risk.PassesMarginCheck(m_symbol, direction, lots, openPx))
        {
         OmegaLogger::LogWarning("POSITIONS",
            StringFormat("%s · skipped (margin) · lots=%.2f openPx=%.5f", m_symbol, lots, openPx));
         return 0;
        }

      //--- Enriched comment showing the continuous decision parameters.
      string tierTag = StringFormat("[%s conv=%.0f EV=%.2f int=%.2f%% act=%.2f%%%s]",
                                     m_risk.TierStr(tier),
                                     conviction >= 0 ? conviction : -1.0, evMult,
                                     riskPct, actualPct,
                                     oversized ? " forced" : "");
      string fullDetail = (StringLen(detail) > 0) ? (tierTag + " " + detail) : tierTag;

      ulong tk = (direction == 1)
         ? m_trade.Buy(m_symbol, lots, sl, 0.0, reason, fullDetail)
         : m_trade.Sell(m_symbol, lots, sl, 0.0, reason, fullDetail);
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
         StringFormat("OPEN · %s · tier=%s int=%.2f%% act=%.2f%%%s lots=%.2f sd=%.0f · %s",
                       PositionRoleStr::ToString(role), m_risk.TierStr(tier),
                       riskPct, actualPct, oversized ? " forced" : "",
                       lots, stopDistPoints, m_pos[slot].Snapshot()));
      //--- Phase 5.5: notify the chart layer so it drops a marker arrow
      //    at the entry bar with tier + actual-vs-intended risk in the tooltip.
      g_chart.OnPositionOpen(m_symbol, tk, direction, openPx, sl,
                              tier, riskPct, actualPct, lots, fullDetail);
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

//==================================================================
//= MODULE: Position/DecisionEngine
//= Source: Include/Position/DecisionEngine.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                              DecisionEngine.mqh  |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 13/15 — the engine where Trinity becomes ACTION.         |
//|                                                                  |
//|   Pure function. Reads the Trinity, the curve+tree, the story,   |
//|   and the current campaign positions. Emits a single decision    |
//|   plus the reason code, role, direction, and stop distance.      |
//|                                                                  |
//|   Decisions are CONSEQUENCES of state, not signals. The truth    |
//|   table:                                                         |
//|                                                                  |
//|     not primed                              → OBSERVE             |
//|     life ≤ 32 (DEAD)  & holding same dir    → EXIT                |
//|     life ≤ 32         & confidence ≥ 50     → REVERSE (counter)   |
//|     life ≤ 32         & owner != held       → OBSERVE             |
//|     life weakening    & holding profitably  → REDUCE              |
//|     life weakening    & holding             → HOLD                |
//|     life holding      & no position         → ENTER (normal risk) |
//|     life alive        & no position         → ENTER (origin role) |
//|     life alive        & progressing & budget→ ADD   (progress role)|
//|     life alive        & at full budget      → HOLD                |
//|                                                                  |
//|   Origin entries require min trinity AND alignment ≥ 4/6.        |
//|   Progress adds require progressing + same dir.                  |
//|   Reversal requires confidence ≥ 50 AND owner direction defined. |
//+------------------------------------------------------------------+
#ifndef __OMEGA_DECISION_ENGINE_MQH__
#define __OMEGA_DECISION_ENGINE_MQH__


//=== Decision result ================================================
struct DecisionResult
  {
   ENUM_OMEGA_DECISION decision;
   ENUM_OMEGA_REASON   reason;
   ENUM_POSITION_ROLE  suggestedRole;
   int                 suggestedDirection;
   double              stopDistPoints;
   string              detail;
   //--- Phase 5.6: continuous-allocation outputs (organism speaks).
   //    The decision engine NEVER gates on component thresholds; it
   //    emits a conviction (0..100) and an expected-value multiplier.
   //    Risk converts these into a continuous size in % equity.
   double              conviction;     // 0..100 weighted blend of all signals
   double              evWith;         // EV multiplier for owner-direction entry
   double              evCounter;      // EV multiplier for counter-direction entry
   double              pCont;          // probability cloud snapshot
   double              pTrans;
   double              pTerm;

                     DecisionResult()
     {
      decision           = OMEGA_DEC_OBSERVE;
      reason             = REASON_PHASE_NOT_BUILT;
      suggestedRole      = POS_ENTRY;
      suggestedDirection = 0;
      stopDistPoints     = 0;
      detail             = "";
      conviction         = 0.0;
      evWith             = 1.0;
      evCounter          = 1.0;
      pCont = pTrans = pTerm = 0.0;
     }
  };

//=== Tunables (sane defaults; later phases tune from CampaignDB) ===
struct DecisionParams
  {
   double  enterMinLife;      // 45 — life threshold to enter
   double  enterMinStability; // 45
   double  enterMinConf;      // 40
   double  attackMinLife;     // 60 — life threshold for ALIVE entries
   double  attackMinStab;     // 60
   double  attackMinConf;     // 55
   double  reverseMinConf;    // 50 — confidence to flip on dead
   int     enterMinAlign;     // legacy — TF-count threshold for HUD info row only
   double  narrAlignMin;      // 65 — narrative coherence floor (canonical gate)
   int     maxBudget;         // 4 — max positions per campaign
   double  defaultSlAtrMult;  // 1.5 — fallback SL when no protective extreme
   double  reduceLifeFloor;   // 38 — life below this triggers REDUCE if profitable

                     DecisionParams()
     {
      enterMinLife = 45.0; enterMinStability = 45.0; enterMinConf = 40.0;
      attackMinLife = 60.0; attackMinStab = 60.0; attackMinConf = 55.0;
      reverseMinConf = 50.0;
      enterMinAlign = 4;
      narrAlignMin  = 65.0;
      maxBudget = 4;
      defaultSlAtrMult = 1.5;
      reduceLifeFloor = 38.0;
     }
  };

//=== The decision engine ===========================================
//
//  CANONICAL F72 RULE (Phase 5.6 — continuous allocation organism):
//
//    "No component except catastrophic risk management may veto a
//     trade. Components are CONTRIBUTORS, not gates."
//
//  Forbidden in here:
//
//      if(narrAlign  < 65) return HOLD;
//      if(stability  < 45) return HOLD;
//      if(confidence < 40) return HOLD;
//
//  Allowed only OUTSIDE this engine (in Capital / Funded / Portfolio /
//  PassesMarginCheck): kill switch, hard limit, margin unavailable,
//  market closed, news blackout, max risk exceeded.
//
//  This engine emits an ACTION + CONVICTION + EV. Risk converts the
//  three to a continuous size. A weak narrative produces a small
//  size, not a refusal. The organism never goes silent.
//
class DecisionEngine
  {
public:
   //--- Phase 5.6 — Continuous conviction (0..100) from all signals.
   //    Trinity contributes 60% (life 30, stab 15, conf 15). Narrative
   //    relationship components contribute 40% (ownership / compression
   //    / force / chain / parent / progression / transfer, equally
   //    weighted at ~5.7% each = 40% sum). Contradiction subtracts.
   //    Components are CONTRIBUTORS — none of them can return 0 alone.
   static double ComputeConviction(const OmegaState &state,
                                    const NarrativeAlignment::Components &naComp)
     {
      double trinity = state.life       * 0.30
                     + state.stability  * 0.15
                     + state.confidence * 0.15;       // 60% weight
      double rel = (naComp.ownership   + naComp.compression + naComp.force
                  + naComp.chain       + naComp.parent      + naComp.progression
                  + naComp.transfer) * (0.40 / 7.0);  // 40% weight, equal sub-weights
      double conv = trinity + rel - naComp.contradiction;
      return MathMax(0.0, MathMin(100.0, conv));
     }

   //--- Phase 5.6 — EV multiplier from probability cloud.
   //    Range [0..2]. EV > 1 means continuation favoured; EV < 1 means
   //    terminal more likely. For owner-direction: pCont positive,
   //    pTerm negative. For counter-direction: pTrans positive,
   //    pCont negative. If probability cloud isn't yet primed
   //    (Phase 6 not active), returns 1.0 (neutral).
   static double ComputeEV(const OmegaState &state, int candidateDir, int ownerDir)
     {
      double pCont  = state.supporting.pContinuation;
      double pTrans = state.supporting.pTransfer;
      double pTerm  = state.supporting.pTerminal;
      if(pCont + pTrans + pTerm < 5.0) return 1.0;     // cloud not primed
      double ev;
      if(candidateDir == ownerDir)
         ev = (pCont * 1.0 + pTrans * 0.3 - pTerm * 0.5) / 100.0;
      else
         ev = (pTrans * 0.8 + pTerm * 0.5 - pCont * 0.4) / 100.0;
      return MathMax(0.0, MathMin(2.0, 1.0 + ev));
     }

   //--- Compute stop distance in POINTS from chart-TF curve state.
   //    Prefers the protective extreme (owner curve origin) if available,
   //    else falls back to ATR multiple. Returns 0 if no valid stop.
   static double ComputeStopDistPoints(string sym, OmegaCurve &curve, int direction,
                                        const DecisionParams &p)
     {
      CurveState *chart = curve.ChartTfState();
      if(chart == NULL) return 0.0;
      double atr   = chart.physics.atr;
      double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      if(atr <= 0 || point <= 0) return 0.0;

      double bar1Close = iClose(sym, chart.tf, 0);
      if(bar1Close <= 0) bar1Close = iClose(sym, chart.tf, 1);

      //-- prefer owner curve origin
      int idx = curve.tree.ownerIndex;
      if(idx >= 0)
        {
         double protectivePx = curve.tree.tree[idx].origin;
         if(protectivePx > 0 && curve.tree.tree[idx].dir == direction)
           {
            double dist = MathAbs(bar1Close - protectivePx);
            //-- pad by ~0.3*ATR so we don't sit on the level
            dist += atr * 0.3;
            if(dist > 0) return dist / point;
           }
        }
      //-- fallback: ATR * multiplier
      return (atr * p.defaultSlAtrMult) / point;
     }

   //--- Phase 5.6 — Continuous-allocation decision dispatcher.
   //
   //  Returns: action (ENTER/HOLD/ADD/REVERSE/REDUCE/EXIT/OBSERVE)
   //         + conviction (0..100, continuous)
   //         + evWith / evCounter (probability-cloud multipliers)
   //
   //  Sizing happens in Risk::RiskPctFromConviction(conviction, evWith, tier).
   //  Catastrophic vetoes happen elsewhere (Capital state SUSPENDED,
   //  margin precheck, funded mode trip, portfolio cap). NEVER here.
   //
   //  The only "soft floor" left in this engine is a noise floor at
   //  conviction × EV < 15 — below that score the engine doesn't
   //  even compute a meaningful direction; emits OBSERVE and waits.
   //  This is NOT a component veto — it's the engine refusing to act
   //  on pure noise. Any single-component value can be 0 and still
   //  produce an entry IF the rest of the signals are strong.
   //
   static DecisionResult Decide(const OmegaState &state,
                                 OmegaCurve &curve,
                                 const OmegaStory &story,
                                 int activeSameDirCount,
                                 int activeCounterCount,
                                 const DecisionParams &p)
     {
      DecisionResult r;
      int ownerDir = curve.tree.ownerDir;
      r.suggestedDirection = ownerDir;
      r.pCont      = state.supporting.pContinuation;
      r.pTrans     = state.supporting.pTransfer;
      r.pTerm      = state.supporting.pTerminal;
      r.conviction = ComputeConviction(state, story.naComp);
      r.evWith     = (ownerDir != 0) ? ComputeEV(state, ownerDir,  ownerDir) : 1.0;
      r.evCounter  = (ownerDir != 0) ? ComputeEV(state, -ownerDir, ownerDir) : 1.0;

      //=== FORCE-FALLBACK during warmup ============================
      //   Perception not primed OR no curve owner → simple bar-bias
      //   so the engine still trades during the first ~10 bars.
      if(!state.primed || ownerDir == 0)
        {
         double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
         double close5 = iClose(_Symbol, PERIOD_CURRENT, 5);
         if(close1 > 0 && close5 > 0 && activeSameDirCount + activeCounterCount == 0)
           {
            int bias = (close1 > close5) ? 1 : (close1 < close5 ? -1 : 0);
            if(bias != 0)
              {
               r.decision           = (bias == 1) ? OMEGA_DEC_ENTER_LONG : OMEGA_DEC_ENTER_SHORT;
               r.suggestedDirection = bias;
               r.suggestedRole      = POS_ORIGIN;
               r.reason             = REASON_HEARTBEAT;
               r.conviction         = 25.0;     // small conviction → small size
               r.evWith             = 1.0;
               r.detail             = StringFormat("force-fallback · primed=%s ownerDir=%d bias=%d",
                                                   state.primed ? "Y" : "N", ownerDir, bias);
               return r;
              }
           }
         r.decision = OMEGA_DEC_OBSERVE;
         r.reason   = state.primed ? REASON_OWNERSHIP_LEAKING : REASON_PHASE_NOT_BUILT;
         r.detail   = "warmup · waiting for owner curve to take wheel";
         return r;
        }

      ENUM_LIFE_VERDICT verdict = LifeScore::Verdict(state.life);

      //--- DEAD: existing campaign collapsed =======================
      if(verdict == LIFE_DEAD)
        {
         if(activeSameDirCount > 0)
           {
            r.decision = OMEGA_DEC_EXIT;
            r.reason   = REASON_LIFE_DEAD;
            r.detail   = StringFormat("life %.1f dead · exit %d position(s)",
                                       state.life, activeSameDirCount);
            return r;
           }
         //   Counter-side opportunity: continuous conv × counter-EV.
         //   No "confidence >= 50" gate. Conviction × EV produces a score;
         //   below the noise floor we WAIT (not BLOCK).
         if(activeCounterCount == 0)
           {
            double counterScore = MathMin(100.0, r.conviction * r.evCounter);
            if(counterScore > 25.0)
              {
               r.decision           = OMEGA_DEC_REVERSE;
               r.reason             = REASON_OWNERSHIP_TRANSFER;
               r.suggestedDirection = -ownerDir;
               r.suggestedRole      = POS_ORIGIN;
               r.conviction         = r.conviction;     // explicit
               r.detail             = StringFormat("flip · counter-EV %.2f × conv %.0f = %.0f",
                                                   r.evCounter, r.conviction, counterScore);
               return r;
              }
           }
         r.decision = OMEGA_DEC_OBSERVE;
         r.reason   = REASON_LIFE_DEAD;
         r.detail   = StringFormat("dead · counter-EV %.2f × conv %.0f insufficient",
                                    r.evCounter, r.conviction);
         return r;
        }

      //--- WEAKENING ===============================================
      if(verdict == LIFE_WEAKENING)
        {
         if(activeSameDirCount > 0 && state.life < p.reduceLifeFloor && !story.progressing)
           {
            r.decision = OMEGA_DEC_REDUCE;
            r.reason   = REASON_LIFE_WEAKENING;
            r.detail   = StringFormat("life %.1f weakening · reduce", state.life);
            return r;
           }
         if(activeSameDirCount > 0)
           {
            r.decision = OMEGA_DEC_HOLD;
            r.reason   = REASON_LIFE_WEAKENING;
            r.detail   = StringFormat("life %.1f weakening · hold", state.life);
            return r;
           }
         //   No position. Do not enter into weakening — but produce
         //   OBSERVE with explicit conviction × EV so the user sees why,
         //   not a "BLOCKED" gate label.
         r.decision = OMEGA_DEC_OBSERVE;
         r.reason   = REASON_LIFE_WEAKENING;
         r.detail   = StringFormat("weakening · conv %.0f × EV %.2f insufficient for fresh entry",
                                    r.conviction, r.evWith);
         return r;
        }

      //--- HOLDING / ALIVE — CONTINUOUS ALLOCATION ================
      //  The organism speaks. Conviction × EV drives action and size.
      //  Component-level vetoes are forbidden here — the only filter
      //  is a noise floor that prevents firing on essentially-random
      //  state combinations.
      if(activeSameDirCount == 0)
        {
         double score = MathMin(100.0, r.conviction * r.evWith);
         if(score < 15.0)
           {
            r.decision = OMEGA_DEC_OBSERVE;
            r.reason   = REASON_LIFE_HEALTHY;
            r.detail   = StringFormat("conv %.0f × EV %.2f = %.0f below noise floor — wait",
                                      r.conviction, r.evWith, score);
            return r;
           }
         r.decision = (ownerDir == 1) ? OMEGA_DEC_ENTER_LONG : OMEGA_DEC_ENTER_SHORT;
         r.reason   = REASON_HEALTHY_CONTINUATION;
         r.suggestedRole = POS_ORIGIN;
         r.detail = StringFormat("ENTER · %s · conv %.0f × EV %.2f = %.0f",
                                 verdict == LIFE_ALIVE ? "ALIVE" : "HOLDING",
                                 r.conviction, r.evWith, score);
         return r;
        }

      //--- pyramiding — same continuous model =====================
      int totalSameDir = activeSameDirCount;
      if(totalSameDir < p.maxBudget && story.progressing)
        {
         double addScore = MathMin(100.0, r.conviction * r.evWith);
         //   Adds need slightly higher score than first entries to
         //   prevent compounding weak setups. Still continuous, never
         //   a component veto.
         if(addScore >= 25.0)
           {
            r.decision      = OMEGA_DEC_ADD;
            r.reason        = REASON_HEALTHY_CONTINUATION;
            r.suggestedRole = POS_PROGRESS;
            r.detail        = StringFormat("ADD %d/%d · conv %.0f × EV %.2f = %.0f",
                                            totalSameDir + 1, p.maxBudget,
                                            r.conviction, r.evWith, addScore);
            return r;
           }
        }
      r.decision = OMEGA_DEC_HOLD;
      r.reason   = REASON_LIFE_HEALTHY;
      r.detail   = (totalSameDir >= p.maxBudget)
                     ? "at budget · hold"
                     : StringFormat("progressing pending · conv %.0f × EV %.2f insufficient for add",
                                    r.conviction, r.evWith);
      return r;
     }
  };

#endif // __OMEGA_DECISION_ENGINE_MQH__

//==================================================================
//= MODULE: Execution
//= Source: Include/Execution.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                    Execution.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer-15 surface. Receives a (decision, reason, state) triple, |
//|   gates it through Capital state, and routes it to the           |
//|   CampaignPositions manager for actual order plumbing.           |
//|                                                                  |
//|   Phase 5 wires real entries:                                    |
//|     ENTER_LONG / ENTER_SHORT / ADD  → CampaignPositions::Open    |
//|     EXIT                            → CampaignPositions::CloseAll|
//|     REVERSE                         → CloseAll(same)+Open(opp)   |
//|     REDUCE                          → ReduceOldest                |
//|     OBSERVE / HOLD                  → log only                   |
//|                                                                  |
//|   The Capital state machine still gates entries (RESTRICTED      |
//|   suppresses new entries; SUSPENDED suppresses everything).      |
//+------------------------------------------------------------------+
#ifndef __OMEGA_EXECUTION_MQH__
#define __OMEGA_EXECUTION_MQH__


class OmegaExecution
  {
private:
   OmegaPaperTrade     m_trade;
   OmegaCapital       *m_capital;
   OmegaRisk          *m_risk;
   CampaignDB         *m_db;
   CampaignPositions  *m_positions;

public:
                     OmegaExecution()
     {
      m_capital   = NULL;
      m_risk      = NULL;
      m_db        = NULL;
      m_positions = NULL;
     }

   void Init(ENUM_OMEGA_MODE mode, ulong magic,
             OmegaCapital *capital, OmegaRisk *risk, CampaignDB *db,
             CampaignPositions *positions = NULL)
     {
      m_trade.Init(mode, magic);
      m_capital   = capital;
      m_risk      = risk;
      m_db        = db;
      m_positions = positions;
      OmegaLogger::LogInfo("EXEC", "Initialized");
     }

   //--- Late-bind the position manager (avoids constructor circular dep)
   void SetPositions(CampaignPositions *positions) { m_positions = positions; }

   //--- expose the trade shell so CampaignPositions can share it
   OmegaPaperTrade* TradeShell() { return GetPointer(m_trade); }
   void SetMode(ENUM_OMEGA_MODE mode) { m_trade.SetMode(mode); }
   ENUM_OMEGA_MODE Mode() const       { return m_trade.Mode(); }

   //--- The single decision-handling entry point. Logs every decision,
   //    gates by capital state, then routes to CampaignPositions.
   //
   //    Phase 5.6: now accepts conviction + evMult from DecisionEngine
   //    so Risk can size the position continuously. Default values
   //    (-1, 1.0) preserve the legacy proxy-conviction path.
   void HandleDecision(string symbol, ENUM_OMEGA_DECISION dec, ENUM_OMEGA_REASON reason,
                        const OmegaState &state, double stopDistPts, string detail,
                        ENUM_POSITION_ROLE role = POS_ENTRY,
                        int suggestedDir = 0,
                        long campaignId = 0,
                        double conviction = -1.0,
                        double evMult     = 1.0)
     {
      OmegaLogger::LogDecision(symbol, m_trade.Mode(), dec, reason,
                                state.life, state.stability, state.confidence, detail);
      if(dec == OMEGA_DEC_OBSERVE || dec == OMEGA_DEC_HOLD) return;

      //--- Capital gate
      if(m_capital == NULL)
        {
         OmegaLogger::LogException("EXEC", -1, "Capital not wired");
         return;
        }
      ENUM_OMEGA_CAPITAL_STATE cs = m_capital.State();
      if(cs == CAPITAL_SUSPENDED)
        {
         OmegaLogger::LogDecision(symbol, m_trade.Mode(), OMEGA_DEC_OBSERVE,
                                   REASON_HARD_LIMIT,
                                   state.life, state.stability, state.confidence,
                                   "Capital SUSPENDED — decision suppressed");
         return;
        }
      bool isEntryDec = (dec == OMEGA_DEC_ENTER_LONG ||
                         dec == OMEGA_DEC_ENTER_SHORT ||
                         dec == OMEGA_DEC_ADD ||
                         dec == OMEGA_DEC_REVERSE);
      if(cs == CAPITAL_RESTRICTED && isEntryDec)
        {
         OmegaLogger::LogDecision(symbol, m_trade.Mode(), OMEGA_DEC_OBSERVE,
                                   REASON_DAILY_LIMIT,
                                   state.life, state.stability, state.confidence,
                                   "Capital RESTRICTED — entry suppressed (managing only)");
         return;
        }

      if(m_positions == NULL)
        {
         OmegaLogger::LogException("EXEC", -2, "Positions not wired");
         return;
        }
      if(stopDistPts <= 0 && isEntryDec)
        {
         OmegaLogger::LogWarning("EXEC",
            StringFormat("%s · %s · invalid stopDistPts %.0f — skipped",
                          symbol, OmegaStr::DecisionToString(dec), stopDistPts));
         return;
        }

      switch(dec)
        {
         case OMEGA_DEC_ENTER_LONG:
            m_positions.Open(+1, role, stopDistPts, campaignId, reason, detail, state, conviction, evMult);
            break;
         case OMEGA_DEC_ENTER_SHORT:
            m_positions.Open(-1, role, stopDistPts, campaignId, reason, detail, state, conviction, evMult);
            break;
         case OMEGA_DEC_ADD:
            if(suggestedDir == 0) suggestedDir = +1;
            m_positions.Open(suggestedDir, role, stopDistPts, campaignId, reason, detail, state, conviction, evMult);
            break;
         case OMEGA_DEC_REVERSE:
           {
            int oldDir = -suggestedDir;     // counter side currently held
            m_positions.CloseAll(oldDir, REASON_OWNERSHIP_TRANSFER,
                                  "REVERSE: closing prior side before flip");
            m_positions.Open(suggestedDir, POS_ORIGIN, stopDistPts, campaignId,
                              reason, "REVERSE: flipped to counter", state, conviction, evMult);
            break;
           }
         case OMEGA_DEC_EXIT:
            m_positions.CloseAll(suggestedDir, reason, detail);
            break;
         case OMEGA_DEC_REDUCE:
            if(suggestedDir == 0) suggestedDir = +1;
            m_positions.ReduceOldest(suggestedDir, reason, detail);
            break;
         case OMEGA_DEC_TRANSFER:
            //-- TRANSFER mirrors REVERSE today; Phase 6 will distinguish
            //   gradual hand-offs (transfer) from hard flips (reverse).
           {
            int oldDirT = -suggestedDir;
            m_positions.CloseAll(oldDirT, REASON_OWNERSHIP_TRANSFER, detail);
            m_positions.Open(suggestedDir, POS_ORIGIN, stopDistPts, campaignId,
                              reason, detail, state, conviction, evMult);
            break;
           }
         default:
            break;
        }
     }
  };

#endif // __OMEGA_EXECUTION_MQH__

//==================================================================
//= MODULE: Meta/Regime
//= Source: Include/Meta/Regime.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                       Regime.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 9 — regime detection.                                    |
//|                                                                  |
//|   What kind of session/day/regime are we in? Not from a clock,   |
//|   from STATE: alignment + force + narrative + chain.             |
//|                                                                  |
//|     EXPANSION_DAY  alignment ≥ 80 + force persisting + life ≥ 60 |
//|     TREND_DAY      alignment ≥ 65 + life ≥ 55                    |
//|     ROTATION_DAY   alignment ≤ 33  OR force leaking + chain weak |
//|     REVERSAL_DAY   transfer-recently OR narrative WEAKENING + dd |
//|     RANGE_DAY      everything else (low energy, inconclusive)    |
//|                                                                  |
//|   Score (0..100) is high for trending/clean, low for rotational. |
//|   Feeds OmegaSupporting.regime.                                  |
//+------------------------------------------------------------------+
#ifndef __OMEGA_META_REGIME_MQH__
#define __OMEGA_META_REGIME_MQH__


enum ENUM_OMEGA_REGIME
  {
   REGIME_RANGE_DAY     = 0,
   REGIME_TREND_DAY     = 1,
   REGIME_EXPANSION_DAY = 2,
   REGIME_ROTATION_DAY  = 3,
   REGIME_REVERSAL_DAY  = 4
  };

struct RegimeResult
  {
   ENUM_OMEGA_REGIME label;
   double            score;     // 0..100 — clean/trending high; messy low
   string            tag;
                     RegimeResult() { label = REGIME_RANGE_DAY; score = OMEGA_TRINITY_NEUTRAL; tag = "RANGE"; }
  };

class Regime
  {
public:
   static string LabelString(ENUM_OMEGA_REGIME r)
     {
      switch(r)
        {
         case REGIME_RANGE_DAY:     return "RANGE";
         case REGIME_TREND_DAY:     return "TREND";
         case REGIME_EXPANSION_DAY: return "EXPANSION";
         case REGIME_ROTATION_DAY:  return "ROTATION";
         case REGIME_REVERSAL_DAY:  return "REVERSAL";
        }
      return "?";
     }

   static RegimeResult Compute(const OmegaState &state, OmegaCurve &curve, const OmegaStory &story)
     {
      RegimeResult r;
      double align       = state.supporting.alignment;
      double life        = state.life;
      double force       = curve.gForce;
      bool   forceLeaking= (curve.gForceState == FORCE_LEAKING);
      bool   forcePersist= (curve.gForceState == FORCE_PERSISTING);
      double chain       = state.supporting.chainHealth;
      ENUM_NARRATIVE_STATE ns = story.narrative.State();
      bool   recentTransfer = (curve.tree.transfersCount > 0);  // Phase 6.1 — track time-windowed
      bool   narrWeakening = (ns == NARR_STATE_WEAKENING);

      //-- decision ladder
      if(align >= 80.0 && life >= 60.0 && forcePersist)
        {
         r.label = REGIME_EXPANSION_DAY;
         r.score = 80.0 + (life - 60.0) * 0.4;
        }
      else if(align >= 65.0 && life >= 55.0)
        {
         r.label = REGIME_TREND_DAY;
         r.score = 65.0 + (align - 65.0) * 0.3 + (life - 55.0) * 0.2;
        }
      else if(narrWeakening && (chain <= 40.0 || forceLeaking))
        {
         r.label = REGIME_REVERSAL_DAY;
         r.score = 35.0;
        }
      else if(align <= 33.0 || (forceLeaking && chain <= 45.0))
        {
         r.label = REGIME_ROTATION_DAY;
         r.score = 25.0;
        }
      else
        {
         r.label = REGIME_RANGE_DAY;
         r.score = 50.0;
        }
      r.score = OmegaMath::Clamp(r.score, 0.0, 100.0);
      r.tag   = LabelString(r.label);
      return r;
     }
  };

#endif // __OMEGA_META_REGIME_MQH__

//==================================================================
//= MODULE: Meta/Probability
//= Source: Include/Meta/Probability.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                  Probability.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 12 — Probability Clouds.                                 |
//|                                                                  |
//|   "Not one outcome. Many."                                       |
//|                                                                  |
//|   Updated every closed bar, normalised to sum 100:               |
//|     pContinuation — current curve persists                       |
//|     pTerminal     — current curve terminates (LIFE_DEAD soon)    |
//|     pTransfer     — ownership transfers to counter side          |
//|                                                                  |
//|   Logits are unnormalised scores; final cloud = logits / Σlogits.|
//|   Feeds OmegaSupporting.pContinuation/Terminal/Transfer.         |
//+------------------------------------------------------------------+
#ifndef __OMEGA_META_PROBABILITY_MQH__
#define __OMEGA_META_PROBABILITY_MQH__


struct ProbabilityCloud
  {
   double pContinuation;   // 0..100
   double pTerminal;       // 0..100
   double pTransfer;       // 0..100

                     ProbabilityCloud() { pContinuation = pTerminal = pTransfer = 0; }
  };

class Probability
  {
public:
   static ProbabilityCloud Compute(const OmegaState &state, OmegaCurve &curve, const OmegaStory &story)
     {
      ProbabilityCloud c;

      //--- continuation logit
      double lContinue = 10.0;
      lContinue += state.life * 0.6;                                 // life is the key driver
      if(story.narrative.State() == NARR_STATE_STRENGTHENING) lContinue += 25.0;
      if(state.supporting.alignment >= 66.0)                  lContinue += 20.0;
      if(curve.gForceState == FORCE_PERSISTING)               lContinue += 25.0;
      int budgetLeft = curve.tree.recursionBudget - curve.tree.treeDepth;
      if(budgetLeft > 0)                                      lContinue += budgetLeft * 8.0;
      if(story.progressing)                                   lContinue += 15.0;
      lContinue = OmegaMath::Clamp(lContinue, 0.0, 200.0);

      //--- terminal logit
      double lTerminal = 5.0;
      lTerminal += (100.0 - state.life) * 0.3;
      if(story.retrX > 75.0)                                  lTerminal += 25.0;
      if(curve.gForceState == FORCE_LEAKING)                  lTerminal += 22.0;
      if(story.recursionComplete)                             lTerminal += 30.0;
      if(curve.tree.chain.Scope(state.life) == CHAIN_WHOLE_DECAYING)
                                                              lTerminal += 35.0;
      lTerminal = OmegaMath::Clamp(lTerminal, 0.0, 200.0);

      //--- transfer logit
      double lTransfer = 5.0;
      if(curve.tree.transfersCount > 0)                       lTransfer += 30.0;
      if(curve.tree.treeDepth >= 1)                           lTransfer += 15.0;
      if(state.supporting.ownershipStability < 30.0)          lTransfer += 25.0;
      if(state.supporting.alignment < 33.0)                   lTransfer += 15.0;
      lTransfer = OmegaMath::Clamp(lTransfer, 0.0, 200.0);

      //--- normalise to 100
      double sum = lContinue + lTerminal + lTransfer;
      if(sum < 1e-9)
        {
         c.pContinuation = 33.34; c.pTerminal = 33.33; c.pTransfer = 33.33;
        }
      else
        {
         c.pContinuation = lContinue / sum * 100.0;
         c.pTerminal     = lTerminal / sum * 100.0;
         c.pTransfer     = lTransfer / sum * 100.0;
        }
      return c;
     }

   static string CloudString(const ProbabilityCloud &c)
     {
      return StringFormat("cont=%.0f%% term=%.0f%% trans=%.0f%%",
                          c.pContinuation, c.pTerminal, c.pTransfer);
     }
  };

#endif // __OMEGA_META_PROBABILITY_MQH__

//==================================================================
//= MODULE: Meta/SelfObservation
//= Source: Include/Meta/SelfObservation.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                              SelfObservation.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 14 — the engine watches itself.                          |
//|                                                                  |
//|   Phase 6 baseline: a rolling 200-sample buffer of (life,        |
//|   stability, confidence) plus a decision-type tally and an       |
//|   outcome buffer fed by CampaignPositions on every close.        |
//|                                                                  |
//|   Emits:                                                         |
//|     LifeMean / LifeVariance      — regime stability proxy        |
//|     ConfidenceVariance           — engine self-coherence         |
//|     DecisionDiversity            — Shannon-style spread          |
//|     HitRate                      — fraction of resolved closes   |
//|                                    that ended profitable         |
//|     ContradictionRate            — back-to-back opposite entries |
//|     SelfTrust  (0..100)          — the OUTPUT consumed by        |
//|                                    Confidence module             |
//|                                                                  |
//|   Phase 6.1 will replay decision_log.csv at startup so the       |
//|   engine boots with prior history; for now it warms up live.     |
//+------------------------------------------------------------------+
#ifndef __OMEGA_META_SELFOBS_MQH__
#define __OMEGA_META_SELFOBS_MQH__


#define OMEGA_SELFOBS_SAMPLES   200
#define OMEGA_SELFOBS_OUTCOMES   64

class SelfObservation
  {
private:
   //--- rolling state samples
   double  m_life[OMEGA_SELFOBS_SAMPLES];
   double  m_stab[OMEGA_SELFOBS_SAMPLES];
   double  m_conf[OMEGA_SELFOBS_SAMPLES];
   int     m_head;
   int     m_count;

   //--- decision frequency tally
   long    m_decCounts[9];  // index = ENUM_OMEGA_DECISION
   long    m_decTotal;
   ENUM_OMEGA_DECISION m_lastDec;
   long    m_contradictionCount;

   //--- outcome buffer (filled on position close)
   struct OutcomeRow
     {
      ENUM_OMEGA_DECISION dec;
      double  pnl;
      datetime t;
     };
   OutcomeRow m_outcomes[OMEGA_SELFOBS_OUTCOMES];
   int        m_outHead;
   int        m_outCount;

public:
                     SelfObservation() { Reset(); }

   void Reset()
     {
      ArrayInitialize(m_life, OMEGA_TRINITY_NEUTRAL);
      ArrayInitialize(m_stab, OMEGA_TRINITY_NEUTRAL);
      ArrayInitialize(m_conf, OMEGA_TRINITY_NEUTRAL);
      m_head = 0; m_count = 0;
      ArrayInitialize(m_decCounts, 0);
      m_decTotal = 0;
      m_lastDec = OMEGA_DEC_OBSERVE;
      m_contradictionCount = 0;
      for(int i = 0; i < OMEGA_SELFOBS_OUTCOMES; i++)
        {
         m_outcomes[i].dec = OMEGA_DEC_OBSERVE;
         m_outcomes[i].pnl = 0;
         m_outcomes[i].t = 0;
        }
      m_outHead = 0; m_outCount = 0;
     }

   //=== Ingest ====================================================
   void Sample(double life, double stab, double conf)
     {
      m_life[m_head] = life;
      m_stab[m_head] = stab;
      m_conf[m_head] = conf;
      m_head = (m_head + 1) % OMEGA_SELFOBS_SAMPLES;
      if(m_count < OMEGA_SELFOBS_SAMPLES) m_count++;
     }

   void RecordDecision(ENUM_OMEGA_DECISION dec)
     {
      if((int)dec >= 0 && (int)dec < 9) m_decCounts[(int)dec]++;
      m_decTotal++;
      bool oppositeFlip =
         ((m_lastDec == OMEGA_DEC_ENTER_LONG  && dec == OMEGA_DEC_ENTER_SHORT) ||
          (m_lastDec == OMEGA_DEC_ENTER_SHORT && dec == OMEGA_DEC_ENTER_LONG));
      if(oppositeFlip) m_contradictionCount++;
      m_lastDec = dec;
     }

   void RegisterOutcome(ENUM_OMEGA_DECISION dec, double pnl)
     {
      m_outcomes[m_outHead].dec = dec;
      m_outcomes[m_outHead].pnl = pnl;
      m_outcomes[m_outHead].t   = TimeCurrent();
      m_outHead = (m_outHead + 1) % OMEGA_SELFOBS_OUTCOMES;
      if(m_outCount < OMEGA_SELFOBS_OUTCOMES) m_outCount++;
     }

   //=== Statistics ================================================
   double LifeMean() const
     {
      if(m_count == 0) return OMEGA_TRINITY_NEUTRAL;
      double s = 0.0;
      for(int i = 0; i < m_count; i++) s += m_life[i];
      return s / m_count;
     }

   double LifeVariance() const
     {
      if(m_count < 2) return 0.0;
      double mu = LifeMean();
      double v = 0.0;
      for(int i = 0; i < m_count; i++) { double d = m_life[i] - mu; v += d * d; }
      return v / m_count;
     }

   double ConfidenceVariance() const
     {
      if(m_count < 2) return 0.0;
      double mu = 0.0;
      for(int i = 0; i < m_count; i++) mu += m_conf[i];
      mu /= m_count;
      double v = 0.0;
      for(int i = 0; i < m_count; i++) { double d = m_conf[i] - mu; v += d * d; }
      return v / m_count;
     }

   double HitRate() const
     {
      if(m_outCount == 0) return 0.5;
      int wins = 0;
      for(int i = 0; i < m_outCount; i++) if(m_outcomes[i].pnl > 0) wins++;
      return (double)wins / m_outCount;
     }

   double ContradictionRate() const
     {
      if(m_decTotal < 2) return 0.0;
      return (double)m_contradictionCount / m_decTotal;
     }

   //--- Shannon-style decision diversity (0=monoculture, 1=uniform)
   double DecisionDiversity() const
     {
      if(m_decTotal == 0) return 0.0;
      double H = 0.0;
      int active = 0;
      for(int i = 0; i < 9; i++)
        {
         if(m_decCounts[i] == 0) continue;
         double p = (double)m_decCounts[i] / m_decTotal;
         H -= p * MathLog(p);
         active++;
        }
      double Hmax = (active > 1) ? MathLog(active) : 1.0;
      return (Hmax > 0) ? OmegaMath::Clamp(H / Hmax, 0.0, 1.0) : 0.0;
     }

   //=== SelfTrust composite (0..100) ==============================
   //   This is what Confidence reads to update StoryConfidence.
   //   Composition (Phase 6 baseline; Phase 6.1 will tune via
   //   reading the actual decision_log.csv at boot):
   //     +50  base (we always grant baseline trust)
   //     +25 * HitRate                         (when outcomes exist)
   //     -15 * ContradictionRate               (penalize whipsaws)
   //     -10 * (LifeVariance / 1000)           (penalize chaos)
   //     +10 * DecisionDiversity               (broad responses)
   //     -10 * (ConfidenceVariance / 1000)     (penalize self-doubt swings)
   double SelfTrust() const
     {
      double base = 50.0;
      double hr   = (m_outCount > 0) ? HitRate() : 0.5;
      double t = base
               + 25.0 * (hr - 0.5) * 2.0    // map 0..1 to -25..+25
               - 15.0 * ContradictionRate()
               - 10.0 * MathMin(LifeVariance() / 1000.0, 1.0)
               + 10.0 * DecisionDiversity()
               - 10.0 * MathMin(ConfidenceVariance() / 1000.0, 1.0);
      return OmegaMath::Clamp(t, 0.0, 100.0);
     }

   //=== Snapshot ==================================================
   string Snapshot() const
     {
      return StringFormat(
         "samples=%d outcomes=%d hit=%.0f%% contr=%.0f%% Lvar=%.0f div=%.2f trust=%.0f",
         m_count, m_outCount,
         HitRate() * 100.0, ContradictionRate() * 100.0,
         LifeVariance(), DecisionDiversity(), SelfTrust());
     }
  };

#endif // __OMEGA_META_SELFOBS_MQH__

//==================================================================
//= MODULE: Meta/Meta
//= Source: Include/Meta/Meta.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                         Meta.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer 9 + 12 + 14 — meta orchestrator.                         |
//|                                                                  |
//|   Sits BELOW Story (which has already written life/stability/    |
//|   confidence to the trinity) and ABOVE Risk/Capital/Execution.   |
//|                                                                  |
//|   On each closed bar:                                            |
//|     1. SelfObservation.Sample(trinity)                           |
//|     2. Regime.Compute → state.supporting.regime                  |
//|     3. Probability.Compute → state.supporting.pContinuation/T/X  |
//|     4. SelfObservation.SelfTrust → blend INTO state.confidence   |
//|        so the trinity reflects engine self-trust                 |
//|                                                                  |
//|   This is where the engine TRACKS ITSELF.                        |
//+------------------------------------------------------------------+
#ifndef __OMEGA_META_MQH__
#define __OMEGA_META_MQH__


class OmegaMeta
  {
public:
   //--- subcomponents
   SelfObservation  selfObs;
   ProbabilityCloud lastCloud;
   RegimeResult     lastRegime;

   //--- weight: how much SelfTrust pulls Confidence away from Story's value
   double           selfTrustBlend;

   //--- bookkeeping
   datetime         lastBarTime;
   long             barsProcessed;

                     OmegaMeta()
     {
      selfTrustBlend = 0.30;     // 30% blend by default
      lastBarTime = 0;
      barsProcessed = 0;
     }

   void Init(double blend = 0.30)
     {
      selfObs.Reset();
      selfTrustBlend = OmegaMath::Clamp(blend, 0.0, 1.0);
      OmegaLogger::LogInfo("META",
         StringFormat("Init · self-trust blend=%.0f%% · samples cap=%d",
                       selfTrustBlend * 100.0, OMEGA_SELFOBS_SAMPLES));
     }

   //--- Per closed bar, AFTER Story.Update has populated the trinity.
   bool Update(OmegaState &state, OmegaCurve &curve, const OmegaStory &story)
     {
      datetime t = curve.ChartTfState() != NULL ? curve.ChartTfState().lastBarTime : 0;
      if(t == 0 || t == lastBarTime) return false;
      lastBarTime = t;
      barsProcessed++;

      //--- 1. sample the trinity
      selfObs.Sample(state.life, state.stability, state.confidence);

      //--- 2. regime
      lastRegime = Regime::Compute(state, curve, story);
      state.supporting.regime = lastRegime.score;

      //--- 3. probability cloud
      lastCloud = Probability::Compute(state, curve, story);
      state.supporting.pContinuation = lastCloud.pContinuation;
      state.supporting.pTerminal     = lastCloud.pTerminal;
      state.supporting.pTransfer     = lastCloud.pTransfer;

      //--- 4. blend self-trust into confidence
      double selfTrust = selfObs.SelfTrust();
      state.confidence = OmegaMath::Clamp(
         state.confidence * (1.0 - selfTrustBlend) + selfTrust * selfTrustBlend,
         0.0, 100.0);

      //--- 5. recompute stability with regime now populated (Story used neutral)
      state.stability = OmegaMath::Clamp(
         state.supporting.alignment  * 0.40 +
         state.supporting.narrative  * 0.40 +
         state.supporting.regime     * 0.20,
         0.0, 100.0);

      return true;
     }

   //--- Hook for CampaignPositions to feed back outcomes
   void RegisterTradeOutcome(ENUM_OMEGA_DECISION dec, double pnl)
     {
      selfObs.RegisterOutcome(dec, pnl);
     }

   void RecordDecision(ENUM_OMEGA_DECISION dec)
     {
      selfObs.RecordDecision(dec);
     }

   string Snapshot() const
     {
      return StringFormat("regime=%s(%.0f) %s · meta[%s]",
                          lastRegime.tag, lastRegime.score,
                          Probability::CloudString(lastCloud),
                          selfObs.Snapshot());
     }
  };

#endif // __OMEGA_META_MQH__

//==================================================================
//= MODULE: Backtest/Replay
//= Source: Include/Backtest/Replay.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                       Replay.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Phase 7 · backtest helper.                                     |
//|                                                                  |
//|   Reads back the engine's own decision_log.csv and execution_log |
//|   and reconstructs:                                              |
//|     - rolling equity curve                                       |
//|     - per-decision outcome attribution                            |
//|     - per-reason hit-rate breakdown                              |
//|                                                                  |
//|   Used by Strategy Tester runs (offline replay) and by the live  |
//|   engine on init to PRIME SelfObservation with prior history.    |
//|                                                                  |
//|   Phase 7 baseline: file readers + statistics. Phase 7.1 will    |
//|   add tick-level walk-forward replay against a saved tick CSV.   |
//+------------------------------------------------------------------+
#ifndef __OMEGA_BACKTEST_REPLAY_MQH__
#define __OMEGA_BACKTEST_REPLAY_MQH__


struct ReplayStats
  {
   int     decisions;
   int     entries;
   int     exits;
   int     wins;
   int     losses;
   double  totalPnl;
   double  avgLifeAtEntry;
   double  avgConfAtEntry;
                     ReplayStats() { decisions=entries=exits=wins=losses=0; totalPnl=avgLifeAtEntry=avgConfAtEntry=0; }
  };

class Replay
  {
public:
   //--- Read decision_log.csv and produce summary stats.
   //    Columns: timestamp,symbol,mode,decision,reason,life,stability,confidence,detail
   static bool ReadDecisionLog(string path, ReplayStats &out)
     {
      int h = FileOpen(path, FILE_READ | FILE_CSV | FILE_ANSI, ',');
      if(h == INVALID_HANDLE)
        {
         OmegaLogger::LogException("REPLAY", GetLastError(),
            StringFormat("ReadDecisionLog: cannot open %s", path));
         return false;
        }
      bool first = true;
      double lifeSum = 0, confSum = 0;
      int    entryCount = 0;
      while(!FileIsEnding(h))
        {
         string ts   = FileReadString(h);
         string sym  = FileReadString(h);
         string mode = FileReadString(h);
         string dec  = FileReadString(h);
         string rea  = FileReadString(h);
         string life = FileReadString(h);
         string stab = FileReadString(h);
         string conf = FileReadString(h);
         string det  = FileReadString(h);
         if(first) { first = false; continue; }   // skip header
         if(StringLen(ts) == 0) break;
         out.decisions++;
         if(StringFind(dec, "ENTER") >= 0)
           {
            out.entries++;
            entryCount++;
            lifeSum += StringToDouble(life);
            confSum += StringToDouble(conf);
           }
         else if(dec == "EXIT" || dec == "REVERSE") out.exits++;
        }
      FileClose(h);
      if(entryCount > 0)
        {
         out.avgLifeAtEntry = lifeSum / entryCount;
         out.avgConfAtEntry = confSum / entryCount;
        }
      OmegaLogger::LogInfo("REPLAY",
         StringFormat("Decision log replay · decisions=%d entries=%d exits=%d "
                       "avgLife=%.1f avgConf=%.1f",
                       out.decisions, out.entries, out.exits,
                       out.avgLifeAtEntry, out.avgConfAtEntry));
      return true;
     }

   //--- Equity-curve estimator from execution_log.csv.
   //    Columns: timestamp,symbol,action,ticket,price,lots,reason,detail
   //    Naive PnL estimator that pairs adjacent open/close on same ticket.
   //    Phase 7.1 will replace with a proper FIFO matcher.
   static double EstimateRealisedPnl(string path)
     {
      int h = FileOpen(path, FILE_READ | FILE_CSV | FILE_ANSI, ',');
      if(h == INVALID_HANDLE) return 0.0;
      double pnl = 0.0;
      bool first = true;
      while(!FileIsEnding(h))
        {
         string ts   = FileReadString(h);
         string sym  = FileReadString(h);
         string act  = FileReadString(h);
         string tk   = FileReadString(h);
         string px   = FileReadString(h);
         string lt   = FileReadString(h);
         string rea  = FileReadString(h);
         string det  = FileReadString(h);
         if(first) { first = false; continue; }
         if(StringLen(ts) == 0) break;
         //-- this is a placeholder; live broker P&L is tracked via OnTradeTransaction.
         //   Phase 7.1 fills this with a real FIFO matcher.
        }
      FileClose(h);
      return pnl;
     }
  };

#endif // __OMEGA_BACKTEST_REPLAY_MQH__

//==================================================================
//= MODULE: Backtest/Shadow
//= Source: Include/Backtest/Shadow.mqh
//==================================================================
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

//==================================================================
//= MODULE: Backtest/Optimization
//= Source: Include/Backtest/Optimization.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                 Optimization.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Phase 7 · MT5-Strategy-Tester optimisation surface.            |
//|                                                                  |
//|   Provides a single OnTester() function the EA can route to,     |
//|   plus a fitness composite so the optimiser doesn't only chase   |
//|   raw P/L — it weighs:                                           |
//|     +1.0 × profit factor                                         |
//|     +0.5 × Sharpe-like (return / drawdown)                       |
//|     -1.0 × max drawdown %                                        |
//|     +0.3 × hit rate                                              |
//|     -0.5 × decision contradiction rate (overfit penalty)         |
//|                                                                  |
//|   Phase 7 baseline returns the composite as a single double; the |
//|   tester ranks runs by it.                                       |
//+------------------------------------------------------------------+
#ifndef __OMEGA_BACKTEST_OPTIMIZATION_MQH__
#define __OMEGA_BACKTEST_OPTIMIZATION_MQH__


class Optimization
  {
public:
   //--- Composite fitness for OnTester(). Higher = better.
   //    Inputs are stats the engine already tracks; the EA passes them
   //    in from SelfObservation + Capital + Tester results.
   static double Fitness(double profitFactor,
                          double netProfit,
                          double maxDrawdownPct,
                          double hitRate,
                          double contradictionRate)
     {
      double score = 0.0;
      score += profitFactor * 1.0;
      if(maxDrawdownPct > 0.01)
         score += (netProfit / maxDrawdownPct) * 0.5;
      score -= maxDrawdownPct * 1.0;
      score += hitRate * 30.0;          // 0..1 → 0..30
      score -= contradictionRate * 50.0;
      OmegaLogger::LogInfo("OPT",
         StringFormat("Fitness · pf=%.2f net=%.2f mdd=%.2f hr=%.2f contr=%.2f → %.2f",
                       profitFactor, netProfit, maxDrawdownPct,
                       hitRate, contradictionRate, score));
      return score;
     }

   //--- Convenience wrapper for the EA's OnTester.
   //    Pulls TesterStatistics directly so the EA's OnTester is one line.
   static double OnTesterDefault()
     {
      double profit  = TesterStatistics(STAT_PROFIT);
      double pf      = TesterStatistics(STAT_PROFIT_FACTOR);
      double mddPct  = TesterStatistics(STAT_BALANCE_DDREL_PERCENT);
      long   trades  = (long)TesterStatistics(STAT_TRADES);
      long   wins    = (long)TesterStatistics(STAT_PROFIT_TRADES);
      double hitRate = (trades > 0) ? (double)wins / trades : 0.0;
      //-- contradictionRate not available from tester; default 0 in offline runs
      return Fitness(pf, profit, mddPct, hitRate, 0.0);
     }
  };

#endif // __OMEGA_BACKTEST_OPTIMIZATION_MQH__

//==================================================================
//= MAIN EA BODY
//= Source: EA.mq5
//==================================================================
//+------------------------------------------------------------------+
//|                                                            EA.mq5|
//|                                                        F72 OMEGA |
//|                                                                  |
//|   "Is the story still alive?"                                    |
//|                                                                  |
//|   This is Phase 1 — the skeleton. The engine does NOT trade yet. |
//|   It boots the trinity, the capital state machine, the campaign  |
//|   memory, the structured logger, and the order shell. Once       |
//|   attached in OBSERVER mode it logs heartbeat decisions and      |
//|   capital state every InpHeartbeatSec seconds — proving the      |
//|   architecture is alive while explicitly stating it does not yet |
//|   perceive (REASON_PHASE_NOT_BUILT).                             |
//|                                                                  |
//|   Phase roadmap is in MT5/F72_Omega/README.md.                   |
//+------------------------------------------------------------------+

//==================================================================
//= MODULE: Funded  (Phase 5.2 — FTMO/prop funded-account overlay)
//= Source: Include/Funded.mqh
//==================================================================
//+------------------------------------------------------------------+
//|  Daily DD watchdog · total DD watchdog · profit-target tracker · |
//|  news blackout · weekend flat · consistency manager · post-target|
//|  risk reduction. Pure overlay on top of the equity-tier guards.  |
//|  When any rule trips, the module CLOSES POSITIONS and returns    |
//|  TripState != NONE so the EA suppresses new entries.             |
//+------------------------------------------------------------------+
#ifndef __OMEGA_FUNDED_MQH__
#define __OMEGA_FUNDED_MQH__

enum ENUM_OMEGA_FUNDED_FIRM
  {
   FUNDED_OFF        = 0,
   FUNDED_FTMO       = 1,
   FUNDED_THE5ERS    = 2,
   FUNDED_FUNDEDNEXT = 3,
   FUNDED_CUSTOM     = 4
  };

enum ENUM_OMEGA_FUNDED_TRIP
  {
   FUNDED_TRIP_NONE         = 0,
   FUNDED_TRIP_DAILY_DD     = 1,
   FUNDED_TRIP_TOTAL_DD     = 2,
   FUNDED_TRIP_NEWS         = 3,
   FUNDED_TRIP_WEEKEND      = 4,
   FUNDED_TRIP_CONSISTENCY  = 5,
   FUNDED_TRIP_POST_TARGET  = 6
  };

class OmegaFunded
  {
private:
   bool     m_enabled;
   ENUM_OMEGA_FUNDED_FIRM m_firm;
   double   m_dailyDDPct;        // hard limit (firm rule)
   double   m_totalDDPct;
   double   m_targetPct;
   double   m_dailyHaltPct;      // soft halt (engine pause buffer)
   double   m_totalHaltPct;
   double   m_postTargetRiskMult;// 0.25 = run at 25% normal after target
   double   m_dailyMaxProfitPct; // consistency rule limit
   bool     m_weekendFlat;
   int      m_fridayCloseHourGmt;
   bool     m_newsBlackout;
   int      m_newsBlackoutMin;

   // runtime state
   datetime m_anchorDay;
   double   m_dayStartEquity;
   double   m_evalStartEquity;
   double   m_dayHighEquity;
   double   m_peakEquity;
   ENUM_OMEGA_FUNDED_TRIP m_trip;
   string   m_tripReason;
   bool     m_targetHit;
   double   m_dailyHighProfitPct; // for consistency
   double   m_lastReportedDdPctDay;
   double   m_lastReportedDdPctTotal;

public:
                     OmegaFunded()
     {
      m_enabled = false; m_firm = FUNDED_OFF;
      m_dailyDDPct = 5.0; m_totalDDPct = 10.0; m_targetPct = 10.0;
      m_dailyHaltPct = 4.0; m_totalHaltPct = 8.0;
      m_postTargetRiskMult = 0.25; m_dailyMaxProfitPct = 50.0;
      m_weekendFlat = true; m_fridayCloseHourGmt = 21;
      m_newsBlackout = true; m_newsBlackoutMin = 30;
      m_anchorDay = 0; m_dayStartEquity = 0; m_evalStartEquity = 0;
      m_dayHighEquity = 0; m_peakEquity = 0;
      m_trip = FUNDED_TRIP_NONE; m_tripReason = "";
      m_targetHit = false; m_dailyHighProfitPct = 0;
      m_lastReportedDdPctDay = 0; m_lastReportedDdPctTotal = 0;
     }

   void Init(bool enabled, ENUM_OMEGA_FUNDED_FIRM firm,
             double dailyDdPct, double totalDdPct, double targetPct,
             double dailyHaltPct, double totalHaltPct,
             double postTargetMult, double dailyMaxProfitPct,
             bool weekendFlat, int fridayCloseHourGmt,
             bool newsBlackout, int newsBlackoutMin)
     {
      m_enabled = enabled;
      m_firm    = firm;
      // Apply firm presets unless CUSTOM
      if(firm == FUNDED_FTMO)
        { m_dailyDDPct = 5.0; m_totalDDPct = 10.0; m_targetPct = 10.0;
          m_dailyHaltPct = 4.0; m_totalHaltPct = 8.0; }
      else if(firm == FUNDED_THE5ERS)
        { m_dailyDDPct = 4.0; m_totalDDPct = 6.0; m_targetPct = 6.0;
          m_dailyHaltPct = 3.0; m_totalHaltPct = 5.0; }
      else if(firm == FUNDED_FUNDEDNEXT)
        { m_dailyDDPct = 5.0; m_totalDDPct = 10.0; m_targetPct = 8.0;
          m_dailyHaltPct = 4.0; m_totalHaltPct = 8.0; }
      else
        { m_dailyDDPct = dailyDdPct; m_totalDDPct = totalDdPct;
          m_targetPct = targetPct; m_dailyHaltPct = dailyHaltPct;
          m_totalHaltPct = totalHaltPct; }
      m_postTargetRiskMult  = postTargetMult;
      m_dailyMaxProfitPct   = dailyMaxProfitPct;
      m_weekendFlat         = weekendFlat;
      m_fridayCloseHourGmt  = fridayCloseHourGmt;
      m_newsBlackout        = newsBlackout;
      m_newsBlackoutMin     = newsBlackoutMin;
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      m_evalStartEquity = eq;
      m_dayStartEquity  = eq;
      m_dayHighEquity   = eq;
      m_peakEquity      = eq;
      m_anchorDay       = (TimeCurrent() / 86400) * 86400;
      OmegaLogger::LogInfo("FUNDED",
         StringFormat("Init · enabled=%s firm=%d · dDD=%.1f%%/halt=%.1f%% · tDD=%.1f%%/halt=%.1f%% · tgt=%.1f%% · weekendFlat=%s newsBlackout=%s",
                       enabled ? "YES" : "NO", (int)firm,
                       m_dailyDDPct, m_dailyHaltPct, m_totalDDPct, m_totalHaltPct,
                       m_targetPct, m_weekendFlat ? "Y" : "N", m_newsBlackout ? "Y" : "N"));
     }

   //--- Update on every tick. Returns the trip state — caller (EA)
   //    inspects it and either suppresses entries or closes all.
   ENUM_OMEGA_FUNDED_TRIP Update(OmegaNewsCalendar &news)
     {
      if(!m_enabled) { m_trip = FUNDED_TRIP_NONE; return m_trip; }
      datetime now = TimeCurrent();
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);

      //-- daily anchor reset at midnight
      datetime today = (now / 86400) * 86400;
      if(today != m_anchorDay)
        {
         m_anchorDay = today;
         m_dayStartEquity = eq;
         m_dayHighEquity  = eq;
         m_dailyHighProfitPct = 0;
         m_trip = FUNDED_TRIP_NONE;
         OmegaLogger::LogInfo("FUNDED",
            StringFormat("New trading day · anchor equity=%.2f", eq));
        }
      if(eq > m_dayHighEquity) m_dayHighEquity = eq;
      if(eq > m_peakEquity)    m_peakEquity   = eq;

      //-- daily DD (vs day open)
      double ddDay = (m_dayStartEquity > 0)
                       ? (m_dayStartEquity - eq) / m_dayStartEquity * 100.0 : 0.0;
      //-- total DD (vs eval start)
      double ddTot = (m_evalStartEquity > 0)
                       ? (m_evalStartEquity - eq) / m_evalStartEquity * 100.0 : 0.0;
      m_lastReportedDdPctDay   = ddDay;
      m_lastReportedDdPctTotal = ddTot;

      //-- profit %% vs eval start
      double profitPct = (m_evalStartEquity > 0)
                          ? (eq - m_evalStartEquity) / m_evalStartEquity * 100.0 : 0.0;
      double dayProfitPct = (m_dayStartEquity > 0)
                             ? (eq - m_dayStartEquity) / m_dayStartEquity * 100.0 : 0.0;
      if(dayProfitPct > m_dailyHighProfitPct) m_dailyHighProfitPct = dayProfitPct;

      //-- target hit?
      if(!m_targetHit && profitPct >= m_targetPct)
        {
         m_targetHit = true;
         OmegaLogger::LogInfo("FUNDED",
            StringFormat("PROFIT TARGET HIT · profit %.2f%% >= target %.2f%% · risk reduced to %.0f%%",
                          profitPct, m_targetPct, m_postTargetRiskMult * 100.0));
        }

      //-- DD trips
      if(ddTot >= m_totalHaltPct)
        {
         m_trip = FUNDED_TRIP_TOTAL_DD;
         m_tripReason = StringFormat("Total DD %.2f%% >= halt %.2f%%", ddTot, m_totalHaltPct);
         return m_trip;
        }
      if(ddDay >= m_dailyHaltPct)
        {
         m_trip = FUNDED_TRIP_DAILY_DD;
         m_tripReason = StringFormat("Daily DD %.2f%% >= halt %.2f%%", ddDay, m_dailyHaltPct);
         return m_trip;
        }
      //-- consistency rule (single day captures > N% of total target)
      if(m_dailyMaxProfitPct > 0 && m_targetPct > 0 &&
         m_dailyHighProfitPct >= m_targetPct * m_dailyMaxProfitPct / 100.0)
        {
         m_trip = FUNDED_TRIP_CONSISTENCY;
         m_tripReason = StringFormat("Day profit %.2f%% would breach consistency rule",
                                      m_dailyHighProfitPct);
         return m_trip;
        }
      //-- weekend flat
      if(m_weekendFlat)
        {
         MqlDateTime t; TimeToStruct(now, t);
         if(t.day_of_week == 5 && t.hour >= m_fridayCloseHourGmt)
           {
            m_trip = FUNDED_TRIP_WEEKEND;
            m_tripReason = "Weekend close window";
            return m_trip;
           }
         if(t.day_of_week == 6 || t.day_of_week == 0)
           {
            m_trip = FUNDED_TRIP_WEEKEND;
            m_tripReason = "Weekend";
            return m_trip;
           }
        }
      //-- news blackout (uses existing OmegaNewsCalendar)
      if(m_newsBlackout)
        {
         //-- proxy: if news.CurrentEnvironment() reports HIGH IMPACT
         //   within the lookahead window, blackout
         string env = news.CurrentEnvironment();
         if(StringFind(env, "HIGH") >= 0 || StringFind(env, "BLACKOUT") >= 0)
           {
            m_trip = FUNDED_TRIP_NEWS;
            m_tripReason = "News blackout · " + env;
            return m_trip;
           }
        }
      m_trip = FUNDED_TRIP_NONE;
      m_tripReason = "";
      return m_trip;
     }

   //--- Risk multiplier from funded mode (post-target reduction).
   //    1.0 = normal; below 1.0 = reduced.
   double RiskMultiplier() const
     {
      if(!m_enabled || !m_targetHit) return 1.0;
      return m_postTargetRiskMult;
     }

   //--- Should the EA suppress new entries now?
   bool BlocksEntries() const { return m_enabled && m_trip != FUNDED_TRIP_NONE; }
   //--- Should the EA close all positions now?
   bool RequiresFlat() const
     {
      return m_enabled && (m_trip == FUNDED_TRIP_DAILY_DD ||
                            m_trip == FUNDED_TRIP_TOTAL_DD ||
                            m_trip == FUNDED_TRIP_WEEKEND);
     }

   string TripStr() const
     {
      switch(m_trip)
        {
         case FUNDED_TRIP_DAILY_DD:    return "DAILY DD HALT";
         case FUNDED_TRIP_TOTAL_DD:    return "TOTAL DD HALT";
         case FUNDED_TRIP_NEWS:        return "NEWS BLACKOUT";
         case FUNDED_TRIP_WEEKEND:     return "WEEKEND";
         case FUNDED_TRIP_CONSISTENCY: return "CONSISTENCY";
         case FUNDED_TRIP_POST_TARGET: return "POST-TARGET";
        }
      return "OK";
     }

   //--- accessors for HUD
   bool   Enabled()    const { return m_enabled; }
   double DailyDdPct() const { return m_lastReportedDdPctDay; }
   double TotalDdPct() const { return m_lastReportedDdPctTotal; }
   double DailyHaltPct() const { return m_dailyHaltPct; }
   double TotalHaltPct() const { return m_totalHaltPct; }
   double TargetPct()  const { return m_targetPct; }
   bool   TargetHit()  const { return m_targetHit; }
   string TripReason() const { return m_tripReason; }
   double EvalStartEquity() const { return m_evalStartEquity; }
   double DayStartEquity()  const { return m_dayStartEquity; }
   ENUM_OMEGA_FUNDED_FIRM Firm() const { return m_firm; }
   string FirmStr() const
     {
      switch(m_firm)
        {
         case FUNDED_FTMO:       return "FTMO";
         case FUNDED_THE5ERS:    return "5%ers";
         case FUNDED_FUNDEDNEXT: return "FundedNext";
         case FUNDED_CUSTOM:     return "Custom";
        }
      return "off";
     }
  };

#endif // __OMEGA_FUNDED_MQH__

//==================================================================
//= MODULE: Memory  (Phase 9 — campaign archive · similarity · sizing)
//= Source: Include/CampaignArchive.mqh
//==================================================================
//+------------------------------------------------------------------+
//|  Phase 9.1 — campaign serializer + archive loader                |
//|  Phase 9.2 — similarity matcher (top-K analogues)                |
//|  Phase 9.3 — confidence-adjustment from analogue outcomes        |
//|                                                                  |
//|  Per closed campaign we write a single row to                    |
//|    MQL5/Files/OmegaMemory/<symbol>.csv                           |
//|  with the trinity at entry, alignment components, force/regime,  |
//|  depth reached, P&L, outcome label.                              |
//|                                                                  |
//|  On init we load every row of that file into a CampaignRecord    |
//|  array. Before each new entry, the engine calls Match() to find  |
//|  the K nearest historical analogues by fingerprint and asks      |
//|  SizeAdjustment() for a multiplier in [0.1, 1.5].                |
//+------------------------------------------------------------------+
#ifndef __OMEGA_CAMPAIGN_ARCHIVE_MQH__
#define __OMEGA_CAMPAIGN_ARCHIVE_MQH__

#define OMEGA_ARCHIVE_MAX 2048

struct CampaignRecord
  {
   datetime opened;
   datetime closed;
   string   symbol;
   int      direction;
   int      tier;
   double   lifeAtEntry;
   double   stabAtEntry;
   double   confAtEntry;
   double   narrAlignAtEntry;
   double   forceAtEntry;
   double   regime;
   int      depth;
   int      adds;
   double   pnl;
   double   pnlPct;       // %% of equity at entry
   string   outcome;      // WON / LOST / SCRATCH
   long     campaignId;
  };

class CampaignArchive
  {
private:
   CampaignRecord m_recs[OMEGA_ARCHIVE_MAX];
   int            m_count;
   string         m_folder;
   bool           m_enabled;
   // pending in-flight campaigns (open → close)
   long           m_pendIds[64];
   datetime       m_pendOpened[64];
   double         m_pendLife[64];
   double         m_pendStab[64];
   double         m_pendConf[64];
   double         m_pendNarr[64];
   double         m_pendForce[64];
   double         m_pendRegime[64];
   int            m_pendTier[64];
   int            m_pendDir[64];
   double         m_pendEqAtEntry[64];
   int            m_pendCount;

public:
                     CampaignArchive() { m_count = 0; m_pendCount = 0; m_enabled = false; m_folder = "OmegaMemory"; }

   void Init(bool enabled, string folder)
     {
      m_enabled = enabled;
      m_folder  = (StringLen(folder) > 0) ? folder : "OmegaMemory";
      LoadAll();
      OmegaLogger::LogInfo("ARCHIVE",
         StringFormat("Init · enabled=%s · folder=%s · loaded %d campaigns",
                       enabled ? "YES" : "NO", m_folder, m_count));
     }

   //--- Build a per-symbol CSV path: MQL5\Files\<folder>\<sym>.csv
   string FilePath(string sym) const
     {
      return m_folder + "\\" + sym + ".csv";
     }

   void LoadAll()
     {
      m_count = 0;
      string sym = _Symbol;
      string path = FilePath(sym);
      int h = FileOpen(path, FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ);
      if(h == INVALID_HANDLE)
        {
         //-- try non-COMMON (per-terminal) folder
         h = FileOpen(path, FILE_READ|FILE_CSV|FILE_ANSI|FILE_SHARE_READ);
        }
      if(h == INVALID_HANDLE) return;
      // header line
      if(!FileIsEnding(h)) FileReadString(h);
      while(!FileIsEnding(h) && m_count < OMEGA_ARCHIVE_MAX)
        {
         CampaignRecord r;
         r.opened          = (datetime)FileReadInteger(h);
         r.closed          = (datetime)FileReadInteger(h);
         r.symbol          = FileReadString(h);
         r.direction       = (int)FileReadInteger(h);
         r.tier            = (int)FileReadInteger(h);
         r.lifeAtEntry     = FileReadNumber(h);
         r.stabAtEntry     = FileReadNumber(h);
         r.confAtEntry     = FileReadNumber(h);
         r.narrAlignAtEntry= FileReadNumber(h);
         r.forceAtEntry    = FileReadNumber(h);
         r.regime          = FileReadNumber(h);
         r.depth           = (int)FileReadInteger(h);
         r.adds            = (int)FileReadInteger(h);
         r.pnl             = FileReadNumber(h);
         r.pnlPct          = FileReadNumber(h);
         r.outcome         = FileReadString(h);
         r.campaignId      = FileReadInteger(h);
         if(r.opened > 0) { m_recs[m_count] = r; m_count++; }
        }
      FileClose(h);
     }

   void Append(const CampaignRecord &r)
     {
      string path = FilePath(_Symbol);
      bool   exists = FileIsExist(path);
      int h = FileOpen(path, FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI|FILE_SHARE_READ);
      if(h == INVALID_HANDLE) return;
      FileSeek(h, 0, SEEK_END);
      if(!exists)
        {
         FileWrite(h, "opened","closed","symbol","direction","tier",
                   "life","stab","conf","narrAlign","force","regime",
                   "depth","adds","pnl","pnlPct","outcome","campaignId");
        }
      FileWrite(h, (long)r.opened, (long)r.closed, r.symbol, r.direction, r.tier,
                r.lifeAtEntry, r.stabAtEntry, r.confAtEntry, r.narrAlignAtEntry,
                r.forceAtEntry, r.regime, r.depth, r.adds, r.pnl, r.pnlPct,
                r.outcome, r.campaignId);
      FileClose(h);
     }

   //--- Phase 9.1: events from the position manager
   void OnCampaignOpen(long campaignId, int direction, int tier,
                        const OmegaState &state, double forceScore, double regime,
                        double equityAtEntry)
     {
      if(!m_enabled || m_pendCount >= 64) return;
      // dedupe
      for(int i = 0; i < m_pendCount; i++)
         if(m_pendIds[i] == campaignId) return;
      int s = m_pendCount;
      m_pendIds[s]        = campaignId;
      m_pendOpened[s]     = TimeCurrent();
      m_pendLife[s]       = state.life;
      m_pendStab[s]       = state.stability;
      m_pendConf[s]       = state.confidence;
      m_pendNarr[s]       = state.supporting.alignment;
      m_pendForce[s]      = forceScore;
      m_pendRegime[s]     = regime;
      m_pendTier[s]       = tier;
      m_pendDir[s]        = direction;
      m_pendEqAtEntry[s]  = equityAtEntry;
      m_pendCount++;
     }

   void OnCampaignClose(long campaignId, double pnl, int depth, int adds, string outcome)
     {
      if(!m_enabled) return;
      int found = -1;
      for(int i = 0; i < m_pendCount; i++) if(m_pendIds[i] == campaignId) { found = i; break; }
      if(found < 0) return;
      CampaignRecord r;
      r.opened           = m_pendOpened[found];
      r.closed           = TimeCurrent();
      r.symbol           = _Symbol;
      r.direction        = m_pendDir[found];
      r.tier             = m_pendTier[found];
      r.lifeAtEntry      = m_pendLife[found];
      r.stabAtEntry      = m_pendStab[found];
      r.confAtEntry      = m_pendConf[found];
      r.narrAlignAtEntry = m_pendNarr[found];
      r.forceAtEntry     = m_pendForce[found];
      r.regime           = m_pendRegime[found];
      r.depth            = depth;
      r.adds             = adds;
      r.pnl              = pnl;
      r.pnlPct           = (m_pendEqAtEntry[found] > 0) ? (pnl / m_pendEqAtEntry[found]) * 100.0 : 0.0;
      r.outcome          = outcome;
      r.campaignId       = campaignId;
      Append(r);
      if(m_count < OMEGA_ARCHIVE_MAX) { m_recs[m_count] = r; m_count++; }
      // shift pending array
      for(int j = found; j < m_pendCount - 1; j++)
        {
         m_pendIds[j]        = m_pendIds[j+1];
         m_pendOpened[j]     = m_pendOpened[j+1];
         m_pendLife[j]       = m_pendLife[j+1];
         m_pendStab[j]       = m_pendStab[j+1];
         m_pendConf[j]       = m_pendConf[j+1];
         m_pendNarr[j]       = m_pendNarr[j+1];
         m_pendForce[j]      = m_pendForce[j+1];
         m_pendRegime[j]     = m_pendRegime[j+1];
         m_pendTier[j]       = m_pendTier[j+1];
         m_pendDir[j]        = m_pendDir[j+1];
         m_pendEqAtEntry[j]  = m_pendEqAtEntry[j+1];
        }
      m_pendCount--;
     }

   //--- Phase 9.2: similarity match. Returns top-K nearest by
   //    fingerprint (life, stab, conf, narrAlign, force, regime).
   //    Outputs: outIdx[], outDist[], outOutcomeWon[].
   //    Returns: count of matches found (≤ k).
   int Match(const OmegaState &state, double forceScore, double regime, int direction,
             int k, int &outIdx[], double &outDist[], int &outWon[])
     {
      if(m_count == 0 || !m_enabled) return 0;
      double dist[OMEGA_ARCHIVE_MAX];
      int    idx [OMEGA_ARCHIVE_MAX];
      int    n = 0;
      for(int i = 0; i < m_count; i++)
        {
         if(m_recs[i].direction != direction) continue;
         double d2 = 0;
         d2 += MathPow(state.life       - m_recs[i].lifeAtEntry,      2);
         d2 += MathPow(state.stability  - m_recs[i].stabAtEntry,      2);
         d2 += MathPow(state.confidence - m_recs[i].confAtEntry,      2);
         d2 += MathPow(state.supporting.alignment - m_recs[i].narrAlignAtEntry, 2);
         d2 += MathPow(forceScore       - m_recs[i].forceAtEntry,     2) * 0.5;
         d2 += MathPow(regime           - m_recs[i].regime,           2) * 0.5;
         dist[n] = MathSqrt(d2);
         idx[n]  = i;
         n++;
        }
      // partial sort: top-k by smallest dist (insertion-sort style on top-k)
      ArrayResize(outIdx,  k);
      ArrayResize(outDist, k);
      ArrayResize(outWon,  k);
      int kept = 0;
      for(int i = 0; i < n; i++)
        {
         int   pos = kept;
         double d  = dist[i];
         //-- find insertion position
         while(pos > 0 && d < outDist[pos-1])
           {
            if(pos < k) { outDist[pos] = outDist[pos-1]; outIdx[pos] = outIdx[pos-1]; outWon[pos] = outWon[pos-1]; }
            pos--;
           }
         if(pos < k)
           {
            outDist[pos] = d;
            outIdx[pos]  = idx[i];
            outWon[pos]  = (m_recs[idx[i]].pnl > 0) ? 1 : (m_recs[idx[i]].pnl < 0 ? 0 : -1);
            if(kept < k) kept++;
           }
        }
      return kept;
     }

   //--- Phase 9.3: convert match outcomes to a sizing multiplier.
   //    Cold-start safe: if archive < 20 records, return 1.0 (no change).
   //    Bounded: clamped to [0.1, 1.5] so a noisy match can't make
   //    the engine reckless or paralysed.
   double SizeAdjustment(const int &outWon[], int matchCount)
     {
      if(!m_enabled || m_count < 20 || matchCount < 3) return 1.0;
      int wins = 0, losses = 0;
      for(int i = 0; i < matchCount; i++)
        {
         if(outWon[i] == 1) wins++;
         else if(outWon[i] == 0) losses++;
        }
      int decided = wins + losses;
      if(decided == 0) return 1.0;
      double winRate = (double)wins / (double)decided;
      // map [0..1] win-rate to [0.1..1.5] multiplier
      double mult = 0.1 + winRate * 1.4;
      return MathMax(0.1, MathMin(1.5, mult));
     }

   //--- accessors
   int   Count() const { return m_count; }
   bool  Enabled() const { return m_enabled; }
   int   PendingCount() const { return m_pendCount; }
  };

#endif // __OMEGA_CAMPAIGN_ARCHIVE_MQH__

//==================================================================
//= MODULE: Explain  (Phase 14 — explainability ring buffer)
//==================================================================
//+------------------------------------------------------------------+
//|  Every decision (verdict, reason, snapshot) lands in a ring of   |
//|  the last N decisions with full state context. The HUD shows the |
//|  last 5 decisions inline so you can see what the engine did and  |
//|  WHY at each bar.                                                |
//+------------------------------------------------------------------+
#ifndef __OMEGA_EXPLAIN_MQH__
#define __OMEGA_EXPLAIN_MQH__

#define OMEGA_EXPLAIN_RING 50

struct ExplainEntry
  {
   datetime t;
   int      decision;
   int      reason;
   double   life, stab, conf, narrAlign;
   string   why;     // synthesised from current state
   string   detail;  // raw decision detail
  };

class OmegaExplain
  {
private:
   ExplainEntry m_ring[OMEGA_EXPLAIN_RING];
   int          m_head;
   int          m_count;

public:
                     OmegaExplain() { m_head = 0; m_count = 0; }

   void Record(int decision, int reason, const OmegaState &state, string detail)
     {
      ExplainEntry e;
      e.t          = TimeCurrent();
      e.decision   = decision;
      e.reason     = reason;
      e.life       = state.life;
      e.stab       = state.stability;
      e.conf       = state.confidence;
      e.narrAlign  = state.supporting.alignment;
      e.detail     = detail;
      e.why        = SynthesiseWhy(decision, state);
      m_ring[m_head] = e;
      m_head = (m_head + 1) % OMEGA_EXPLAIN_RING;
      if(m_count < OMEGA_EXPLAIN_RING) m_count++;
     }

   //--- Compose a why-string explaining the decision.
   string SynthesiseWhy(int decision, const OmegaState &state) const
     {
      string base = "";
      if(decision == OMEGA_DEC_ENTER_LONG || decision == OMEGA_DEC_ENTER_SHORT)
         base = StringFormat("life %.0f healthy + narr %.0f coherent + tier floor pass",
                              state.life, state.supporting.alignment);
      else if(decision == OMEGA_DEC_ADD)
         base = StringFormat("campaign progressing · life %.0f · narr %.0f", state.life, state.supporting.alignment);
      else if(decision == OMEGA_DEC_REVERSE)
         base = "ownership transferred · counter-side now owns";
      else if(decision == OMEGA_DEC_EXIT)
         base = StringFormat("life %.0f below floor · story ended", state.life);
      else if(decision == OMEGA_DEC_REDUCE)
         base = StringFormat("life weakening %.0f · trim risk", state.life);
      else if(decision == OMEGA_DEC_HOLD)
         base = "campaign alive · no action";
      else
         base = StringFormat("waiting · life %.0f stab %.0f conf %.0f narr %.0f",
                              state.life, state.stability, state.confidence, state.supporting.alignment);
      return base;
     }

   //--- Most recent N entries (newest first). Returns count actually filled.
   int RecentN(int wantN, ExplainEntry &out[]) const
     {
      int n = MathMin(wantN, m_count);
      ArrayResize(out, n);
      for(int i = 0; i < n; i++)
        {
         int idx = (m_head - 1 - i + OMEGA_EXPLAIN_RING) % OMEGA_EXPLAIN_RING;
         out[i] = m_ring[idx];
        }
      return n;
     }

   int Count() const { return m_count; }
  };

#endif // __OMEGA_EXPLAIN_MQH__

//==================================================================
//= MODULE: Attention  (Phase 10 — focus engine)
//==================================================================
//+------------------------------------------------------------------+
//|  Attention = "what matters most right now". Scores 0..100 from   |
//|  4 urgency signals: compression critical, parent threat near,    |
//|  life inflection, alignment shift. Higher score = more urgent.   |
//|  Used by HUD to highlight the curve under highest attention.    |
//+------------------------------------------------------------------+
#ifndef __OMEGA_ATTENTION_MQH__
#define __OMEGA_ATTENTION_MQH__

class OmegaAttention
  {
private:
   double m_lastLife;
   double m_lastNarr;
   double m_score;
   string m_dominant;

public:
                     OmegaAttention() { m_lastLife = 50; m_lastNarr = 50; m_score = 0; m_dominant = "—"; }

   //--- Update on each closed bar.
   void Update(const OmegaState &state, OmegaCurve &curve)
     {
      double s = 0;
      string dom = "—";

      //-- compression critical (compIdx high == tightening near release)
      double comp = state.supporting.compression;
      if(comp >= 70.0) { s += 30; if(dom == "—") dom = "compression release imminent"; }
      else if(comp >= 50.0) s += 15;

      //-- life inflection (rapid change)
      double dLife = state.life - m_lastLife;
      if(MathAbs(dLife) >= 8.0) { s += 25; if(dom == "—") dom = (dLife>0 ? "life rising fast" : "life falling fast"); }
      else if(MathAbs(dLife) >= 4.0) s += 12;

      //-- narrative alignment shift
      double dNarr = state.supporting.alignment - m_lastNarr;
      if(MathAbs(dNarr) >= 8.0) { s += 25; if(dom == "—") dom = (dNarr>0 ? "narrative re-cohering" : "narrative breaking"); }

      //-- transfer probability
      double xfer = state.supporting.pTransfer;
      if(xfer >= 60.0) { s += 20; if(dom == "—") dom = "transfer probability spiking"; }

      //-- owner near death
      int oi = curve.tree.ownerIndex;
      if(oi >= 0 && curve.tree.tree[oi].alive && curve.tree.tree[oi].energy < 25)
        { s += 25; if(dom == "—") dom = "owner curve near death"; }

      m_score = MathMax(0.0, MathMin(100.0, s));
      m_dominant = dom;
      m_lastLife = state.life;
      m_lastNarr = state.supporting.alignment;
     }

   double Score()    const { return m_score; }
   string Dominant() const { return m_dominant; }
  };

#endif // __OMEGA_ATTENTION_MQH__

//==================================================================
//= MODULE: Portfolio  (Phase 11 — cross-symbol awareness)
//==================================================================
//+------------------------------------------------------------------+
//|  Counts open positions across ALL symbols on the broker (any     |
//|  magic), tracks total notional exposure, and detects correlated  |
//|  overlap (multiple positions on macro-correlated pairs). Returns |
//|  a cap multiplier the Risk module multiplies into LotsFor.       |
//+------------------------------------------------------------------+
#ifndef __OMEGA_PORTFOLIO_MQH__
#define __OMEGA_PORTFOLIO_MQH__

class OmegaPortfolio
  {
private:
   int    m_totalPositions;
   double m_totalNotional;
   int    m_correlated;
   double m_aggLevPct;
   double m_capMultiplier;
   double m_maxAggLevPct;     // hard cap

public:
                     OmegaPortfolio() { Reset(); m_maxAggLevPct = 2500.0; }

   void Init(double maxAggLevPct) { m_maxAggLevPct = maxAggLevPct; Reset(); }
   void Reset() { m_totalPositions = 0; m_totalNotional = 0; m_correlated = 0; m_aggLevPct = 0; m_capMultiplier = 1.0; }

   //--- Refresh counters from open broker positions.
   void Update(double equity)
     {
      Reset();
      int total = PositionsTotal();
      string mySym = _Symbol;
      string mySymBase = StringSubstr(mySym, 0, 3);     // crude: 'XAU' / 'EUR' / etc.
      for(int i = 0; i < total; i++)
        {
         ulong tk = PositionGetTicket(i);
         if(tk == 0) continue;
         if(!PositionSelectByTicket(tk)) continue;
         string sym = PositionGetString(POSITION_SYMBOL);
         double vol = PositionGetDouble(POSITION_VOLUME);
         double px  = PositionGetDouble(POSITION_PRICE_CURRENT);
         double cs  = SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE);
         m_totalPositions++;
         m_totalNotional += MathAbs(vol * px * cs);
         if(StringLen(sym) >= 3 && StringSubstr(sym, 0, 3) == mySymBase && sym != mySym)
            m_correlated++;
        }
      m_aggLevPct = (equity > 0) ? (m_totalNotional / equity) * 100.0 : 0.0;
      // cap multiplier: scale down as we approach max leverage
      if(m_maxAggLevPct > 0 && m_aggLevPct >= m_maxAggLevPct)
         m_capMultiplier = 0.0;       // hard refuse new entries
      else if(m_maxAggLevPct > 0 && m_aggLevPct >= m_maxAggLevPct * 0.75)
         m_capMultiplier = 0.5;       // soft slowdown
      else
         m_capMultiplier = 1.0;
      // correlation penalty
      if(m_correlated >= 2) m_capMultiplier *= 0.5;
     }

   double CapMultiplier() const { return m_capMultiplier; }
   int    TotalPositions() const { return m_totalPositions; }
   double TotalNotional()  const { return m_totalNotional; }
   double AggLeveragePct() const { return m_aggLevPct; }
   int    Correlated()     const { return m_correlated; }
   double MaxAggLevPct()   const { return m_maxAggLevPct; }
  };

#endif // __OMEGA_PORTFOLIO_MQH__

//==================================================================
//= MODULE: MetaChain  (Phase 12 — campaigns of campaigns)
//==================================================================
//+------------------------------------------------------------------+
//|  Tracks the engine's recent campaign outcomes by symbol. Detects |
//|  streaks (good or bad) and exposes a confidence multiplier the   |
//|  decision engine can read.                                       |
//+------------------------------------------------------------------+
#ifndef __OMEGA_META_CHAIN_MQH__
#define __OMEGA_META_CHAIN_MQH__

#define OMEGA_META_RING 30

class OmegaMetaChain
  {
private:
   double m_pnls[OMEGA_META_RING];
   int    m_head;
   int    m_count;
   double m_lastTotal;
   int    m_streakWins;
   int    m_streakLosses;

public:
                     OmegaMetaChain() { m_head = 0; m_count = 0; m_lastTotal = 0; m_streakWins = 0; m_streakLosses = 0; }

   void OnCampaignClose(double pnl)
     {
      m_pnls[m_head] = pnl;
      m_head = (m_head + 1) % OMEGA_META_RING;
      if(m_count < OMEGA_META_RING) m_count++;
      if(pnl > 0)
        {
         m_streakWins++;
         m_streakLosses = 0;
        }
      else if(pnl < 0)
        {
         m_streakLosses++;
         m_streakWins = 0;
        }
      m_lastTotal = 0;
      for(int i = 0; i < m_count; i++) m_lastTotal += m_pnls[i];
     }

   //--- Confidence multiplier from streak. Bounded.
   double Multiplier() const
     {
      if(m_streakWins   >= 5) return 1.20;   // hot streak → bump
      if(m_streakWins   >= 3) return 1.10;
      if(m_streakLosses >= 5) return 0.50;   // cold streak → throttle hard
      if(m_streakLosses >= 3) return 0.75;
      return 1.0;
     }

   double WinRate() const
     {
      if(m_count == 0) return 0.50;
      int w = 0, decided = 0;
      for(int i = 0; i < m_count; i++) { if(m_pnls[i] > 0) w++; if(m_pnls[i] != 0) decided++; }
      return (decided > 0) ? (double)w / (double)decided : 0.50;
     }

   int    StreakWins()   const { return m_streakWins; }
   int    StreakLosses() const { return m_streakLosses; }
   int    Count()        const { return m_count; }
   double TotalPnl()     const { return m_lastTotal; }
  };

#endif // __OMEGA_META_CHAIN_MQH__

//==================================================================
//= MODULE: SelfEvolution  (Phase 13 — adaptive thresholds)
//==================================================================
//+------------------------------------------------------------------+
//|  Watches engine hit-rate over a rolling window. If degrading,    |
//|  tightens the trinity floors and narrative threshold by a small  |
//|  step. If improving, eases them. Bounded ranges so the engine    |
//|  cannot drift off the rails. The tuned thresholds are written    |
//|  back to DecisionParams every N closed campaigns.                |
//+------------------------------------------------------------------+
#ifndef __OMEGA_SELF_EVOLUTION_MQH__
#define __OMEGA_SELF_EVOLUTION_MQH__

class OmegaSelfEvolution
  {
private:
   double m_baselineWinRate;
   double m_lastWinRate;
   int    m_rebalanceEvery;     // every N closed campaigns
   int    m_closedSinceCheck;
   double m_lifeFloorMin, m_lifeFloorMax;
   double m_stabFloorMin, m_stabFloorMax;
   double m_confFloorMin, m_confFloorMax;
   double m_narrFloorMin, m_narrFloorMax;
   bool   m_enabled;

public:
                     OmegaSelfEvolution()
     {
      m_baselineWinRate = 0.55;
      m_lastWinRate = 0.55;
      m_rebalanceEvery = 5;
      m_closedSinceCheck = 0;
      m_lifeFloorMin = 35; m_lifeFloorMax = 65;
      m_stabFloorMin = 35; m_stabFloorMax = 65;
      m_confFloorMin = 30; m_confFloorMax = 60;
      m_narrFloorMin = 50; m_narrFloorMax = 80;
      m_enabled = false;
     }

   void Init(bool enabled, double baseline, int rebalanceN)
     {
      m_enabled = enabled;
      m_baselineWinRate = baseline;
      m_rebalanceEvery = MathMax(1, rebalanceN);
     }

   //--- Called on every campaign close. Returns true if thresholds
   //    should be re-applied this close (caller writes back to params).
   bool OnCampaignClose(double currentWinRate, DecisionParams &p)
     {
      if(!m_enabled) return false;
      m_closedSinceCheck++;
      m_lastWinRate = currentWinRate;
      if(m_closedSinceCheck < m_rebalanceEvery) return false;
      m_closedSinceCheck = 0;

      double delta = currentWinRate - m_baselineWinRate;
      double step  = (MathAbs(delta) > 0.10) ? 3.0 : 1.5;   // bigger step when far off

      if(delta < -0.05)
        {
         //-- degrading → tighten thresholds
         p.enterMinLife       = MathMin(p.enterMinLife       + step, m_lifeFloorMax);
         p.enterMinStability  = MathMin(p.enterMinStability  + step, m_stabFloorMax);
         p.enterMinConf       = MathMin(p.enterMinConf       + step, m_confFloorMax);
         p.narrAlignMin       = MathMin(p.narrAlignMin       + step, m_narrFloorMax);
        }
      else if(delta > 0.05)
        {
         //-- improving → ease thresholds (slightly)
         p.enterMinLife       = MathMax(p.enterMinLife       - step * 0.5, m_lifeFloorMin);
         p.enterMinStability  = MathMax(p.enterMinStability  - step * 0.5, m_stabFloorMin);
         p.enterMinConf       = MathMax(p.enterMinConf       - step * 0.5, m_confFloorMin);
         p.narrAlignMin       = MathMax(p.narrAlignMin       - step * 0.5, m_narrFloorMin);
        }
      OmegaLogger::LogInfo("EVOLUTION",
         StringFormat("Adapt · winRate=%.2f vs baseline=%.2f · life=%.0f stab=%.0f conf=%.0f narr=%.0f",
                       currentWinRate, m_baselineWinRate,
                       p.enterMinLife, p.enterMinStability, p.enterMinConf, p.narrAlignMin));
      return true;
     }

   double LastWinRate() const { return m_lastWinRate; }
   bool   Enabled()     const { return m_enabled; }
  };

#endif // __OMEGA_SELF_EVOLUTION_MQH__//================== INPUTS ==========================================
input group "═══ Mode (Layer: Human Override Philosophy) ═══"
input ENUM_OMEGA_MODE     InpMode             = OMEGA_MODE_AUTONOMOUS; // Operating mode (AUTONOMOUS = trade)
input ulong               InpMagic            = 7270001;              // Magic number

input group "═══ Risk (dynamic — driven by Trinity) ═══"
input double              InpBaseRiskPct      = 0.25;                 // Base risk per trade (%)
input double              InpNormalRiskPct    = 0.50;                 // Normal narrative (%)
input double              InpStrongRiskPct    = 1.00;                 // Strong narrative (%)
input double              InpExcepRiskPct     = 2.00;                 // Exceptional alignment (%)
input double              InpHardCeilingPct   = 2.00;                 // Per-trade hard ceiling (%)

input group "═══ Phase 5.1 — Equity-Tier Guards (universal sizing) ═══"
input double              InpMinStopAtrMult   = 0.75;                 // Stop-distance floor as ATR× (anti-runaway)
input int                 InpMinStopAtrPeriod = 14;                   // ATR period for stop floor
input double              InpMaxNotionalPct   = 1000.0;               // Per-ticket notional ≤ N% of equity (10× default)
input double              InpMicroTierEquity  = 200.0;                // < this USD → MICRO tier (A+ only)
input double              InpSmallTierEquity  = 1000.0;               // < this USD → SMALL tier (ALIVE+ only)
input double              InpLargeTierEquity  = 50000.0;              // ≥ this USD → LARGE tier (notional caps bite)
input double              InpInstTierEquity   = 500000.0;             // ≥ this USD → INSTITUTIONAL tier
input bool                InpAllowMicroTier   = false;                // EXPLICIT consent: trade <$200 accounts (forced over-risk)
input double              InpMarginUseMaxPct  = 80.0;                 // Pre-trade margin precheck: req ≤ N% free margin

input group "═══ Phase 5.1.1 — Per-Tier Behavior Matrix ═══"
input bool                InpCentAccount      = false;                // CENT account: divide displayed equity by 100 for tier classification
input ENUM_OMEGA_UNDERSIZED InpUndersizedBehavior = UNDERSIZED_AUTO;   // What to do when broker min forces actual > intended
//-- Per-tier risk ceilings (% per ticket)
input double              InpMicroMaxRiskPct  = 8.00;                 // MICRO ceiling — broker min may force this
input double              InpSmallMaxRiskPct  = 3.00;                 // SMALL ceiling — ALIVE-tier or above
input double              InpStdMaxRiskPct    = 1.00;                 // STANDARD ceiling — production
input double              InpLargeMaxRiskPct  = 1.00;                 // LARGE ceiling — production + notional cap
input double              InpInstMaxRiskPct   = 0.75;                 // INSTITUTIONAL ceiling — leverage-bounded
//-- MICRO-only conviction floor (only A+ trades earn a slot)
input double              InpMicroMinLife     = 75.0;                 // MICRO min life
input double              InpMicroMinStab     = 65.0;                 // MICRO min stability
input double              InpMicroMinConf     = 60.0;                 // MICRO min confidence
//-- SMALL-only conviction floor (ALIVE-tier or higher)
input double              InpSmallMinLife     = 60.0;                 // SMALL min life
input double              InpSmallMinStab     = 55.0;                 // SMALL min stability
input double              InpSmallMinConf     = 50.0;                 // SMALL min confidence
//-- Per-tier pyramid budget (max same-side positions per campaign)
input int                 InpMicroMaxBudget   = 1;                    // MICRO — no pyramid
input int                 InpSmallMaxBudget   = 2;                    // SMALL — light
input int                 InpStdMaxBudget     = 3;                    // STANDARD — moderate
input int                 InpLargeMaxBudget   = 4;                    // LARGE — full
input int                 InpInstMaxBudget    = 4;                    // INSTITUTIONAL — full
//-- Per-tier ATR stop multiplier (MICRO wider, larger tighter)
input double              InpMicroStopAtr     = 1.25;                 // MICRO — wider stops, fewer stop-outs
input double              InpSmallStopAtr     = 0.85;                 // SMALL — slightly wider
input double              InpStdStopAtr       = 0.75;                 // STANDARD — production
input double              InpLargeStopAtr     = 0.75;                 // LARGE — production
input double              InpInstStopAtr      = 0.75;                 // INSTITUTIONAL — production

input group "═══ Phase 5.5 — On-Chart Diagnostics ═══"
input bool                InpChartEnabled     = true;                 // Master toggle for chart visualization
input bool                InpChartHUD         = true;                 // Top-left HUD panel (Trinity, tier, verdict)
input bool                InpChartMTFMap      = true;                 // Top-right MTF map (per-TF dir + state)
input bool                InpChartOwnerBox    = true;                 // Owner-curve box (origin → extreme)
input bool                InpChartFlipZone    = true;                 // Flip zone box (chart TF ft/fb)
input bool                InpChartBudgetTgt   = true;                 // Budget target arrow (current px → owner.extreme)
input bool                InpChartFUMarks     = true;                 // FU spike marks on rejection candles
input bool                InpChartPositions   = true;                 // Per-position arrows + labels at entry bars
input string              InpChartPrefix      = "OMEGA";              // Object-name prefix (so multiple EAs don't clash)

input group "═══ Capital — drawdown circuit breakers ═══"
input double              InpDailyLossLimit   = 3.0;                  // Daily loss limit (%)
input double              InpWeeklyLossLimit  = 8.0;                  // Weekly loss limit (%)
input double              InpHardLimit        = 15.0;                 // Hard kill switch (%)

input group "═══ Logging ═══"
input ENUM_OMEGA_LOG_LEVEL InpLogLevel        = LOG_INFO;              // Log verbosity

input group "═══ Engine ═══"
input int                 InpHeartbeatSec     = 5;                    // Heartbeat / persistence cadence (s)

input group "═══ Curve physics (Phase 2) ═══"
input int                 InpAtrLen           = 14;                   // ATR length
input int                 InpEffLen           = 10;                   // Efficiency lookback
input double              InpEffThresh        = 0.65;                 // Efficiency threshold
input double              InpDispThresh       = 1.5;                  // Displacement threshold (ATR)
input double              InpConvMult         = 0.01;                 // Convexity multiplier (ATR)
input int                 InpPivotLen         = 5;                    // Pivot length
input int                 InpStructLen        = 10;                   // Structure pivot length (warmup bars)
input double              InpImpulseMult      = 1.5;                  // Impulse ATR multiple
input double              InpChochBufATR      = 0.75;                 // CHoCH buffer (ATR)

input group "═══ Decision thresholds (Phase 5 — production) ═══"
input double              InpEnterMinLife     = 45.0;                 // Min life to ENTER (HOLDING regime)
input double              InpEnterMinStab     = 45.0;                 // Min stability to ENTER
input double              InpEnterMinConf     = 40.0;                 // Min confidence to ENTER
input double              InpAttackMinLife    = 60.0;                 // Min life for ALIVE (strong) entries
input double              InpAttackMinStab    = 60.0;                 // Min stability for ALIVE entries
input double              InpAttackMinConf    = 55.0;                 // Min confidence for ALIVE entries
input double              InpReverseMinConf   = 50.0;                 // Min confidence to FLIP on dead
input int                 InpEnterMinAlign    = 4;                    // (legacy / info only) TF-count for HUD info row
input double              InpNarrativeAlignmentMin = 65.0;            // Narrative coherence floor (canonical gate, 0..100)
input int                 InpMaxBudget        = 4;                    // Max positions per campaign
input double              InpDefaultSlAtrMult = 1.5;                  // Fallback SL = N × ATR
input double              InpReduceLifeFloor  = 38.0;                 // Below this: REDUCE if profitable

input group "═══ Meta (Phase 6) ═══"
input double              InpSelfTrustBlend   = 0.30;                 // Self-trust blend into Confidence (0..1)

input group "═══ Backtest / Shadow (Phase 7) ═══"
input string              InpShadowTag        = "";                   // Shadow tag (empty=disable)

input group "═══ Phase 5.2 — FTMO / Funded Account Mode ═══"
input bool                InpFundedMode          = false;             // Master toggle for funded-account overlay
input ENUM_OMEGA_FUNDED_FIRM InpFundedFirm       = FUNDED_FTMO;       // Firm preset (auto-fills DD / target rules)
input double              InpFundedDailyDDPct    = 5.0;               // Custom: daily DD limit (%)
input double              InpFundedTotalDDPct    = 10.0;              // Custom: total DD limit (%)
input double              InpFundedTargetPct     = 10.0;              // Custom: profit target to pass eval (%)
input double              InpFundedDailyHaltPct  = 4.0;               // Engine-halt buffer below firm daily limit
input double              InpFundedTotalHaltPct  = 8.0;               // Engine-halt buffer below firm total limit
input double              InpFundedPostTargetMult= 0.25;              // Risk multiplier after target hit
input double              InpFundedDailyMaxProfit= 50.0;              // Consistency: max single-day profit % of target
input bool                InpFundedWeekendFlat   = true;              // Auto-flat at Friday close
input int                 InpFundedFridayCloseGmt= 21;                // Friday close hour (GMT)
input bool                InpFundedNewsBlackout  = true;              // Pause around high-impact news
input int                 InpFundedNewsMin       = 30;                // News blackout window (min)

input group "═══ Phase 9 — Memory Replay (campaign archive) ═══"
input bool                InpMemoryEnabled       = true;              // Write + read campaign archive on disk
input string              InpMemoryFolder        = "OmegaMemory";     // Subfolder under MQL5/Files/

input group "═══ Phase 11 — Portfolio (cross-symbol guard) ═══"
input bool                InpPortfolioEnabled    = true;              // Cap aggregate exposure across symbols
input double              InpPortfolioMaxAggLev  = 2500.0;             // Max aggregate notional as % of equity (25× default)

input group "═══ Phase 13 — Self-Evolution (adaptive thresholds) ═══"
input bool                InpSelfEvolutionEnabled= false;             // ENABLE adaptive threshold drift
input double              InpEvolutionBaseline   = 0.55;              // Target win-rate (engine adapts vs this)
input int                 InpEvolutionRebalanceN = 5;                 // Re-check every N closed campaigns

//================== GLOBALS =========================================
OmegaState        g_state;
OmegaCapital      g_capital;
OmegaRisk         g_risk;
CampaignDB        g_db;
CampaignPositions g_positions;   // Phase 5: campaign-aware position manager
OmegaExecution    g_exec;
OmegaCurve        g_curve;       // Phase 2: multi-TF perception
OmegaParticipants g_part;        // Phase 8: Fib zones + FU/flip engine
OmegaStory        g_story;       // Phase 4: narrative engine
OmegaMeta         g_meta;        // Phase 6: probability + self-observation + regime
OmegaNewsCalendar g_news;        // Phase 7: optional CSV calendar
ShadowLogger      g_shadow;      // Phase 7: optional parallel logger
DecisionParams    g_dparams;     // Phase 5: decision tunables
//-- Phase 5.5: g_chart, g_lastDecision, g_lastReason are declared at file
//   scope right after the Chart module so class methods (e.g.
//   CampaignPositions::Open) can reference them without forward-decl issues.
//-- Phases 5.2 / 9 / 10..14 — globals
OmegaFunded         g_funded;       // Phase 5.2 — FTMO funded mode
CampaignArchive     g_archive;      // Phase 9   — campaign memory + similarity
OmegaExplain        g_explain;      // Phase 14  — decision trace ring
OmegaAttention      g_attention;    // Phase 10  — focus engine
OmegaPortfolio      g_portfolio;    // Phase 11  — cross-symbol exposure
OmegaMetaChain      g_metaChain;    // Phase 12  — campaigns of campaigns
OmegaSelfEvolution  g_evolution;    // Phase 13  — adaptive thresholds
datetime       g_lastHeartbeat = 0;
long           g_tickCount     = 0;
//-- Phase 5.1.1 tier-shift tracking (logs on >20% equity move OR tier change)
ENUM_OMEGA_TIER g_lastTier        = TIER_STANDARD;
double          g_lastTierEquity  = 0.0;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- 1. Logger (everything else logs through it)
   OmegaLogger::Init(InpLogLevel);
   OmegaLogger::LogInfo("EA", StringFormat(
      "F72 OMEGA %s · symbol=%s · mode=%s · magic=%I64u · build=%d",
      OMEGA_VERSION, _Symbol, OmegaStr::ModeToString(InpMode), InpMagic,
      (int)TerminalInfoInteger(TERMINAL_BUILD)));

//--- 2. Trinity (state container)
   g_state.Reset();
   OmegaLogger::LogInfo("EA", "Trinity initialized neutral · " + g_state.Snapshot());

//--- 3. Capital state machine
   g_capital.Init(InpDailyLossLimit, InpWeeklyLossLimit, InpHardLimit);

//--- 4. Risk
   g_risk.Init(InpBaseRiskPct, InpNormalRiskPct, InpStrongRiskPct,
                InpExcepRiskPct, InpHardCeilingPct);
   //--- 4.1 Phase 5.1 — install equity-tier guards.
   g_risk.InitGuards(InpMinStopAtrMult, InpMinStopAtrPeriod, InpMaxNotionalPct,
                     InpMicroTierEquity, InpSmallTierEquity,
                     InpLargeTierEquity, InpInstTierEquity,
                     InpAllowMicroTier, InpMarginUseMaxPct);
   //--- 4.2 Phase 5.1.1 — install per-tier behavior matrix.
   g_risk.InitTiers(InpMicroMaxRiskPct, InpSmallMaxRiskPct, InpStdMaxRiskPct,
                    InpLargeMaxRiskPct, InpInstMaxRiskPct,
                    InpMicroMinLife, InpMicroMinStab, InpMicroMinConf,
                    InpSmallMinLife, InpSmallMinStab, InpSmallMinConf,
                    InpMicroMaxBudget, InpSmallMaxBudget, InpStdMaxBudget,
                    InpLargeMaxBudget, InpInstMaxBudget,
                    InpMicroStopAtr, InpSmallStopAtr, InpStdStopAtr,
                    InpLargeStopAtr, InpInstStopAtr,
                    InpCentAccount, (int)InpUndersizedBehavior);
   {
      double _eqRaw = AccountInfoDouble(ACCOUNT_EQUITY);
      double _eqEff = InpCentAccount ? (_eqRaw / 100.0) : _eqRaw;
      ENUM_OMEGA_TIER _tNow = g_risk.TierFor(_eqEff);
      g_lastTier = _tNow;
      g_lastTierEquity = _eqEff;
      OmegaLogger::LogInfo("EA",
         StringFormat("Equity tier on init: %s · raw=%.2f %s%s · effective=%.2f · cap=%.2f%%",
                       g_risk.TierStr(_tNow), _eqRaw,
                       AccountInfoString(ACCOUNT_CURRENCY),
                       InpCentAccount ? " (cent)" : "",
                       _eqEff, g_risk.TierMaxRiskPct(_tNow)));
   }

//--- 5. Campaign memory
   g_db.Init();

//--- 6. Execution shell + Position manager (Phase 5).
//    Init order: exec first (creates trade shell), then positions
//    (uses exec.TradeShell()), then exec.SetPositions(...) wires the
//    decision-handling path to the position manager.
   g_exec.Init(InpMode, InpMagic, GetPointer(g_capital), GetPointer(g_risk), GetPointer(g_db));
   g_positions.Init(_Symbol, InpMagic, g_exec.TradeShell(),
                     GetPointer(g_capital), GetPointer(g_risk), GetPointer(g_db));
   g_exec.SetPositions(GetPointer(g_positions));

   //--- Phase 5: write tunable decision thresholds from inputs into g_dparams.
   g_dparams.enterMinLife      = InpEnterMinLife;
   g_dparams.enterMinStability = InpEnterMinStab;
   g_dparams.enterMinConf      = InpEnterMinConf;
   g_dparams.attackMinLife     = InpAttackMinLife;
   g_dparams.attackMinStab     = InpAttackMinStab;
   g_dparams.attackMinConf     = InpAttackMinConf;
   g_dparams.reverseMinConf    = InpReverseMinConf;
   g_dparams.enterMinAlign     = InpEnterMinAlign;
   g_dparams.narrAlignMin      = InpNarrativeAlignmentMin;
   g_dparams.maxBudget         = InpMaxBudget;
   g_dparams.defaultSlAtrMult  = InpDefaultSlAtrMult;
   g_dparams.reduceLifeFloor   = InpReduceLifeFloor;
   OmegaLogger::LogInfo("EA",
      StringFormat("Decision thresholds: enterLife=%.0f stab=%.0f conf=%.0f · attackLife=%.0f stab=%.0f conf=%.0f · align=%d/6 · budget=%d · slAtr=%.1f",
                    InpEnterMinLife, InpEnterMinStab, InpEnterMinConf,
                    InpAttackMinLife, InpAttackMinStab, InpAttackMinConf,
                    InpEnterMinAlign, InpMaxBudget, InpDefaultSlAtrMult));

//--- 7. Perception (Phase 2): multi-TF curve engine.
   if(!g_curve.Init(_Symbol, (ENUM_TIMEFRAMES)_Period,
                     InpPivotLen, InpStructLen, InpImpulseMult, InpChochBufATR,
                     InpAtrLen, InpEffLen, InpEffThresh, InpDispThresh, InpConvMult))
     {
      OmegaLogger::LogException("EA", -1, "Curve init failed — perception offline.");
     }

//--- 8. Narrative (Phase 4): LifeScore + NarrativeTracker + ConfidenceTracker.
   g_story.Init(_Symbol);

//--- 8b. Participants (Phase 8): Fib zones + FU/flip engine.
   g_part.Init(_Symbol);

//--- 9. Meta (Phase 6): SelfObservation + Probability cloud + Regime.
   g_meta.Init(InpSelfTrustBlend);
   //--- Phase 5.5: chart visualization (optional, but on by default).
   g_chart.Init(InpChartPrefix, InpChartEnabled,
                InpChartHUD, InpChartMTFMap, InpChartOwnerBox, InpChartFlipZone,
                InpChartBudgetTgt, InpChartFUMarks, InpChartPositions,
                0.30, 5);
   g_chart.SetEntryGates(InpEnterMinAlign);
   g_chart.SetNarrativeAlignMin(InpNarrativeAlignmentMin);

   //--- Phase 5.2 — FTMO / Funded Mode overlay.
   g_funded.Init(InpFundedMode, InpFundedFirm,
                  InpFundedDailyDDPct, InpFundedTotalDDPct, InpFundedTargetPct,
                  InpFundedDailyHaltPct, InpFundedTotalHaltPct,
                  InpFundedPostTargetMult, InpFundedDailyMaxProfit,
                  InpFundedWeekendFlat, InpFundedFridayCloseGmt,
                  InpFundedNewsBlackout, InpFundedNewsMin);

   //--- Phase 9 — Campaign memory archive.
   g_archive.Init(InpMemoryEnabled, InpMemoryFolder);

   //--- Phase 11 — Portfolio guard.
   g_portfolio.Init(InpPortfolioMaxAggLev);

   //--- Phase 13 — Self-evolution.
   g_evolution.Init(InpSelfEvolutionEnabled, InpEvolutionBaseline, InpEvolutionRebalanceN);

//--- 10. News calendar (Phase 7, optional).
   g_news.Load();

//--- 11. Shadow logger (Phase 7, optional).
   if(InpShadowTag != "")
      g_shadow.Init(InpShadowTag);

//--- 12. Heartbeat
   EventSetTimer(MathMax(1, InpHeartbeatSec));

   OmegaLogger::LogInfo("EA",
      "Phases 1-7 online · Trinity LIVE · Engine ready to trade in mode " +
      OmegaStr::ModeToString(InpMode));
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_shadow.Shutdown();
   g_chart.Deinit();
   g_curve.Deinit();
   OmegaLogger::LogInfo("EA",
      StringFormat("Shutting down · reason=%d · ticks=%I64d", reason, g_tickCount));
   OmegaLogger::Flush();
   OmegaLogger::Shutdown();
  }

//+------------------------------------------------------------------+
//| OnTester — strategy-tester optimisation fitness                  |
//+------------------------------------------------------------------+
double OnTester()
  {
   return Optimization::OnTesterDefault();
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_tickCount++;
   g_state.tickCount = g_tickCount;
   g_state.updated   = TimeCurrent();

//--- Phase 5.1.1: tier-shift detection. Re-resolve tier; log a
//    transition line whenever the tier changes OR the effective
//    equity moves >20% from the last anchor. Cheap (no allocations).
   {
      double _eqRaw = AccountInfoDouble(ACCOUNT_EQUITY);
      double _eqEff = InpCentAccount ? (_eqRaw / 100.0) : _eqRaw;
      ENUM_OMEGA_TIER _tNow = g_risk.TierFor(_eqEff);
      bool _tierChanged = (_tNow != g_lastTier);
      bool _bigMove = (g_lastTierEquity > 0.0)
                       ? (MathAbs(_eqEff - g_lastTierEquity) / g_lastTierEquity > 0.20)
                       : false;
      if(_tierChanged || _bigMove)
        {
         OmegaLogger::LogInfo("EA",
            StringFormat("Tier shift · %s → %s · equity %.2f → %.2f%s · cap=%.2f%% · pyramid=%d",
                          g_risk.TierStr(g_lastTier), g_risk.TierStr(_tNow),
                          g_lastTierEquity, _eqEff,
                          InpCentAccount ? " (cent-corrected)" : "",
                          g_risk.TierMaxRiskPct(_tNow),
                          g_risk.TierMaxBudget(_tNow)));
         g_lastTier       = _tNow;
         g_lastTierEquity = _eqEff;
        }
     }

//--- Capital state machine — runs even before perception exists,
//    so circuit breakers protect equity from any external losses
//    on the account during testing.
   g_capital.Update();

//--- Phase 5.2 — FTMO funded watchdog. Returns trip state; if a
//    rule has fired, suppress new entries (and optionally close all).
   ENUM_OMEGA_FUNDED_TRIP fundedTrip = g_funded.Update(g_news);
   if(g_funded.RequiresFlat() && g_positions.CountActive() > 0)
     {
      g_positions.CloseAll(0, REASON_HARD_LIMIT,
                            "Funded rule trip: " + g_funded.TripReason());
      OmegaLogger::LogWarning("FUNDED",
         "Flat-all triggered · " + g_funded.TripReason());
     }

//--- Phase 11 — Portfolio refresh (counts open positions across all symbols).
   g_portfolio.Update(AccountInfoDouble(ACCOUNT_EQUITY));

//--- Phase 10 — Attention (cheap, every tick).
   g_attention.Update(g_state, g_curve);

//--- Phase 2: drive the multi-TF curve engine. Each CurveState
//    consumes its own bar-close events and updates per-TF
//    structure / physics. The curve writes the supporting fields,
//    DeriveTrinity() folds them upward.
   if(g_curve.Update())
     {
      g_curve.DeriveSupporting(g_state.supporting);
      g_state.primed = g_curve.primed;

      //--- Phase 8: participants + flip engines run after curve+tree,
      //    before narrative — they expose participantStability /
      //    flipQuality which the narrative then folds into stability.
      g_part.Update(g_curve, g_state);

      //--- Phase 4: narrative reads curve+tree and writes life/stability/
      //    confidence DIRECTLY into g_state. DeriveTrinity is now a clamp.
      bool storyAdvanced = g_story.Update(g_state, g_curve);
      g_state.DeriveTrinity();

      //--- Phase 6: meta layer overlays Self-Observation, Probability,
      //    Regime ON TOP of Story's trinity. Confidence gets blended
      //    with SelfTrust; supporting.regime + probability cloud now live.
      if(storyAdvanced)
        {
         g_meta.Update(g_state, g_curve, g_story);
         g_state.DeriveTrinity();
        }

      //--- Phase 5: each closed bar, ask the decision engine, route the
      //    answer through Execution → CampaignPositions, then trail stops.
      if(storyAdvanced)
        {
         int activeSame    = g_positions.CountActive(g_curve.tree.ownerDir);
         int activeCounter = g_positions.CountActive(-g_curve.tree.ownerDir);
         DecisionResult dr = DecisionEngine::Decide(g_state, g_curve, g_story,
                                                     activeSame, activeCounter, g_dparams);
         dr.stopDistPoints = DecisionEngine::ComputeStopDistPoints(_Symbol, g_curve,
                              dr.suggestedDirection != 0 ? dr.suggestedDirection : g_curve.tree.ownerDir,
                              g_dparams);
         long campaignId = (g_curve.tree.ownerIndex >= 0)
                            ? g_curve.tree.tree[g_curve.tree.ownerIndex].id : 0;

         //--- Phase 5.2 — funded mode: suppress new entries when a rule has tripped.
         //--- Phase 11 — portfolio: also suppress when aggregate leverage hard-cap hit.
         bool isEntry = (dr.decision == OMEGA_DEC_ENTER_LONG ||
                          dr.decision == OMEGA_DEC_ENTER_SHORT ||
                          dr.decision == OMEGA_DEC_ADD ||
                          dr.decision == OMEGA_DEC_REVERSE);
         if(isEntry)
           {
            if(g_funded.BlocksEntries())
              {
               OmegaLogger::LogWarning("FUNDED",
                  "Entry suppressed · " + g_funded.TripStr() + " · " + g_funded.TripReason());
               dr.decision = OMEGA_DEC_OBSERVE;
               dr.reason   = REASON_HARD_LIMIT;
               dr.detail   = "funded mode: " + g_funded.TripReason();
              }
            else if(g_portfolio.CapMultiplier() <= 0.001)
              {
               OmegaLogger::LogWarning("PORTFOLIO",
                  StringFormat("Entry suppressed · aggLev %.0f%% >= cap %.0f%%",
                                g_portfolio.AggLeveragePct(), g_portfolio.MaxAggLevPct()));
               dr.decision = OMEGA_DEC_OBSERVE;
               dr.reason   = REASON_HARD_LIMIT;
               dr.detail   = "portfolio cap reached";
              }
           }

         g_meta.RecordDecision(dr.decision);
         g_exec.HandleDecision(_Symbol, dr.decision, dr.reason, g_state,
                                dr.stopDistPoints, dr.detail,
                                dr.suggestedRole, dr.suggestedDirection, campaignId,
                                dr.conviction, dr.evWith);
         //--- Phase 5.5: keep the most recent verdict for the HUD readout.
         g_lastDecision = dr.decision;
         g_lastReason   = dr.reason;
         //--- Phase 14 — explainability: record every decision in the trace ring.
         g_explain.Record((int)dr.decision, (int)dr.reason, g_state, dr.detail);
         //--- Phase 9.1 — campaign archive open hook.
         if(isEntry && campaignId > 0)
           {
            g_archive.OnCampaignOpen(campaignId,
                                      dr.suggestedDirection != 0 ? dr.suggestedDirection : g_curve.tree.ownerDir,
                                      (int)g_risk.TierForCap(g_capital),
                                      g_state, g_state.supporting.forceScore,
                                      g_state.supporting.regime,
                                      AccountInfoDouble(ACCOUNT_EQUITY));
           }
         g_positions.BarUpdate(g_state, g_curve);
         g_shadow.Log(dr.decision, dr.reason, g_state.life, g_state.stability,
                       g_state.confidence, dr.detail);
        }
     }
   else g_state.DeriveTrinity();

   //-- per-tick: update MFE/MAE on every position
   g_positions.TickUpdate();

   //-- Phase 5.5: refresh chart visualization every tick (cheap; objects
   //   are re-positioned in place, no per-tick allocation).
   //-- Phase 5.5: refresh chart visualization every tick (cheap; objects
   //   are re-positioned in place, no per-tick allocation).
   g_chart.Update(g_state, g_curve, g_risk, g_capital, g_story,
                   g_lastDecision, g_lastReason);

   //-- Phase 5.5.4: build supplementary phases-status strings and pass
   //   them to the chart. Done in EA scope so the chart class doesn't
   //   need the late-declared phase types in its method signatures.
   {
      string fundedLine, memLine, attLine, portLine, metaLine, evolLine, exLine;
      if(g_funded.Enabled())
         fundedLine = StringFormat("Funded[%s] dDD %.2f%%/halt %.1f · tDD %.2f%%/halt %.1f · tgt %.1f%% %s · %s",
                                    g_funded.FirmStr(), g_funded.DailyDdPct(), g_funded.DailyHaltPct(),
                                    g_funded.TotalDdPct(), g_funded.TotalHaltPct(), g_funded.TargetPct(),
                                    g_funded.TargetHit() ? "HIT" : "—", g_funded.TripStr());
      else
         fundedLine = "Funded: OFF";
      memLine  = StringFormat("Memory: %d archived · %d in-flight",
                               g_archive.Count(), g_archive.PendingCount());
      attLine  = StringFormat("Attention: %5.1f · %s",
                               g_attention.Score(), g_attention.Dominant());
      portLine = StringFormat("Portfolio: %d pos · aggLev %.0f%% (cap %.0f%%) · cor %d · cap×%.2f",
                               g_portfolio.TotalPositions(), g_portfolio.AggLeveragePct(),
                               g_portfolio.MaxAggLevPct(), g_portfolio.Correlated(),
                               g_portfolio.CapMultiplier());
      metaLine = StringFormat("Meta-Chain: W%d L%d · winRate %.0f%% · mult ×%.2f",
                               g_metaChain.StreakWins(), g_metaChain.StreakLosses(),
                               g_metaChain.WinRate() * 100.0, g_metaChain.Multiplier());
      evolLine = StringFormat("Evolution: %s · winRate %.0f%%",
                               g_evolution.Enabled() ? "ON" : "off",
                               g_evolution.LastWinRate() * 100.0);
      ExplainEntry recent[];
      int n = g_explain.RecentN(1, recent);
      if(n > 0)
        {
         exLine = StringFormat("Last: %s · L%.0f S%.0f C%.0f N%.0f · %s",
                                OmegaStr::DecisionToString((ENUM_OMEGA_DECISION)recent[0].decision),
                                recent[0].life, recent[0].stab, recent[0].conf, recent[0].narrAlign,
                                recent[0].why);
         if(StringLen(exLine) > 75) exLine = StringSubstr(exLine, 0, 74);
        }
      else
         exLine = "Last: (no decisions yet)";
      g_chart.UpdatePhasesPanel(fundedLine, memLine, attLine, portLine,
                                 metaLine, evolLine, exLine);
   }
  }

//+------------------------------------------------------------------+
//| OnTimer — heartbeat & explainability                             |
//+------------------------------------------------------------------+
void OnTimer()
  {
   datetime now = TimeCurrent();
   if(g_lastHeartbeat == 0 || (now - g_lastHeartbeat) >= InpHeartbeatSec)
     {
      g_lastHeartbeat = now;

      OmegaLogger::LogInfo("HEARTBEAT", StringFormat(
         "%s · cap=%s · dd(d/w/hard)=%.2f%%/%.2f%%/%.2f%% · throttle=%.2f · session=%s · news=%s · %s · curve[%s] · story[%s] · pos[%s] · %s · %s",
         _Symbol,
         OmegaStr::CapitalStateToString(g_capital.State()),
         g_capital.DailyDrawdownPct(),
         g_capital.WeeklyDrawdownPct(),
         g_capital.HardDrawdownPct(),
         g_capital.Throttle(),
         OmegaStr::SessionToString(OmegaSession::Current()),
         g_news.CurrentEnvironment(),
         g_state.Snapshot(),
         g_curve.Snapshot(),
         g_story.Snapshot(),
         g_positions.Snapshot(),
         g_meta.Snapshot(),
         g_part.Snapshot()));

      //--- Phase 2: emit a HEARTBEAT decision so the explainability path
      //    keeps logging trinity + curve snapshot every interval. Once
      //    Phase 4 wires Narrative + LifeScore, real ENTER/HOLD/EXIT
      //    decisions emerge per tick from the trinity.
      ENUM_OMEGA_REASON reason = g_state.primed ? REASON_HEARTBEAT : REASON_PHASE_NOT_BUILT;
      g_exec.HandleDecision(_Symbol, OMEGA_DEC_OBSERVE, reason,
                             g_state, 0,
                             g_curve.primed
                              ? "Curve primed — narrative / chain pending Phase 3-4"
                              : "Curve warming up — waiting for chart-TF readiness");

      OmegaLogger::Flush();
     }
  }

//+------------------------------------------------------------------+
//| OnTradeTransaction — precise order tracking                      |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
//--- Phase 1: log every deal. Phase 5 will tie deals to campaign
//    positions and update PositionHealth.
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      OmegaLogger::LogInfo("TRADE", StringFormat(
         "Deal #%I64u · symbol=%s · type=%d · vol=%.2f · price=%.5f · order=#%I64u",
         trans.deal, trans.symbol, (int)trans.deal_type, trans.volume,
         trans.price, trans.order));
     }
   else if(trans.type == TRADE_TRANSACTION_ORDER_ADD)
     {
      OmegaLogger::LogInfo("TRADE", StringFormat(
         "Order added · #%I64u · symbol=%s · type=%d",
         trans.order, trans.symbol, (int)trans.order_type));
     }
   else if(trans.type == TRADE_TRANSACTION_ORDER_DELETE)
     {
      OmegaLogger::LogInfo("TRADE", StringFormat(
         "Order removed · #%I64u · symbol=%s",
         trans.order, trans.symbol));
     }
  }
//+------------------------------------------------------------------+
