// eas/AdaptiveBreakoutAI/src/trade_exec.mqh
#ifndef TRADE_EXEC_MQH
#define TRADE_EXEC_MQH

#include <Trade\Trade.mqh> // Standard library include

class TradeExec
{
public:
    enum Direction { DIR_NONE = 0, DIR_BUY = 1, DIR_SELL = -1 };

    static bool MarketOrder(string symbol, Direction dir, double sl, double tp, double riskPct)
    {
        // Your market order logic
        return true; // Placeholder
    }
    
    // CORRECTED PendingStopOrder function
    static bool PendingStopOrder(string symbol, Direction dir, double price, double sl, double tp, double riskPct, datetime expiration)
    {
        if (dir == DIR_NONE) return false;
        
        CTrade trade;
        // trade.SetExpertMagicNumber(YOUR_MAGIC_NUMBER); // Set your magic number
        trade.SetMarginMode();

        double volume = 0.01; // Placeholder for your volume calculation
        double sl_price = (dir == DIR_BUY) ? price - sl : price + sl;
        double tp_price = (dir == DIR_BUY) ? price + tp : price - tp;
        
        if (dir == DIR_BUY) {
            // FIX: Use the correct enum 'ORDER_TIME_GTC' for the expiration type
            return trade.BuyStop(volume, price, symbol, sl_price, tp_price, ORDER_TIME_GTC, expiration);
        } else {
            // FIX: Use the correct enum 'ORDER_TIME_GTC' for the expiration type
            return trade.SellStop(volume, price, symbol, sl_price, tp_price, ORDER_TIME_GTC, expiration);
        }
    }
};

#endif // TRADE_EXEC_MQH
