// eas/AdaptiveBreakoutAI/src/prop_rules.mqh
#ifndef PROP_RULES_MQH
#define PROP_RULES_MQH

class PropRules
{
public:
    // This enum MUST be defined for your main EA file to compile.
    // This is the source of the "undeclared identifier" error.
    enum OperationMode {
        MODE_NORMAL = 0, // Standard trading
        MODE_PROP   = 1  // Prop firm rules enabled
    };

    // This static method allows you to call PropRules::AllowTrading(...)
    static bool AllowTrading(int mode, double maxDailyLossPct, double maxTotalDDPct)
    {
        if (mode != MODE_PROP) {
            return true; // If not in prop mode, always allow trading.
        }

        // --- Placeholder for your prop firm logic ---
        // You would add your code here to check daily drawdown, etc.
        // For example:
        // CAccountInfo account;
        // if (account.Equity() < account.Balance() * (1 - (maxDailyLossPct/100.0)))
        //    return false;

        return true;
    }
};

#endif // PROP_RULES_MQH
