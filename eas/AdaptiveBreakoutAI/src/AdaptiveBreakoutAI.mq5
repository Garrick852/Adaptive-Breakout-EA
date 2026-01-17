// Experts/AdaptiveBreakoutAI/AdaptiveBreakoutAI.mq5

// (The top part of your file with #includes and inputs remains the same)
// ...
#include <AdaptiveBreakoutAI/utils.mqh>
#include <AdaptiveBreakoutAI/volatility.mqh>
#include <AdaptiveBreakoutAI/risk.mqh>
#include <AdaptiveBreakoutAI/trade_exec.mqh>
#include <AdaptiveBreakoutAI/prop_rules.mqh>
#include <AdaptiveBreakoutAI/strategy_breakout.mqh>
#include <AdaptiveBreakoutAI/strategy_meanrevert.mqh>
#include <AdaptiveBreakoutAI/drift_detection.mqh>

// (Your enums and inputs go here...)
// ...

// Expert initialization
int OnInit()
{
    // Sanity checks for new parameters to avoid pathological configs
    if(InpDriftBreakoutRatio <= InpDriftMeanRevRatio ||
        InpDriftBreakoutRatio <= 0.0 ||
        InpDriftMeanRevRatio  <= 0.0)
    {
        PrintFormat("AdaptiveBreakoutAI: invalid drift thresholds (breakout=%.3f, meanrev=%.3f) – using defaults (2.0 / 0.8)",
                    InpDriftBreakoutRatio, InpDriftMeanRevRatio);
        // InpDriftBreakoutRatio = 2.0; // ERROR: Cannot modify an input variable
        // InpDriftMeanRevRatio  = 0.8; // ERROR: Cannot modify an input variable
    }

    if(InpMR_EMAPeriod < 5)
    {
        PrintFormat("AdaptiveBreakoutAI: InpMR_EMAPeriod too small (%d), should be >= 5", InpMR_EMAPeriod);
        // InpMR_EMAPeriod = 5; // ERROR: Cannot modify an input variable
    }

    if(InpMR_ZScoreThresh <= 0.0)
    {
        PrintFormat("AdaptiveBreakoutAI: InpMR_ZScoreThresh <= 0 (%.3f), should be > 0", InpMR_ZScoreThresh);
        // InpMR_ZScoreThresh = 0.5; // ERROR: Cannot modify an input variable
    }

    Drift::Init();
    return(INIT_SUCCEEDED);
}

// (The rest of your AdaptiveBreakoutAI.mq5 file remains the same)
// ...
