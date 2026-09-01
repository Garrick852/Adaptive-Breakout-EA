//+------------------------------------------------------------------+
//| observation_tap.mqh - MI-002: 6-feature observation tap           |
//|                                                                    |
//| Gating-safe observability ONLY. This module writes the AuraArc      |
//| 6-feature vector (training contract order) to a single FILE_COMMON  |
//| CSV via ATOMIC REPLACE (tmp -> FileMove), never per-tick files.     |
//|                                                                    |
//| HOLD contract (non-negotiable):                                    |
//|   - write failure  => observation invalid => EA must HOLD           |
//|   - stale (ts_ms older than stale window) => observation invalid    |
//|   - any invalid observation => EA must NOT evaluate trades          |
//|   - this module NEVER places or modifies orders                     |
//|                                                                    |
//| File (FILE_COMMON root, Common\Files):                             |
//|   adaptivebo_observations_<SYMBOL>.csv  (header + 1 data line)      |
//| Columns: ts_ms,seq_id,symbol,timeframe,regime_bias,adx_norm,        |
//|          ema_crossover,range_width_frac,range_position,             |
//|          drawdown_fraction                                          |
//|                                                                    |
//| Feature formulas (documented; match training contract NAMES/ORDER;  |
//| see docs/ADAPTIVEBO_MI_MAP.md §6):                                  |
//|   regime_bias      Drift::Advise() {-1,0,+1} (strategy regime)      |
//|   adx_norm         iADX(14) MAIN / 100, clamped [0,1]               |
//|   ema_crossover    (ema12 - ema26)/ATR, clamped [-1,1]              |
//|   range_width_frac (boxHigh - boxLow)/ATR (Donchian, closed bars)   |
//|   range_position   (close - boxLow)/(boxHigh - boxLow), clamped     |
//|   drawdown_fraction (dayHwm - equity)/dayHwm (day-reset HWM)        |
//+------------------------------------------------------------------+
#property strict

#include "volatility.mqh"
#include "drift_detection.mqh"

class ObservationTap
{
private:
    static int       s_emaFast;
    static int       s_emaSlow;
    static int       s_adx;
    static uint      s_seq;
    static long      s_lastWriteMs;
    static long      s_lastWarnMs;
    static bool      s_valid;
    static double    s_dayHwm;
    static datetime  s_dayKey;
    // configuration (set via Configure() from EA OnInit)
    static bool      s_enabled;
    static int       s_intervalMs;
    static int       s_staleMs;
    static double    s_driftBreakoutRatio;
    static double    s_driftMeanRevRatio;

    static double Clamp(const double v, const double lo, const double hi)
    {
        if(v < lo) return(lo);
        if(v > hi) return(hi);
        return(v);
    }

    // Read the previous (closed) bar value from an indicator handle.
    static double IndicatorValue(const int handle)
    {
        if(handle == INVALID_HANDLE)
            return(0.0);
        double buf[];
        if(CopyBuffer(handle, 0, 1, 1, buf) > 0)
            return(buf[0]);
        return(0.0);
    }

    // Day-reset high-water mark of account equity (UTC day boundary).
    static void UpdateDayHwm()
    {
        datetime now = TimeGMT();
        if(now != s_dayKey)
        {
            s_dayKey = now;
            s_dayHwm = AccountInfoDouble(ACCOUNT_EQUITY);   // start-of-day baseline
            if(s_dayHwm < 0.0)
                s_dayHwm = 0.0;
        }
        double eq = AccountInfoDouble(ACCOUNT_EQUITY);
        if(eq > s_dayHwm)
            s_dayHwm = eq;
    }

    // Compute the 6-feature vector from current market/account state.
    static bool ComputeFeatures(const string symbol, double &f[])
    {
        ArrayResize(f, 6);
        double emaFast = IndicatorValue(s_emaFast);
        double emaSlow = IndicatorValue(s_emaSlow);
        double adx     = IndicatorValue(s_adx);
        double atr     = Volatility::ATR(symbol, PERIOD_CURRENT, 14);
        double close   = iClose(symbol, PERIOD_CURRENT, 1);
        double boxHigh = 0.0, boxLow = 0.0;
        bool   hasBox  = Volatility::Donchian(symbol, PERIOD_CURRENT, 24, 0, boxHigh, boxLow);

        double atrSafe  = (atr > 0.0) ? atr : 1e-9;
        double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
        UpdateDayHwm();

        f[0] = (double)Drift::Advise(s_driftBreakoutRatio, s_driftMeanRevRatio); // regime_bias {-1,0,1}
        f[1] = Clamp(adx / 100.0, 0.0, 1.0);                                     // adx_norm
        f[2] = Clamp((emaFast - emaSlow) / atrSafe, -1.0, 1.0);                  // ema_crossover
        f[3] = (hasBox && atr > 0.0) ? (boxHigh - boxLow) / atr : 0.0;           // range_width_frac
        f[4] = (hasBox && boxHigh > boxLow)                                       // range_position
               ? Clamp((close - boxLow) / (boxHigh - boxLow), 0.0, 1.0)
               : 0.5;
        f[5] = (s_dayHwm > 0.0) ? MathMax(0.0, (s_dayHwm - equity) / s_dayHwm)   // drawdown_fraction
                                : 0.0;
        return(true);
    }

    // Atomic replace: write tmp, then FileMove over the target.
    static bool WriteObservation(const string symbol, const long nowMs)
    {
        double f[];
        if(!ComputeFeatures(symbol, f))
            return(false);

        string tmpName = "adaptivebo_observations_" + symbol + ".csv.tmp";
        string dstName = "adaptivebo_observations_" + symbol + ".csv";

        int fh = FileOpen(tmpName, FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI, ',');
        if(fh == INVALID_HANDLE)
        {
            PrintFormat("OBS-TAP: open tmp failed (%s) err=%d", tmpName, GetLastError());
            return(false);
        }
        FileWrite(fh, "ts_ms", "seq_id", "symbol", "timeframe",
                  "regime_bias", "adx_norm", "ema_crossover",
                  "range_width_frac", "range_position", "drawdown_fraction");
        FileWrite(fh, nowMs, (long)s_seq, symbol, EnumToString(Period()),
                  f[0], f[1], f[2], f[3], f[4], f[5]);
        FileClose(fh);

        if(!FileMove(tmpName, FILE_COMMON, dstName, FILE_REWRITE))
        {
            PrintFormat("OBS-TAP: atomic move failed (%s) err=%d", dstName, GetLastError());
            FileDelete(tmpName, FILE_COMMON);
            return(false);
        }
        s_seq++;
        return(true);
    }

public:
    // Called from EA OnInit: apply inputs, then create indicator handles.
    static bool Configure(const bool enabled,
                          const int  intervalMs,
                          const int  staleMs,
                          const double driftBreakoutRatio,
                          const double driftMeanRevRatio)
    {
        s_enabled           = enabled;
        s_intervalMs        = (intervalMs >= 100)  ? intervalMs  : 1000;
        s_staleMs           = (staleMs >= 250)     ? staleMs     : 2500;
        s_driftBreakoutRatio = driftBreakoutRatio;
        s_driftMeanRevRatio  = driftMeanRevRatio;
        return(true);
    }

    static bool Init()
    {
        s_emaFast = iMA(_Symbol, PERIOD_CURRENT, 12, 0, MODE_EMA, PRICE_CLOSE);
        s_emaSlow = iMA(_Symbol, PERIOD_CURRENT, 26, 0, MODE_EMA, PRICE_CLOSE);
        s_adx     = iADX(_Symbol, PERIOD_CURRENT, 14);
        if(s_emaFast == INVALID_HANDLE || s_emaSlow == INVALID_HANDLE || s_adx == INVALID_HANDLE)
        {
            Print("OBS-TAP: indicator handle creation failed - staying HOLD.");
            return(false);
        }
        s_seq        = 0;
        s_lastWriteMs = 0;
        s_lastWarnMs  = 0;
        s_valid      = false;   // no observation yet => invalid => HOLD until first write
        s_dayHwm     = AccountInfoDouble(ACCOUNT_EQUITY);
        s_dayKey     = TimeGMT();
        if(s_dayHwm < 0.0)
            s_dayHwm = 0.0;
        return(true);
    }

    static void Deinit()
    {
        if(s_emaFast != INVALID_HANDLE) IndicatorRelease(s_emaFast);
        if(s_emaSlow != INVALID_HANDLE) IndicatorRelease(s_emaSlow);
        if(s_adx     != INVALID_HANDLE) IndicatorRelease(s_adx);
        s_emaFast = INVALID_HANDLE;
        s_emaSlow = INVALID_HANDLE;
        s_adx     = INVALID_HANDLE;
    }

    // Current observation validity: last write ok AND younger than staleMs.
    static bool ObservationValid()
    {
        if(!s_enabled)
            return(true);                        // tap off => no gating
        if(!s_valid)
            return(false);
        long nowMs = (long)TimeGMT() * 1000 + (long)(GetTickCount() % 1000);
        return((nowMs - s_lastWriteMs) < (long)s_staleMs);
    }

    // Per-tick entry (EA OnTick). Returns false => EA must HOLD (no trade eval).
    static bool OnTick(const string symbol)
    {
        if(!s_enabled)
            return(true);

        long nowMs = (long)TimeGMT() * 1000 + (long)(GetTickCount() % 1000);
        if((nowMs - s_lastWriteMs) >= (long)s_intervalMs)
        {
            s_lastWriteMs = nowMs;
            bool ok = WriteObservation(symbol, nowMs);
            if(ok)
            {
                s_valid = true;
            }
            else
            {
                s_valid = false;
                if((nowMs - s_lastWarnMs) > 5000)
                {
                    Print("OBS-TAP: write failure -> observation invalid -> HOLD.");
                    s_lastWarnMs = nowMs;
                }
            }
        }
        return(ObservationValid());
    }
};

// --- static member definitions (initialized in Configure/Init) ---------------
int      ObservationTap::s_emaFast;
int      ObservationTap::s_emaSlow;
int      ObservationTap::s_adx;
uint     ObservationTap::s_seq;
long     ObservationTap::s_lastWriteMs;
long     ObservationTap::s_lastWarnMs;
bool     ObservationTap::s_valid;
double   ObservationTap::s_dayHwm;
datetime ObservationTap::s_dayKey;
bool     ObservationTap::s_enabled;
int      ObservationTap::s_intervalMs;
int      ObservationTap::s_staleMs;
double   ObservationTap::s_driftBreakoutRatio;
double   ObservationTap::s_driftMeanRevRatio;
