// utils.mqh
// General helper functions for math, logging, and parameter validation

#ifndef __UTILS_MQH__
#define __UTILS_MQH__

string FormatDouble(double value, int digits);
void LogMessage(string tag, string message);
bool ValidateInputs(double param, double min, double max);

#endif