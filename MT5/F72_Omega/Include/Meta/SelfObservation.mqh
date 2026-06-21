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

#include "../Common.mqh"
#include "../Logger.mqh"

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
