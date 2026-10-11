#ifndef DRIFT_DETECTION_MQH
#define DRIFT_DETECTION_MQH

class Drift 
{
private:
    static double m_atr_history[50];
    static int    m_atr_count;

public:
    static void Init() 
    {
        ArrayInitialize(m_atr_history, 0.0);
        m_atr_count = 0;
        Print("Drift Detection Initialized.");
    }

    static void Update(double current_atr)
    {
        if(current_atr <= 0.0) return;

        if(m_atr_count < 50)
        {
            m_atr_history[m_atr_count] = current_atr;
            m_atr_count++;
            return;
        }

        for(int i = 0; i < 49; i++)
            m_atr_history[i] = m_atr_history[i + 1];
        m_atr_history[49] = current_atr;
    }

    static int Advise(double breakoutRatio, double meanRevRatio, bool verbose = false)
    {
        if (m_atr_count < 50) {
            return 0; // Not enough data yet
        }

        double first_half_avg = 0;
        for(int i = 0; i < 25; i++) first_half_avg += m_atr_history[i];
        first_half_avg /= 25.0;

        double second_half_avg = 0;
        for(int i = 25; i < 50; i++) second_half_avg += m_atr_history[i];
        second_half_avg /= 25.0;

        if (first_half_avg <= 0) return 0; 

        double ratio = second_half_avg / first_half_avg;
        if(verbose && !MQLInfoInteger(MQL_OPTIMIZATION))
            PrintFormat("Drift Advise: Ratio=%.2f (Newer ATR / Older ATR)", ratio);

        if (ratio > breakoutRatio) return 1;  // Breakout
        if (ratio < meanRevRatio) return -1; // Mean Reversion

        return 0; // Neutral
    }
};

// Initialize static members
double Drift::m_atr_history[50];
int    Drift::m_atr_count = 0;

#endif
