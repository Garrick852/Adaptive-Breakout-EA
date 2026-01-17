// eas/AdaptiveBreakoutAI/src/trade_exec.mqh

#ifndef TRADE_EXEC_MQH
#define TRADE_EXEC_MQH

#include <Trade\Trade.mqh>

class TradeExec
{
public:
    enum Direction { DIR_NONE = 0, DIR_BUY = 1, DIR_SELL = -1 };

    static bool MarketOrder(string symbol, Direction dir, double sl, double tp, double riskPct)
    {
        // ... (Your existing MarketOrder logic is likely fine) ...
        CTrade trade;
        // ...
        return true;
    }
    
    // CORRECTED PendingStopOrder
    static bool PendingStopOrder(string symbol, Direction dir, double price, double sl, double tp, double riskPct, datetime expiration)
    {
        if (dir == DIR_NONE) return false;
        
        CTrade trade;
        trade.SetExpertMagicNumber(12345); // Set your magic number
        trade.SetMarginMode();

        double volume = 1.0; // Replace with your lot size calculation
        double sl_price = (dir == DIR_BUY) ? price - sl : price + sl;
        double tp_price = (dir == DIR_BUY) ? price + tp : price - tp;
        
        if (dir == DIR_BUY) {
            // Use ORDER_TIME_GTC for the time type
            return trade.BuyStop(volume, price, symbol, sl_price, tp_price, ORDER_TIME_GTC, expiration);
        } else {
            // Use ORDER_TIME_GTC for the time type
            return trade.SellStop(volume, price, symbol, sl_price, tp_price, ORDER_TIME_GTC, expiration);
        }
    }
};

#endif // TRADE_EXEC_MQH
