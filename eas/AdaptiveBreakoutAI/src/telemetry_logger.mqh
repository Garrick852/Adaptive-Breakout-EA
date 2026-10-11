#ifndef TELEMETRY_LOGGER_MQH
#define TELEMETRY_LOGGER_MQH

#define TELEMETRY_MAX_INFLIGHT 256

namespace Telemetry
{
    struct Submission
    {
        bool active;
        string correlationId;
        string symbol;
        int regime;
        int direction;
        int orderType;
        double requestedPrice;
        double bidAtSubmit;
        double askAtSubmit;
        double requestedVolume;
        double filledVolume;
        ulong submitTimestampUs;
        ulong orderId;
        ulong dealId;
        uint retcode;
    };

    int fileHandle = INVALID_HANDLE;
    bool enabled = false;
    int currentRegime = -1;
    uint sequence = 0;
    Submission inflight[TELEMETRY_MAX_INFLIGHT];

    string SafeFilenamePart(string value)
    {
        StringReplace(value, ".", "-");
        StringReplace(value, ":", "-");
        StringReplace(value, " ", "_");
        StringReplace(value, "\\", "_");
        StringReplace(value, "/", "_");
        return(value);
    }

    void ResetRecord(const int index)
    {
        ZeroMemory(inflight[index]);
        inflight[index].active = false;
    }

    bool Init(const bool shouldEnable, const string symbol, const ulong magicNumber)
    {
        enabled = shouldEnable;
        if(!enabled)
            return(true);

        string date = SafeFilenamePart(TimeToString(TimeCurrent(), TIME_DATE));
        string account = (string)AccountInfoInteger(ACCOUNT_LOGIN);
        string filename = "AdaptiveBO_Telemetry_" + date + "_" + account + "_" +
                          SafeFilenamePart(symbol) + "_" + (string)magicNumber + ".csv";

        fileHandle = FileOpen(filename,
                              FILE_WRITE|FILE_READ|FILE_CSV|FILE_COMMON|FILE_ANSI|FILE_SHARE_READ,
                              ',');
        if(fileHandle == INVALID_HANDLE)
        {
            PrintFormat("Telemetry: failed to open %s (error %d)", filename, GetLastError());
            return(false);
        }

        if(FileSize(fileHandle) == 0)
        {
            FileWrite(fileHandle,
                      "timestamp", "correlation_id", "symbol", "magic_number",
                      "regime", "direction", "order_type",
                      "requested_price", "bid_at_submit", "ask_at_submit", "fill_price",
                      "spread_points", "slippage_points", "latency_ms", "latency_basis",
                      "volume", "commission",
                      "spread_cost_acct", "slippage_cost_acct", "total_friction_acct",
                      "order_id", "deal_id", "retcode");
            FileFlush(fileHandle);
        }
        FileSeek(fileHandle, 0, SEEK_END);
        return(true);
    }

    void Deinit()
    {
        if(fileHandle != INVALID_HANDLE)
        {
            FileFlush(fileHandle);
            FileClose(fileHandle);
            fileHandle = INVALID_HANDLE;
        }
    }

    void SetRegime(const int regime)
    {
        currentRegime = regime;
    }

    int FindFreeRecord()
    {
        for(int i = 0; i < TELEMETRY_MAX_INFLIGHT; i++)
        {
            if(!inflight[i].active)
                return(i);
        }
        return(-1);
    }

    int TrackSubmission(const string symbol,
                        const int direction,
                        const int orderType,
                        const double requestedPrice,
                        const double volume)
    {
        if(!enabled)
            return(-1);

        int index = FindFreeRecord();
        if(index < 0)
        {
            Print("Telemetry: in-flight cache exhausted; trade submission blocked");
            return(-2);
        }

        MqlTick tick;
        if(!SymbolInfoTick(symbol, tick))
        {
            PrintFormat("Telemetry: quote unavailable for %s; trade submission blocked", symbol);
            return(-2);
        }

        sequence++;
        ResetRecord(index);
        inflight[index].active = true;
        inflight[index].correlationId = StringFormat("%s-%I64u-%u",
                                                     symbol, GetMicrosecondCount(), sequence);
        inflight[index].symbol = symbol;
        inflight[index].regime = currentRegime;
        inflight[index].direction = direction;
        inflight[index].orderType = orderType;
        inflight[index].requestedPrice = requestedPrice;
        inflight[index].bidAtSubmit = tick.bid;
        inflight[index].askAtSubmit = tick.ask;
        inflight[index].requestedVolume = volume;
        inflight[index].submitTimestampUs = GetMicrosecondCount();
        return(index);
    }

    bool SubmissionAllowed(const int index)
    {
        return(index != -2);
    }

    bool TradeResultAccepted(const uint retcode)
    {
        return(retcode == TRADE_RETCODE_DONE ||
               retcode == TRADE_RETCODE_DONE_PARTIAL ||
               retcode == TRADE_RETCODE_PLACED);
    }

    void BindResult(const int index,
                    const bool accepted,
                    const ulong orderId,
                    const ulong dealId,
                    const uint retcode)
    {
        if(index < 0)
            return;

        inflight[index].retcode = retcode;
        inflight[index].orderId = orderId;
        inflight[index].dealId = dealId;
        if(!accepted)
            ResetRecord(index);
    }

    int FindSubmission(const ulong orderId,
                       const ulong dealId,
                       const string symbol,
                       const int direction)
    {
        for(int i = 0; i < TELEMETRY_MAX_INFLIGHT; i++)
        {
            if(!inflight[i].active)
                continue;
            if(orderId > 0 && inflight[i].orderId == orderId)
                return(i);
            if(dealId > 0 && inflight[i].dealId == dealId)
                return(i);
        }

        int newest = -1;
        ulong newestTimestamp = 0;
        for(int i = 0; i < TELEMETRY_MAX_INFLIGHT; i++)
        {
            if(!inflight[i].active || inflight[i].symbol != symbol ||
               inflight[i].direction != direction)
                continue;
            if(inflight[i].submitTimestampUs >= newestTimestamp)
            {
                newest = i;
                newestTimestamp = inflight[i].submitTimestampUs;
            }
        }
        return(newest);
    }

    double TickValueForCost(const string symbol)
    {
        double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
        if(tickValue <= 0.0)
            tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        return(tickValue);
    }

    void LogTradeTransaction(const MqlTradeTransaction &trans,
                             const MqlTradeRequest &request,
                             const MqlTradeResult &result)
    {
        if(!enabled || fileHandle == INVALID_HANDLE ||
           trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
            return;
        if(!HistoryDealSelect(trans.deal))
            return;

        long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
        if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
            return;

        long dealType = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
        int direction;
        if(dealType == DEAL_TYPE_BUY)
            direction = 1;
        else if(dealType == DEAL_TYPE_SELL)
            direction = -1;
        else
            return;

        string symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
        int index = FindSubmission(trans.order, trans.deal, symbol, direction);
        if(index < 0)
        {
            PrintFormat("Telemetry: no submission match for deal %I64u", trans.deal);
            return;
        }

        double fillPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
        double volume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
        double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        double tickValue = TickValueForCost(symbol);

        double spreadPoints = 0.0;
        double slippagePoints = 0.0;
        if(point > 0.0)
        {
            spreadPoints = (inflight[index].askAtSubmit - inflight[index].bidAtSubmit) / point;
            if(direction == 1)
                slippagePoints = (fillPrice - inflight[index].askAtSubmit) / point;
            else
                slippagePoints = (inflight[index].bidAtSubmit - fillPrice) / point;
        }

        double spreadCost = 0.0;
        double slippageCost = 0.0;
        if(tickSize > 0.0 && tickValue > 0.0)
        {
            spreadCost = (spreadPoints * point / tickSize) * tickValue * volume;
            slippageCost = (slippagePoints * point / tickSize) * tickValue * volume;
        }
        double totalFriction = spreadCost + slippageCost + MathAbs(commission);
        double latencyMs = (double)(GetMicrosecondCount() -
                                   inflight[index].submitTimestampUs) / 1000.0;
        string latencyBasis = (inflight[index].orderType == ORDER_TYPE_BUY ||
                               inflight[index].orderType == ORDER_TYPE_SELL)
                              ? "submit_to_fill"
                              : "placement_to_fill";
        uint retcode = inflight[index].retcode;
        if(retcode == 0)
            retcode = result.retcode;

        FileSeek(fileHandle, 0, SEEK_END);
        FileWrite(fileHandle,
                  TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                  inflight[index].correlationId,
                  symbol,
                  HistoryDealGetInteger(trans.deal, DEAL_MAGIC),
                  inflight[index].regime,
                  direction,
                  inflight[index].orderType,
                  DoubleToString(inflight[index].requestedPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
                  DoubleToString(inflight[index].bidAtSubmit, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
                  DoubleToString(inflight[index].askAtSubmit, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
                  DoubleToString(fillPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
                  DoubleToString(spreadPoints, 1),
                  DoubleToString(slippagePoints, 1),
                  DoubleToString(latencyMs, 3),
                  latencyBasis,
                  DoubleToString(volume, 2),
                  DoubleToString(commission, 2),
                  DoubleToString(spreadCost, 5),
                  DoubleToString(slippageCost, 5),
                  DoubleToString(totalFriction, 5),
                  trans.order,
                  trans.deal,
                  retcode);
        FileFlush(fileHandle);

        inflight[index].filledVolume += volume;
        if(inflight[index].filledVolume + 0.0000001 >= inflight[index].requestedVolume)
            ResetRecord(index);
    }
}

#endif
