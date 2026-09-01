//+------------------------------------------------------------------+
//| escalation.mqh - MI-004: Escalation Controller (4.5% DD hard cap) |
//|                                                                    |
//| Governance-locked risk rail, run FIRST in OnTick (highest          |
//| priority). On breach of the hard cap it CLOSES ALL positions and   |
//| latches BLOCK/LOCKED until clear recovery (hysteresis) or the      |
//| day rollover (HWM reset). While locked, the EA ignores every       |
//| command, including any AOS BUY.                                    |
//|                                                                    |
//| Non-negotiable:                                                     |
//|   - dd = (HWM - Equity) / HWM, HWM = day-reset equity high-water   |
//|     mark (reset policy: UTC day boundary).                         |
//|   - The 4.5% cap is GOVERNANCE-LOCKED here, NOT an input: it must  |
//|     not be open to external optimization. Change requires a        |
//|     governed approval (docs/ADAPTIVEBO_MI_MAP.md §8).              |
//|   - This rail never places orders; it only closes and blocks.      |
//+------------------------------------------------------------------+
#property strict

#include "trade_exec.mqh"

// Governance-locked hard cap: maximum HWM drawdown fraction.
// DO NOT change without a governed approval (see ADAPTIVEBO_MI_MAP.md §8).
#define ESCALATION_MAX_DD_FRACTION      0.045
// Hysteresis: lock releases only below this fraction (avoids boundary churn).
#define ESCALATION_RELEASE_DD_FRACTION  0.040

class Escalation
{
private:
    static double   s_hwm;
    static datetime s_dayKey;
    static bool     s_locked;
    static double   s_peakDdFrac;

    static double DdFraction()
    {
        double hwm = s_hwm;
        if(hwm <= 0.0)
            return(0.0);
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        return(MathMax(0.0, (hwm - equity) / hwm));
    }

    // Day-reset HWM: at each UTC day boundary, baseline = current equity.
    static void UpdateHwm()
    {
        datetime now = TimeGMT();
        if(now != s_dayKey)
        {
            s_dayKey = now;
            s_hwm = AccountInfoDouble(ACCOUNT_EQUITY);
            if(s_hwm < 0.0)
                s_hwm = 0.0;
        }
        double eq = AccountInfoDouble(ACCOUNT_EQUITY);
        if(eq > s_hwm)
            s_hwm = eq;
    }

public:
    static void Init()
    {
        s_hwm       = AccountInfoDouble(ACCOUNT_EQUITY);
        if(s_hwm < 0.0)
            s_hwm   = 0.0;
        s_dayKey    = TimeGMT();
        s_locked    = false;
        s_peakDdFrac = 0.0;
    }

    // Per-tick rail. Returns TRUE when the account is in breach or latched
    // locked => the EA must do nothing else (no trades, no AOS processing).
    static bool OnTick(const string symbol)
    {
        UpdateHwm();
        double dd = DdFraction();
        if(dd > s_peakDdFrac)
            s_peakDdFrac = dd;

        if(!s_locked && dd >= ESCALATION_MAX_DD_FRACTION)
        {
            s_locked = true;
            PrintFormat("ESCALATION: drawdown %.4f >= cap %.4f - CloseAll + BLOCK/EXIT", dd, ESCALATION_MAX_DD_FRACTION);
            int closed = TradeExec::CloseAllPositions();
            PrintFormat("ESCALATION: closed %d position(s); state LOCKED (ignoring all commands)", closed);
        }

        if(s_locked)
        {
            // Release only on clear recovery (hysteresis; day rollover resets
            // HWM so dd collapses to ~0 and this naturally releases).
            if(dd < ESCALATION_RELEASE_DD_FRACTION)
            {
                s_locked = false;
                PrintFormat("ESCALATION: recovered below %.4f - state UNLOCKED (peak dd %.4f)", ESCALATION_RELEASE_DD_FRACTION, s_peakDdFrac);
            }
            return(true);
        }
        return(false);
    }

    static bool IsLocked()
    {
        return(s_locked);
    }
};

// --- static member definitions (initialized in Init) -------------------------
double   Escalation::s_hwm;
datetime Escalation::s_dayKey;
bool     Escalation::s_locked;
double   Escalation::s_peakDdFrac;
