// risk.mqh
// Provides leverage, margin, and drawdown controls

#ifndef __RISK_MQH__
#define __RISK_MQH__

double CalculateLotSize(double riskPercent, double accountBalance, double stopLossPoints);
bool CheckDrawdownLimit(double maxDrawdownPercent);
double NormalizeRisk(double rawRisk);

#endif
