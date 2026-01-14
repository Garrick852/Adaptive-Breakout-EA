//+------------------------------------------------------------------+
//| prop_rules.mqh - Prop-firm style constraints                     |
//+------------------------------------------------------------------+
#ifndef __PROP_RULES_MQH__
#define __PROP_RULES_MQH__

namespace PropRules
  {
   enum OperMode
     {
      MODE_NORMAL = 0,
      MODE_EVAL   = 1,
      MODE_FUND   = 2
     };

   bool AllowTrading(int operMode, double dailyLossStopPct, double maxTotalDDPct)
     {
      double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
      double profitDay = AccountInfoDouble(ACCOUNT_PROFIT);

      if(balance <= 0.0)
        {
         Print("PropRules::AllowTrading -> balance <= 0");
         return(false);
        }

      // Total drawdown check
      double ddAbs = balance - equity;
      double ddPct = (ddAbs / balance) * 100.0;
      if(maxTotalDDPct > 0.0 && ddPct > maxTotalDDPct)
        {
         Print("PropRules::AllowTrading -> DD exceeded: ",
               DoubleToString(ddPct, 2), "% / max=",
               DoubleToString(maxTotalDDPct, 2), "%");
         return(false);
        }

      // Daily loss check (very basic)
      double dailyLossPct = 0.0;
      if(profitDay < 0.0)
         dailyLossPct = MathAbs(profitDay) / balance * 100.0;

      if(dailyLossStopPct > 0.0 && dailyLossPct > dailyLossStopPct)
        {
         Print("PropRules::AllowTrading -> daily loss exceeded: ",
               DoubleToString(dailyLossPct, 2), "% / max=",
               DoubleToString(dailyLossStopPct, 2), "%");
         return(false);
        }

      // You may tighten rules for MODE_EVAL / MODE_FUND here if desired

      return(true);
     }
  }

#endif // __PROP_RULES_MQH__
