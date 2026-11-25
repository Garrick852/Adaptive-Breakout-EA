// trade_exec.mqh — risk-bounded, capped, fail-closed execution (AOS.TWIN §6).
#ifndef TRADE_EXEC_MQH
#define TRADE_EXEC_MQH

#include <Trade/Trade.mqh>
#include "risk.mqh"

class TradeExec 
{
private:
    static CTrade m_trade;
    static double s_maxLot;   // configurable per-order cap (0 = unlimited)

    // Risk-bounded lot from the broker-side SL distance, capped and step-normalized.
    // Returns 0.0 (fail-closed) on any invalid input.
    static double CalcLots(string symbol, double sl_dist, double risk_pct)
    {
        if(risk_pct <= 0.0 || sl_dist <= 0.0)
            return 0.0;
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        if(point <= 0.0)
            return 0.0;
        double slPoints = sl_dist / point;
        if(slPoints <= 0.0)
            return 0.0;

        double lots = Risk::CalcLotsByRisk(symbol, slPoints, risk_pct);
        if(lots <= 0.0)
            return 0.0;   // invalid tick params -> reject (fail-closed)

        if(s_maxLot > 0.0 && lots > s_maxLot)
            lots = s_maxLot;

        // re-normalize to the broker step after the cap
        double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
        if(minLot <= 0.0 || stepLot <= 0.0)
            return 0.0;
        double steps = MathFloor((lots - minLot) / stepLot + 0.5);
        lots = minLot + steps * stepLot;
        if(lots <= 0.0)
            return 0.0;
        return lots;
    }

public:
    enum Direction {
        DIR_NONE = 0,
        DIR_BUY  = 1,
        DIR_SELL = -1,
        DIR_ANY  = 2     // MI-003: no AOS direction restriction (default)
    };

    static void SetMaxLot(double v) { s_maxLot = v; }

    static bool MarketOrder(string symbol, Direction dir, double sl_dist, double tp_dist, double risk_pct)
    {
        if (dir == DIR_NONE) return false;

        double price = (dir == DIR_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
        double sl_price = (dir == DIR_BUY) ? price - sl_dist : price + sl_dist;
        double tp_price = (dir == DIR_BUY) ? price + tp_dist : price - tp_dist;

        // fail-closed: no zero/negative price or SL
        if(price <= 0.0 || sl_price <= 0.0)
        {
            Print("TradeExec::MarketOrder -> fail-closed: invalid price/SL");
            return false;
        }

        double lot_size = CalcLots(symbol, sl_dist, risk_pct);
        if(lot_size <= 0.0)
        {
            Print("TradeExec::MarketOrder -> fail-closed: computed lot <= 0");
            return false;
        }

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

        // fail-closed: no zero/negative price or SL
        if(price <= 0.0 || sl_price <= 0.0)
        {
            Print("TradeExec::PendingStopOrder -> fail-closed: invalid price/SL");
            return false;
        }

        double lot_size = CalcLots(symbol, sl_dist, risk_pct);
        if(lot_size <= 0.0)
        {
            Print("TradeExec::PendingStopOrder -> fail-closed: computed lot <= 0");
            return false;
        }

        ENUM_ORDER_TYPE_TIME time_type = (expiration == 0) ? ORDER_TIME_GTC : ORDER_TIME_SPECIFIED_DAY;

        if (dir == DIR_BUY) {
            return m_trade.BuyStop(lot_size, price, symbol, sl_price, tp_price, time_type, expiration, "buy stop");
        } else {
            return m_trade.SellStop(lot_size, price, symbol, sl_price, tp_price, time_type, expiration, "sell stop");
        }
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
CTrade TradeExec::m_trade;      // static member init
double TradeExec::s_maxLot = 0.0;

#endif
