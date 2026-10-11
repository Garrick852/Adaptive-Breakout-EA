// CORRECTED
#ifndef TRADE_EXEC_MQH
#define TRADE_EXEC_MQH

#include <Trade/Trade.mqh> // Include the standard Trade library
#include "telemetry_logger.mqh"

class TradeExec 
{
private:
    static CTrade m_trade; // Static trade object

public:
    enum Direction {
        DIR_NONE = 0,
        DIR_BUY  = 1,
        DIR_SELL = -1,
        DIR_ANY  = 2     // MI-003: no AOS direction restriction (default)
    };

    static void SetMagicNumber(const ulong magicNumber)
    {
        m_trade.SetExpertMagicNumber(magicNumber);
    }
    
    // ... MarketOrder function remains the same ...
    static bool MarketOrder(string symbol, Direction dir, double sl_dist, double tp_dist, double risk_pct)
    {
        if (dir == DIR_NONE) return false;
        
        double price = (dir == DIR_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
        double sl_price = (dir == DIR_BUY) ? price - sl_dist : price + sl_dist;
        double tp_price = (dir == DIR_BUY) ? price + tp_dist : price - tp_dist;

        // Lot size calculation would go here
        double lot_size = 0.01; // Placeholder
        int telemetry_index = Telemetry::TrackSubmission(symbol, (int)dir,
                                                         (int)((dir == DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL),
                                                         price, lot_size);
        if(!Telemetry::SubmissionAllowed(telemetry_index))
            return(false);

        bool placed;
        if (dir == DIR_BUY) {
            placed = m_trade.Buy(lot_size, symbol, price, sl_price, tp_price, "buy");
        } else {
            placed = m_trade.Sell(lot_size, symbol, price, sl_price, tp_price, "sell");
        }
        uint retcode = m_trade.ResultRetcode();
        Telemetry::BindResult(telemetry_index,
                              placed && Telemetry::TradeResultAccepted(retcode),
                              m_trade.ResultOrder(), m_trade.ResultDeal(), retcode);
        return(placed);
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
        int telemetry_index = Telemetry::TrackSubmission(symbol, (int)dir,
                                                         (int)((dir == DIR_BUY) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP),
                                                         price, lot_size);
        if(!Telemetry::SubmissionAllowed(telemetry_index))
            return(false);

        bool placed;
        if (dir == DIR_BUY) {
            placed = m_trade.BuyStop(lot_size, price, symbol, sl_price, tp_price, time_type, expiration, "buy stop");
        } else {
            placed = m_trade.SellStop(lot_size, price, symbol, sl_price, tp_price, time_type, expiration, "sell stop");
        }
        uint retcode = m_trade.ResultRetcode();
        Telemetry::BindResult(telemetry_index,
                              placed && Telemetry::TradeResultAccepted(retcode),
                              m_trade.ResultOrder(), m_trade.ResultDeal(), retcode);
        return(placed);
    }

    // MI-004: close every open position (escalation rail). Returns count closed.
    static int CloseAllPositions()
    {
        int closed = 0;
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0)
                continue;
            if(!PositionSelectByTicket(ticket))
                continue;
            if(m_trade.PositionClose(ticket))
                closed++;
        }
        return(closed);
    }
};
CTrade TradeExec::m_trade; // Initialize static member

#endif
