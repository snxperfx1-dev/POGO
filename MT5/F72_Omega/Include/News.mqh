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

#include "Common.mqh"

class OmegaNews
  {
public:
   //--- "NORMAL" / "PRE_HIGH_IMPACT" / "POST_HIGH_IMPACT" / "QUIET"
   static string Environment() { return "NORMAL"; }
   //--- 0..100 severity placeholder
   static int    Severity()    { return 0; }
  };

#endif // __OMEGA_NEWS_MQH__
