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

#property copyright "F72 OMEGA"
#property strict

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
