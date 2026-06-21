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

#include "../Common.mqh"
#include "../Logger.mqh"

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
