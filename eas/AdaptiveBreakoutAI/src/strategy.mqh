// strategy.mqh
// Core breakout logic and signal generation

#ifndef __STRATEGY_MQH__
#define __STRATEGY_MQH__

bool IsBreakout(double price, double threshold);
int GenerateSignal(double price, double upperBand, double lowerBand);
void ExecuteTrade(int signal, double lotSize);

#endif