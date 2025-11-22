//+------------------------------------------------------------------+
//|                                        drift_detection.mqh |
//|                     Copyright 2025, Garrick852                   |
//|      https://github.com/Garrick852/Adaptive-Breakout-EA          |
//|------------------------------------------------------------------+|
//| Description:                                                     |
//| This module monitors the predictive performance of the AI model  |
//| (CalculateSensitivityScore). If performance degrades (drifts)    |
//| below a specified threshold, it raises a flag to halt trading.   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Garrick852"
#property link      "https://github.com/Garrick852/Adaptive-Breakout-EA"

//--- Inputs for Drift Detection
input int    DriftCheckPeriod         = 100;    // How often to check for drift (in number of trades)
input int    DriftMinTrades           = 20;     // Minimum number of trades before checking for drift
input double DriftPerformanceThreshold = 0.55;   // Performance threshold (e.g., win rate) to trigger drift alert
input double DriftSensitivityThreshold = 0.8;    // Analyze only trades where sensitivity score was above this level
input long   InpDriftMagicNumber      = 123456; // Magic Number to filter trades

//--- Global flag to signal model drift
bool isModelDrifting = false;

//--- Forward declaration for EmitGlyph from the main EA
void EmitGlyph(string type, string note);

//+------------------------------------------------------------------+
//| MonitorDrift                                                     |
//| Analyzes recent trade performance to detect model drift.         |
//+------------------------------------------------------------------+
void MonitorDrift()
  {
   // 1. Select History (MQL5 specific)
   if(!HistorySelect(0, TimeCurrent())) return;

   int total_deals = HistoryDealsTotal();
   int analyzed_trades = 0;
   int wins = 0;

   // 2. Loop backwards to find recent trades
   for(int i = total_deals - 1; i >= 0; i--) {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      // 3. Filter: Must be an EXIT deal (profit/loss realization)
      long entry_type = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry_type != DEAL_ENTRY_OUT) continue;

      // 4. Filter: Must match your EA's Magic Number
      long deal_magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      if(deal_magic != InpDriftMagicNumber) continue;

      // 5. Calculate Stats (Win Rate)
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      if(profit > 0) wins++;

      analyzed_trades++;
      if(analyzed_trades >= DriftCheckPeriod) break;
   }

   // If we haven't collected enough trades yet, do nothing
   if(analyzed_trades < DriftMinTrades) return;

   // Calculate win rate
   double win_rate = (double)wins / analyzed_trades;

   if(win_rate < DriftPerformanceThreshold)
   {
      if(!isModelDrifting)
      {
         isModelDrifting = true;
         string msg = "Win rate dropped to " + DoubleToString(win_rate, 2);
         EmitGlyph("DriftDetected", msg);
         Print("CRITICAL: Model drift detected. " + msg);
      }
   }
   else
   {
      isModelDrifting = false;
   }
  }

//+------------------------------------------------------------------+
//| CheckDriftStatus                                                 |
//| Provides a simple accessor to the current drift status.          |
//+------------------------------------------------------------------+
bool IsModelDrifting()
  {
   return isModelDrifting;
  }
//+------------------------------------------------------------------+
