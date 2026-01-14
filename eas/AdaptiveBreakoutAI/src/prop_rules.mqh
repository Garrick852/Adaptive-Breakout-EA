//+------------------------------------------------------------------+
//| prop_rules.mqh - Prop‑firm style rule checks                     |
//| For AdaptiveBreakoutAI                                           |
//+------------------------------------------------------------------+
#ifndef __PROP_RULES_MQH__
#define __PROP_RULES_MQH__

namespace PropRules
  {
   // Example operational modes (align with your InpOperMode)
   enum OperMode
     {
      MODE_NORMAL = 0,
      MODE_EVAL   = 1,
      MODE_FUND   = 2
     };

   // Daily loss stop & overall drawdown checks.
   // dailyLossStopPct: max daily loss as % of balance (e.g. 5 == 5%)
   // maxTotalDDPct:    max overall drawdown as % of balance (e.g. 10 == 10%)
   bool AllowTrading(int operMode, double dailyLossStopPct, double maxTotalDDPct)
     {
      double balance      = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity       = AccountInfoDouble(ACCOUNT_EQUITY);
      double profitDay    = AccountInfoDouble(ACCOUNT_PROFIT); // since today
      double freeMargin   = AccountInfoDouble(ACCOUNT_FREEMARGIN);

      // Basic sanity
      if(balance <= 0.0)
        {
         Print("PropRules::AllowTrading -> balance <= 0, blocking");
         return(false);
        }

      // Overall drawdown (eq vs balance)
      double ddAbs  = balance - equity;
      double ddPct  = (ddAbs / balance) * 100.0;

      if(maxTotalDDPct > 0.0 && ddPct > maxTotalDDPct)
        {
         Print("PropRules::AllowTrading -> overall DD exceeded: ",
               DoubleToString(ddPct, 2), "% / limit=", DoubleToString(maxTotalDDPct, 2), "%");
         return(false);
        }

      // Daily loss (very simple: negative profit vs starting balance)
      double dailyLossPct = 0.0;
      if(profitDay < 0.0)
        dailyLossPct = (MathAbs(profitDay) / balance) * 100.0;

      if(dailyLossStopPct > 0.0 && dailyLossPct > dailyLossStopPct)
        {
         Print("PropRules::AllowTrading -> daily loss exceeded: ",
               DoubleToString(dailyLossPct, 2), "% / limit=", DoubleToString(dailyLossStopPct, 2), "%");
         return(false);
        }

      // Optional: mode‑specific logic
      if(operMode == MODE_EVAL)
        {
         // Could add tighter restrictions here if needed
      }

      // Basic margin sanity
      if(freeMargin <= 0.0)
        {
         Print("PropRules::AllowTrading -> free margin <= 0, blocking");
         return(false);
        }

      return(true);
     }
  }

#endif // __PROP_RULES_MQH__
