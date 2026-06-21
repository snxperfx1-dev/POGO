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

#include "Common.mqh"
#include "Logger.mqh"

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
