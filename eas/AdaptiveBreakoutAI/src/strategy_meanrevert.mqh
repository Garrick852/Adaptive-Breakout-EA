// CORRECTED
#pragma once

#include "trade_exec.mqh"

class StrategyMeanRevert 
{
public:
    static bool Run(
        string symbol,
        int emaPeriod,
        double zScoreThresh,
        double atr,
        double atrMultSL,
        double atrMultTP,
        double riskPct)
    {
        if (atr <= 0.0) return false;

        // Correctly call iMA to get a handle
        int ma_handle = iMA(symbol, PERIOD_CURRENT, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
        if (ma_handle == INVALID_HANDLE) return false;
        
        double ema[];
        if (CopyBuffer(ma_handle, 0, 0, 1, ema) <= 0) return false;
        
        MqlRates rates[];
        if (CopyRates(symbol, PERIOD_CURRENT, 0, 1, rates) <= 0) return false;
        
        double currentClose = rates[0].close;
        double zScore = (currentClose - ema[0]) / atr;
        
        TradeExec::Direction dir = TradeExec::DIR_NONE;
        if (zScore < -zScoreThresh) {
            dir = TradeExec::DIR_BUY;
        } else if (zScore > zScoreThresh) {
            dir = TradeExec::DIR_SELL;
        }

        if (dir == TradeExec::DIR_NONE) return false;

        double sl = atr * atrMultSL;
        double tp = atr * atrMultTP;

        return TradeExec::MarketOrder(symbol, dir, sl, tp, riskPct);
    }
};
