// eas/AdaptiveBreakoutAI/src/portfolio.mqh
// PortfolioAgent: equity-level risk guard and global monitor.
// Provides AllowNewTrade() and GlobalMonitor() as static helpers.
// Design rule: NO input variables, NO OnInit/OnTick in this file.
#ifndef PORTFOLIO_MQH
#define PORTFOLIO_MQH

class PortfolioAgent
{
public:
    // Returns true if current equity drawdown is within the allowed limit.
    // maxDrawdownPct: maximum allowed drawdown from balance as a percentage, e.g. 10.0 = 10%.
    // Values <= 0 are treated as "no limit" — trading is always allowed.
    static bool AllowNewTrade(double maxDrawdownPct)
    {
        if(maxDrawdownPct <= 0.0)
            return(true); // No limit configured (or invalid value) — always allow

        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        if(balance <= 0.0)
            return(true); // Can't determine drawdown — allow by default

        double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
        double ddPct    = (balance - equity) / balance * 100.0;

        if(ddPct >= maxDrawdownPct)
        {
            PrintFormat("PortfolioAgent::AllowNewTrade -> BLOCKED: equity drawdown %.2f%% >= limit %.2f%%",
                        ddPct, maxDrawdownPct);
            return(false);
        }
        return(true);
    }

    // Monitors overall account health and prints a status line.
    // stopOutPct: if equity falls below this % of balance, prints a critical alert.
    static void GlobalMonitor(double stopOutPct)
    {
        double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
        double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
        double margin   = AccountInfoDouble(ACCOUNT_MARGIN);
        double freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);

        if(balance <= 0.0)
            return;

        double ddPct = (balance - equity) / balance * 100.0;

        PrintFormat("PortfolioAgent::GlobalMonitor -> Balance=%.2f  Equity=%.2f  DD=%.2f%%  Margin=%.2f  Free=%.2f",
                    balance, equity, ddPct, margin, freeMargin);

        if(stopOutPct > 0.0 && ddPct >= stopOutPct)
        {
            PrintFormat("PortfolioAgent::GlobalMonitor -> CRITICAL: drawdown %.2f%% reached stop-out limit %.2f%%",
                        ddPct, stopOutPct);
        }
    }
};

#endif // PORTFOLIO_MQH
