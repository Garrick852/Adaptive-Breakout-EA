// eas/AdaptiveBreakoutAI/src/prop_rules.mqh

#ifndef PROP_RULES_MQH
#define PROP_RULES_MQH

class PropRules
{
public:
    enum OperationMode {
        MODE_NORMAL = 0, // Standard trading
        MODE_PROP   = 1  // Prop firm rules enabled
    };

    static bool AllowTrading(int mode, double maxDailyLossPct, double maxTotalDDPct)
    {
        if (mode != MODE_PROP) {
            return true; // Not in prop mode, always allow trading
        }

        // Add your logic here to check daily loss and total drawdown
        // This is a placeholder for your actual implementation.
        // For example:
        // double dailyLoss = GetDailyLoss();
        // if (dailyLoss > maxDailyLossPct) return false;

        return true;
    }
};

#endif // PROP_RULES_MQH
