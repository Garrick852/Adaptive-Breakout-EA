// eas/AdaptiveBreakoutAI/src/prop_rules.mqh
// FTMO 2-step rails (5% daily / 10% total), fail-closed on balance/equity <= 0.
// NOTE: do NOT copy the RL-Bot variant here — that one is fail-OPEN on balance <= 0.
#ifndef PROP_RULES_MQH
#define PROP_RULES_MQH

class PropRules
{
private:
    static double s_dayStartBalance;
    static long   s_dayKey;

    static void UpdateDayAnchor()
    {
        long dayNow = (long)TimeGMT() / 86400;
        if(dayNow != s_dayKey || s_dayStartBalance <= 0.0)
        {
            s_dayKey = dayNow;
            double bal = AccountInfoDouble(ACCOUNT_BALANCE);
            s_dayStartBalance = (bal > 0.0) ? bal : AccountInfoDouble(ACCOUNT_EQUITY);
        }
    }

public:
    enum OperationMode {
        MODE_NORMAL = 0, // Standard trading (no prop rails)
        MODE_PROP   = 1  // Prop firm rules enabled
    };

    // Returns true when trading is allowed.
    //  - enabled == false  -> raw signal pass (measure unmasked MaxDD/expectancy).
    //  - enabled == true && MODE_PROP -> 5% daily / 10% total DD, fail-closed.
    static bool AllowTrading(bool enabled, int mode, double maxDailyLossPct, double maxTotalDDPct)
    {
        if(!enabled)
            return true;   // raw signal pass
        if(mode != MODE_PROP)
            return true;

        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

        // FAIL-CLOSED: cannot compute drawdown -> block (never fail-open).
        if(balance <= 0.0 || equity <= 0.0)
        {
            Print("PropRules: BLOCKED - balance/equity <= 0 (fail-closed)");
            return false;
        }

        UpdateDayAnchor();

        if(maxDailyLossPct > 0.0 && s_dayStartBalance > 0.0)
        {
            double dailyLossPct = (s_dayStartBalance - equity) / s_dayStartBalance * 100.0;
            if(dailyLossPct >= maxDailyLossPct)
            {
                PrintFormat("PropRules: BLOCKED - daily loss %.2f%% >= %.2f%%",
                            dailyLossPct, maxDailyLossPct);
                return false;
            }
        }

        if(maxTotalDDPct > 0.0)
        {
            double totalDdPct = (balance - equity) / balance * 100.0;
            if(totalDdPct >= maxTotalDDPct)
            {
                PrintFormat("PropRules: BLOCKED - total drawdown %.2f%% >= %.2f%%",
                            totalDdPct, maxTotalDDPct);
                return false;
            }
        }

        return true;
    }
};

double PropRules::s_dayStartBalance = 0.0;
long   PropRules::s_dayKey          = 0;

#endif // PROP_RULES_MQH
