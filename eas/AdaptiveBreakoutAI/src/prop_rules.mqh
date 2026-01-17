// eas/AdaptiveBreakoutAI/src/prop_rules.mqh
#ifndef PROP_RULES_MQH
#define PROP_RULES_MQH

class PropRules
{
public:
    // This enum MUST be defined for your main EA file to compile
    enum OperationMode {
        MODE_NORMAL = 0, // Standard trading
        MODE_PROP   = 1  // Prop firm rules enabled
    };

    static bool AllowTrading(int mode, double maxDailyLossPct, double maxTotalDDPct)
    {
        if (mode != MODE_PROP) {
            return true; // Not in prop mode, so we don't apply rules
        }

        // Placeholder for your actual prop firm rule logic
        // For example, you would calculate the day's profit/loss here.
        return true;
    }
};

#endif // PROP_RULES_MQH
