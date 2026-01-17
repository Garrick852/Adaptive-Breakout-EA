// CORRECTED
#ifndef TRADE_EXEC_MQH
#define TRADE_EXEC_MQH

#include <Trade/Trade.mqh> // Include the standard Trade library

class TradeExec 
{
private:
    static CTrade m_trade; // Static trade object

public:
    enum Direction {
        DIR_NONE = 0,
        DIR_BUY  = 1,
        DIR_SELL = -1
    };
    
    // ... MarketOrder function remains the same ...
    static bool MarketOrder(string symbol, Direction dir, double sl_dist, double tp_dist, double risk_pct)
    {
        if (dir == DIR_NONE) return false;
        
        double price = (dir == DIR_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
        double sl_price = (dir == DIR_BUY) ? price - sl_dist : price + sl_dist;
        double tp_price = (dir == DIR_BUY) ? price + tp_dist : price - tp_dist;

        // Lot size calculation would go here
        double lot_size = 0.01; // Placeholder

        if (dir == DIR_BUY) {
            return m_trade.Buy(lot_size, symbol, price, sl_price, tp_price, "buy");
        } else {
            return m_trade.Sell(lot_size, symbol, price, sl_price, tp_price, "sell");
        }
    }

    static bool PendingStopOrder(string symbol, Direction dir, double price, double sl_dist, double tp_dist, double risk_pct, datetime expiration)
    {
        if (dir == DIR_NONE) return false;
        
        double sl_price = (dir == DIR_BUY) ? price - sl_dist : price + sl_dist;
        double tp_price = (dir == DIR_BUY) ? price + tp_dist : price - tp_dist;

        // Lot size calculation
        double lot_size = 0.01; // Placeholder
        
        // --- THIS IS THE FIX ---
        // If expiration is 0, use GTC. Otherwise, use the provided time.
        ENUM_ORDER_TYPE_TIME time_type = (expiration == 0) ? ORDER_TIME_GTC : ORDER_TIME_SPECIFIED_DAY;

        if (dir == DIR_BUY) {
            return m_trade.BuyStop(lot_size, price, symbol, sl_price, tp_price, time_type, expiration, "buy stop");
        } else {
            return m_trade.SellStop(lot_size, price, symbol, sl_price, tp_price, time_type, expiration, "sell stop");
        }
    }
};
CTrade TradeExec::m_trade; // Initialize static member

#endif
