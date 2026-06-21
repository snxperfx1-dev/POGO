//+------------------------------------------------------------------+
//|                                                    F72_Omega.mq5 |
//|                                                        F72 OMEGA |
//|                                                                  |
//|       *** SINGLE-FILE BUNDLE — Phase 1 + Phase 2 ***             |
//|                                                                  |
//|   This file contains every module of the F72 OMEGA engine        |
//|   inlined in dependency order. To reproduce the modular layout,  |
//|   see MT5/F72_Omega/ in the repo (recommended for editing).      |
//|                                                                  |
//|   "Is the story still alive?"                                    |
//+------------------------------------------------------------------+
#property copyright "F72 OMEGA"
#property version   "1.00"
#property strict
#property description "F72 OMEGA — multi-timeframe curve organism."
#property description "Phase 1 + 2 bundled: skeleton + perception."
#property description "Trinity: LifeScore · StoryStability · StoryConfidence."

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
//   OBSERVER   — engine perceives, no orders, only scores logged
//   COPILOT    — engine suggests, human approves (Phase 5+)
//   AUTONOMOUS — engine controls fully
//   PAPER      — decisions logged, no orders sent (back-test friendly)
//   SHADOW     — engine runs in parallel to live trading, compares
//===================================================================
enum ENUM_OMEGA_MODE
  {
   OMEGA_MODE_OBSERVER     = 0,
   OMEGA_MODE_COPILOT      = 1,
   OMEGA_MODE_AUTONOMOUS   = 2,
   OMEGA_MODE_PAPER        = 3,
   OMEGA_MODE_SHADOW       = 4
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
#define OMEGA_VERSION                "1.0.0-phase1"
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
      switch(m)
        {
         case OMEGA_MODE_OBSERVER:    return "OBSERVER";
         case OMEGA_MODE_COPILOT:     return "COPILOT";
         case OMEGA_MODE_AUTONOMOUS:  return "AUTONOMOUS";
         case OMEGA_MODE_PAPER:       return "PAPER";
         case OMEGA_MODE_SHADOW:      return "SHADOW";
        }
      return "UNKNOWN";
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
      //-- LifeScore: Layer 6 + 7 + 5 + 5 (force, ownership, chain, compression)
      life = OmegaMath::Clamp(
         supporting.forceScore           * 0.35 +
         supporting.ownershipStability   * 0.25 +
         supporting.chainHealth          * 0.25 +
         supporting.compression          * 0.15,
         0.0, 100.0);
      //-- StoryStability: Layer 3 + 8 + 9 (alignment, narrative, regime)
      stability = OmegaMath::Clamp(
         supporting.alignment            * 0.40 +
         supporting.narrative            * 0.40 +
         supporting.regime               * 0.20,
         0.0, 100.0);
      //-- StoryConfidence is OWNED by SelfObservation; clamp only here
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
//|   Layer 10 context. Informational ONLY in Phase 1.               |
//|   The interface intentionally does NOT expose a blackout. The    |
//|   engine's "should I trade through this?" logic emerges in       |
//|   Phase 6 from regime/confidence — not from a hard news veto.    |
//|                                                                  |
//|   Phase 7 will wire a feed (calendar parser or webhook) into     |
//|   Environment() / Severity() and stamp campaigns with the        |
//|   environment they were born in.                                 |
//+------------------------------------------------------------------+
#ifndef __OMEGA_NEWS_MQH__
#define __OMEGA_NEWS_MQH__


class OmegaNews
  {
public:
   //--- "NORMAL" / "PRE_HIGH_IMPACT" / "POST_HIGH_IMPACT" / "QUIET"
   static string Environment() { return "NORMAL"; }
   //--- 0..100 severity placeholder
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


class OmegaRisk
  {
private:
   double m_base;
   double m_normal;
   double m_strong;
   double m_exceptional;
   double m_hardCeiling;

public:
                     OmegaRisk()
     {
      m_base        = 0.25;
      m_normal      = 0.50;
      m_strong      = 1.00;
      m_exceptional = 2.00;
      m_hardCeiling = 2.00;
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

   //--- Conviction tier from the trinity. Conservative by design;
   //    Phase 6 SelfObservation tunes these against campaign memory.
   double RiskPctFor(const OmegaState &s) const
     {
      if(!s.primed)
         return m_base;
      if(s.life >= 75 && s.stability >= 75 && s.confidence >= 70)
         return m_exceptional;
      if(s.life >= 60 && s.stability >= 60 && s.confidence >= 55)
         return m_strong;
      if(s.life >= 45 && s.stability >= 45 && s.confidence >= 40)
         return m_normal;
      return m_base;
     }

   //--- Convert risk% + stop distance to broker-normalized lots.
   //    Returns 0 lots if any input is invalid (which suppresses entry).
   double LotsFor(string symbol, double riskPct, double stopDistPoints, const OmegaCapital &cap) const
     {
      riskPct = OmegaMath::Clamp(riskPct, 0.0, m_hardCeiling);
      double throttle = cap.Throttle();
      double effectivePct = riskPct * throttle;
      if(effectivePct <= 0.0) return 0.0;

      double equity = cap.Equity();
      double riskMoney = equity * effectivePct / 100.0;

      double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(tickSize <= 0 || tickValue <= 0 || point <= 0 || stopDistPoints <= 0) return 0.0;

      double lossPerLot = (stopDistPoints * point / tickSize) * tickValue;
      if(lossPerLot <= 0) return 0.0;

      double lots = riskMoney / lossPerLot;

      double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      if(stepLot <= 0) stepLot = 0.01;
      lots = MathFloor(lots / stepLot) * stepLot;
      lots = OmegaMath::Clamp(lots, minLot, maxLot);
      return lots;
     }

   //--- accessors
   double Base()        const { return m_base; }
   double Normal()      const { return m_normal; }
   double Strong()      const { return m_strong; }
   double Exceptional() const { return m_exceptional; }
   double HardCeiling() const { return m_hardCeiling; }
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
      m_mode        = OMEGA_MODE_OBSERVER;
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

   //--- BUY
   bool Buy(string symbol, double lots, double sl, double tp, ENUM_OMEGA_REASON reason, string detail)
     {
      double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(LiveMode())
        {
         bool ok = m_trade.Buy(lots, symbol, price, sl, tp, detail);
         OmegaLogger::LogExecution(symbol, "BUY", m_trade.ResultOrder(),
                                    m_trade.ResultPrice(), lots, reason,
            StringFormat("live=%s ret=%u %s", ok?"true":"false",
                         m_trade.ResultRetcode(), detail));
         return ok;
        }
      ulong ticket = ++m_paperTicket;
      OmegaLogger::LogExecution(symbol, "BUY-PAPER", ticket, price, lots, reason,
         StringFormat("sl=%.5f tp=%.5f %s", sl, tp, detail));
      return true;
     }

   //--- SELL
   bool Sell(string symbol, double lots, double sl, double tp, ENUM_OMEGA_REASON reason, string detail)
     {
      double price = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(LiveMode())
        {
         bool ok = m_trade.Sell(lots, symbol, price, sl, tp, detail);
         OmegaLogger::LogExecution(symbol, "SELL", m_trade.ResultOrder(),
                                    m_trade.ResultPrice(), lots, reason,
            StringFormat("live=%s ret=%u %s", ok?"true":"false",
                         m_trade.ResultRetcode(), detail));
         return ok;
        }
      ulong ticket = ++m_paperTicket;
      OmegaLogger::LogExecution(symbol, "SELL-PAPER", ticket, price, lots, reason,
         StringFormat("sl=%.5f tp=%.5f %s", sl, tp, detail));
      return true;
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
//= MODULE: Execution
//= Source: Include/Execution.mqh
//==================================================================
//+------------------------------------------------------------------+
//|                                                    Execution.mqh |
//|                                                        F72 OMEGA |
//|                                                                  |
//|   Layer-15 surface. Receives a (decision, reason, state) triple, |
//|   gates it through the Capital state machine, asks Risk for the  |
//|   conviction-tier-appropriate lot size, and routes it to the     |
//|   PaperTrade shell. EVERYTHING is logged.                        |
//|                                                                  |
//|   Phase 1: only the gate + log path is wired. Actual              |
//|   ENTRY/EXIT/REVERSE/TRANSFER plumbing belongs to Phase 5         |
//|   (CampaignPositions + PositionHealth). The shape is fixed now    |
//|   so later phases plug in without touching the contract.          |
//+------------------------------------------------------------------+
#ifndef __OMEGA_EXECUTION_MQH__
#define __OMEGA_EXECUTION_MQH__


//=== Position roles within a campaign (Layer 5: granularity) =======
enum ENUM_OMEGA_POSITION_ROLE
  {
   POS_ROLE_ORIGIN     = 0,
   POS_ROLE_ENTRY      = 1,
   POS_ROLE_PROGRESS   = 2,
   POS_ROLE_TERMINAL   = 3
  };

class OmegaExecution
  {
private:
   OmegaPaperTrade  m_trade;
   OmegaCapital    *m_capital;
   OmegaRisk       *m_risk;
   CampaignDB      *m_db;

public:
                     OmegaExecution()
     {
      m_capital = NULL;
      m_risk    = NULL;
      m_db      = NULL;
     }

   void Init(ENUM_OMEGA_MODE mode, ulong magic,
             OmegaCapital *capital, OmegaRisk *risk, CampaignDB *db)
     {
      m_trade.Init(mode, magic);
      m_capital = capital;
      m_risk    = risk;
      m_db      = db;
      OmegaLogger::LogInfo("EXEC", "Initialized");
     }

   void SetMode(ENUM_OMEGA_MODE mode) { m_trade.SetMode(mode); }
   ENUM_OMEGA_MODE Mode() const       { return m_trade.Mode(); }

   //--- The single entry point for every decision.
   //    OBSERVE / HOLD log only. Everything else is gated by capital
   //    state, risk-tiered, and routed through the paper shell.
   void HandleDecision(string symbol, ENUM_OMEGA_DECISION dec, ENUM_OMEGA_REASON reason,
                        const OmegaState &state, double stopDistPts, string detail)
     {
      OmegaLogger::LogDecision(symbol, m_trade.Mode(), dec, reason,
                                state.life, state.stability, state.confidence, detail);
      if(dec == OMEGA_DEC_OBSERVE || dec == OMEGA_DEC_HOLD)
         return;

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
      if(cs == CAPITAL_RESTRICTED &&
         (dec == OMEGA_DEC_ENTER_LONG || dec == OMEGA_DEC_ENTER_SHORT || dec == OMEGA_DEC_ADD))
        {
         OmegaLogger::LogDecision(symbol, m_trade.Mode(), OMEGA_DEC_OBSERVE,
                                   REASON_DAILY_LIMIT,
                                   state.life, state.stability, state.confidence,
                                   "Capital RESTRICTED — entry suppressed (managing only)");
         return;
        }

      //--- Risk gate
      if(m_risk == NULL)
        {
         OmegaLogger::LogException("EXEC", -2, "Risk not wired");
         return;
        }
      double riskPct = m_risk.RiskPctFor(state);
      double lots    = m_risk.LotsFor(symbol, riskPct, stopDistPts, m_capital);
      if(lots <= 0)
        {
         OmegaLogger::LogWarning("EXEC",
            StringFormat("%s · zero lots · risk=%.2f%% sd=%.0f", symbol, riskPct, stopDistPts));
         return;
        }

      //--- Phase 1 stub: SL/TP are owned by PositionHealth (Phase 5).
      //    Until then we route entries with sl=0, tp=0 (broker will
      //    accept; PositionHealth will set them post-fill).
      double sl = 0.0, tp = 0.0;

      switch(dec)
        {
         case OMEGA_DEC_ENTER_LONG:
         case OMEGA_DEC_ADD:
            m_trade.Buy(symbol, lots, sl, tp, reason,
                        StringFormat("risk=%.2f%% sd=%.0f %s", riskPct, stopDistPts, detail));
            break;
         case OMEGA_DEC_ENTER_SHORT:
            m_trade.Sell(symbol, lots, sl, tp, reason,
                         StringFormat("risk=%.2f%% sd=%.0f %s", riskPct, stopDistPts, detail));
            break;
         case OMEGA_DEC_REVERSE:
         case OMEGA_DEC_TRANSFER:
         case OMEGA_DEC_REDUCE:
         case OMEGA_DEC_EXIT:
            OmegaLogger::LogInfo("EXEC",
               StringFormat("%s · %s · deferred to Phase 5 (CampaignPositions/PositionHealth)",
                            symbol, OmegaStr::DecisionToString(dec)));
            break;
         default:
            break;
        }
     }
  };

#endif // __OMEGA_EXECUTION_MQH__

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

      gDir         = chart.DirByOrigin();
      gCompression = chart.compIdx;
      gConvexity   = ConvexityHelper::Score(chart);
      gMaturity    = ConvexityHelper::Maturity(chart);
      gForce       = ForceHelper::Score(gCompression, tighten, /*residual*/ 50.0, /*recursion*/ 0);
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
      supp.ownershipStability = OMEGA_TRINITY_NEUTRAL; // Phase 3
      supp.chainHealth        = OMEGA_TRINITY_NEUTRAL; // Phase 3
      supp.recursionDepth     = 0;                    // Phase 3
      supp.recursionBudget    = 1;                    // Phase 3
      //-- alignment: how many of the 6 TFs share the chart's direction
      int sameDir = 0;
      if(gDir != 0)
        {
         if(tfM1.DirByOrigin()  == gDir) sameDir++;
         if(tfM3.DirByOrigin()  == gDir) sameDir++;
         if(tfM5.DirByOrigin()  == gDir) sameDir++;
         if(tfM15.DirByOrigin() == gDir) sameDir++;
         if(tfH1.DirByOrigin()  == gDir) sameDir++;
         if(tfH4.DirByOrigin()  == gDir) sameDir++;
        }
      supp.alignment    = (sameDir / 6.0) * 100.0;
      supp.narrative    = OMEGA_TRINITY_NEUTRAL; // Phase 4
      supp.regime       = OMEGA_TRINITY_NEUTRAL; // Phase 6
      supp.pContinuation= 0; supp.pTerminal = 0; supp.pTransfer = 0; // Phase 6
     }

   //--- short snapshot for heartbeat
   string Snapshot() const
     {
      return StringFormat(
         "dir=%d F=%.0f(%s/%s) C=%.0f X=%.0f mat=%.0f align=M1:%d M3:%d M5:%d M15:%d H1:%d H4:%d",
         gDir, gForce, ForceHelper::StateString(gForceState), gForceTrend,
         gCompression, gConvexity, gMaturity,
         tfM1.DirByOrigin(),  tfM3.DirByOrigin(),  tfM5.DirByOrigin(),
         tfM15.DirByOrigin(), tfH1.DirByOrigin(),  tfH4.DirByOrigin());
     }
  };

#endif // __OMEGA_CURVE_MQH__

//==================================================================
//= MAIN EA BODY (inputs · globals · OnInit/Tick/Timer/Deinit)
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

//================== INPUTS ==========================================
input group "═══ Mode (Layer: Human Override Philosophy) ═══"
input ENUM_OMEGA_MODE     InpMode             = OMEGA_MODE_OBSERVER;  // Operating mode
input ulong               InpMagic            = 7270001;              // Magic number

input group "═══ Risk (dynamic — driven by Trinity) ═══"
input double              InpBaseRiskPct      = 0.25;                 // Base risk per trade (%)
input double              InpNormalRiskPct    = 0.50;                 // Normal narrative (%)
input double              InpStrongRiskPct    = 1.00;                 // Strong narrative (%)
input double              InpExcepRiskPct     = 2.00;                 // Exceptional alignment (%)
input double              InpHardCeilingPct   = 2.00;                 // Per-trade hard ceiling (%)

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
input int                 InpStructLen        = 10;                   // Structure pivot length
input double              InpImpulseMult      = 1.5;                  // Impulse ATR multiple
input double              InpChochBufATR      = 0.75;                 // CHoCH buffer (ATR)

//================== GLOBALS =========================================
OmegaState     g_state;
OmegaCapital   g_capital;
OmegaRisk      g_risk;
CampaignDB     g_db;
OmegaExecution g_exec;
OmegaCurve     g_curve;        // Phase 2: multi-TF perception
datetime       g_lastHeartbeat = 0;
long           g_tickCount     = 0;

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

//--- 5. Campaign memory
   g_db.Init();

//--- 6. Execution shell
   g_exec.Init(InpMode, InpMagic, GetPointer(g_capital), GetPointer(g_risk), GetPointer(g_db));

//--- 7. Perception (Phase 2): multi-TF curve engine.
   if(!g_curve.Init(_Symbol, (ENUM_TIMEFRAMES)_Period,
                     InpPivotLen, InpStructLen, InpImpulseMult, InpChochBufATR,
                     InpAtrLen, InpEffLen, InpEffThresh, InpDispThresh, InpConvMult))
     {
      OmegaLogger::LogException("EA", -1, "Curve init failed — perception offline.");
     }

//--- 8. Heartbeat
   EventSetTimer(MathMax(1, InpHeartbeatSec));

   OmegaLogger::LogInfo("EA",
      "Phase 2 perception online · waiting for chart-TF curve readiness (≈" +
      IntegerToString(InpStructLen) + " bars)");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_curve.Deinit();
   OmegaLogger::LogInfo("EA",
      StringFormat("Shutting down · reason=%d · ticks=%I64d", reason, g_tickCount));
   OmegaLogger::Flush();
   OmegaLogger::Shutdown();
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_tickCount++;
   g_state.tickCount = g_tickCount;
   g_state.updated   = TimeCurrent();

//--- Capital state machine — runs even before perception exists,
//    so circuit breakers protect equity from any external losses
//    on the account during testing.
   g_capital.Update();

//--- Phase 2: drive the multi-TF curve engine. Each CurveState
//    consumes its own bar-close events and updates per-TF
//    structure / physics. The curve writes the supporting fields,
//    DeriveTrinity() folds them upward.
   if(g_curve.Update())
     {
      g_curve.DeriveSupporting(g_state.supporting);
      g_state.primed = g_curve.primed;
     }
   g_state.DeriveTrinity();
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
         "%s · cap=%s · dd(d/w/hard)=%.2f%%/%.2f%%/%.2f%% · throttle=%.2f · session=%s · news=%s · %s · curve[%s]",
         _Symbol,
         OmegaStr::CapitalStateToString(g_capital.State()),
         g_capital.DailyDrawdownPct(),
         g_capital.WeeklyDrawdownPct(),
         g_capital.HardDrawdownPct(),
         g_capital.Throttle(),
         OmegaStr::SessionToString(OmegaSession::Current()),
         OmegaNews::Environment(),
         g_state.Snapshot(),
         g_curve.Snapshot()));

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
