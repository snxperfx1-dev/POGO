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

#include "CurveState.mqh"

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
