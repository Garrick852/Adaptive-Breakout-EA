//+------------------------------------------------------------------+
//| drift_detection.mqh - Simple regime / “drift” detector           |
//+------------------------------------------------------------------+
#ifndef __DRIFT_DETECTION_MQH__
#define __DRIFT_DETECTION_MQH__

namespace Drift
  {
   double gLastATR      = 0.0;
   double gLastBoxRange = 0.0;

   void Init()
     {
      gLastATR      = 0.0;
      gLastBoxRange = 0.0;
      Print("Drift::Init -> reset state");
     }

   void Update(double atr, double boxHigh, double boxLow)
     {
      gLastATR      = atr;
      gLastBoxRange = MathAbs(boxHigh - boxLow);
     }

   // Parameterised drift adviser:
   //  - breakoutRatio: threshold above which we consider regime "breakout"
   //  - meanRevRatio : threshold below which we consider regime "mean-revert"
   // Returns:
   //  - +1 => breakout regime
   //  - -1 => mean-revert regime
   //  -  0 => neutral / no clear signal
   int Advise(double breakoutRatio, double meanRevRatio)
     {
      if(gLastATR <= 0.0 || gLastBoxRange <= 0.0)
         return(0);

      double ratio = gLastBoxRange / gLastATR;

      // Basic validation, fallback to sensible defaults if user misconfigures
      if(breakoutRatio <= meanRevRatio || breakoutRatio <= 0.0 || meanRevRatio <= 0.0)
        {
         breakoutRatio = 2.0;
         meanRevRatio  = 0.8;
        }

      if(ratio > breakoutRatio)
         return(+1);  // breakout regime

      if(ratio < meanRevRatio)
         return(-1);  // mean-revert regime

      // In-between zone: neutral
      return(0);
     }
  }

#endif // __DRIFT_DETECTION_MQH__
