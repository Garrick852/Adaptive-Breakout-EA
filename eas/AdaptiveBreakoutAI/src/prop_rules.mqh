// CORRECTED
#ifndef PROP_RULES_MQH
#define PROP_RULES_MQH

class PropRules 
{
public:
    enum OperationMode {
        MODE_NORMAL = 0,
        MODE_PROP   = 1
    };

    static bool AllowTrading(int mode, double dailyLossPct, double maxDDPct) 
    {
        // Your implementation logic here
        return true;
    }
};

#endif
