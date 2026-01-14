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

   int Advise()
     {
      if(gLastATR <= 0.0 || gLastBoxRange <= 0.0)
         return(0);

      double ratio = gLastBoxRange / gLastATR;

      if(ratio > 2.0)
         return(+1); // breakout regime
      if(ratio < 0.8)
         return(-1); // mean-revert regime
      return(0);
     }
  }

#endif // __DRIFT_DETECTION_MQH__
