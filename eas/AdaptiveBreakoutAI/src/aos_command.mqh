//+------------------------------------------------------------------+
//| aos_command.mqh - MI-003: AOS command channel + telemetry routing |
//|                                                                    |
//| The EA consumes the AOS command as a 104-byte SBridgePacket binary |
//| in FILE_COMMON (Common\Files\adaptivebo_command_<SYMBOL>.bin) and  |
//| writes its decision back as a status SBridgePacket                 |
//| (adaptivebo_status_<SYMBOL>.bin). Both files are written/read      |
//| atomically and validated (magic/version/CRC) on every use.         |
//|                                                                    |
//| Conflict priority (non-negotiable): BLOCK > HOLD > BUY/SELL.       |
//|   - BLOCK / UNKNOWN / STALE command  => HOLD (no trade evaluation) |
//|   - HOLD command                      => HOLD (blocks BUY/SELL)     |
//|   - BUY/SELL command                  => gate ONLY that direction; |
//|     the local strategy keeps its own intent AND the local risk     |
//|     gates keep FINAL VETO (this module never places orders).       |
//|                                                                    |
//| Staleness clock: the command's ts_sec PAYLOAD field (UTC epoch),   |
//| NOT file mtime — same payload-clock rule as the observation tap    |
//| (ts_ms). Both ends agree on the HOLD boundary.                     |
//+------------------------------------------------------------------+
#property strict

#include "SBridgePacket.mqh"

// --- MI-003 enums (FILE SCOPE so the EA input block can reference them) -------
enum AosCmdState
{
    AOS_STATE_UNKNOWN = -1,
    AOS_STATE_HOLD    = 0,
    AOS_STATE_BUY     = 1,
    AOS_STATE_SELL    = 2,
    AOS_STATE_BLOCK   = 3
};

enum AosSimCmd
{
    AOS_SIM_OFF   = 0,
    AOS_SIM_HOLD  = 1,
    AOS_SIM_BUY   = 2,
    AOS_SIM_SELL  = 3,
    AOS_SIM_BLOCK = 4
};

class AosCommand
{
private:
    static bool s_enabled;
    static int  s_staleSec;
    static int  s_simCmd;
    static long s_lastStatusMs;
    static int  s_lastStatusState;

public:
    static void Configure(const bool enabled, const int staleSec, const int simCmd)
    {
        s_enabled   = enabled;
        s_staleSec  = (staleSec >= 1) ? staleSec : 2;
        s_simCmd    = simCmd;
        s_lastStatusMs = 0;
        s_lastStatusState = AOS_STATE_UNKNOWN;
    }

    // Current AOS command state for a symbol (AosCmdState).
    // Priority semantics are applied by the CALLER via PriorityGate().
    static int ReadCommand(const string symbol)
    {
        // Simulation override (acceptance testing path).
        if(s_simCmd != AOS_SIM_OFF)
        {
            switch(s_simCmd)
            {
                case AOS_SIM_HOLD:  return(AOS_STATE_HOLD);
                case AOS_SIM_BUY:   return(AOS_STATE_BUY);
                case AOS_SIM_SELL:  return(AOS_STATE_SELL);
                case AOS_SIM_BLOCK: return(AOS_STATE_BLOCK);
                default:            return(AOS_STATE_UNKNOWN);
            }
        }

        // Real channel: read + verify the 104-byte command packet.
        string fname = "adaptivebo_command_" + symbol + ".bin";
        if(!FileIsExist(fname, FILE_COMMON))
            return(AOS_STATE_UNKNOWN);          // no command => HOLD (fail-closed)

        SBridgePacket pkt;
        int fh = FileOpen(fname, FILE_READ | FILE_BIN | FILE_COMMON);
        if(fh == INVALID_HANDLE)
            return(AOS_STATE_UNKNOWN);
        bool ok = FileReadStruct(fh, pkt);
        FileClose(fh);
        if(!ok || !SBPacketVerify(pkt))
            return(AOS_STATE_UNKNOWN);          // corrupted/invalid => HOLD

        // Staleness: PAYLOAD ts_sec (UTC), not file mtime.
        long ageSec = (long)TimeGMT() - (long)SB_U32FromBytes(pkt.ts_sec);
        if(ageSec < 0 || ageSec > (long)s_staleSec)
            return(AOS_STATE_UNKNOWN);          // stale => HOLD

        int cmd = (int)pkt.cmd_type;
        if(cmd < AOS_STATE_HOLD || cmd > AOS_STATE_BLOCK)
            return(AOS_STATE_UNKNOWN);
        return(cmd);
    }

    // Priority gate: true => the EA may proceed past the AOS layer.
    // BLOCK/UNKNOWN => false (hard HOLD). HOLD => false (blocks trades).
    // BUY/SELL => true (direction gating happens downstream).
    static bool PriorityGate(const int state)
    {
        return(state == AOS_STATE_BUY || state == AOS_STATE_SELL);
    }

    // Write the EA decision back to AOS as a status SBridgePacket
    // (atomic tmp -> FileMove). status uses SB_STATUS_*; flags use
    // SB_FLAG_* (override_valid / risk_veto).
    static void WriteStatus(const string symbol, const int cmdState, const int status, const int flags)
    {
        long nowMs = (long)TimeGMT() * 1000 + (long)(GetTickCount() % 1000);
        bool stateChanged = (cmdState != s_lastStatusState);
        if(!stateChanged && (nowMs - s_lastStatusMs) < 1000)
            return;                              // throttle: 1 Hz unless state changed

        SBridgePacket pkt;
        int cmd = (cmdState == AOS_STATE_UNKNOWN) ? SB_CMD_HOLD : cmdState;  // unknown => decision HOLD
        SBPacketInit(pkt, (uchar)cmd, (uchar)status);
        SBPacketSetSymbol(pkt, symbol);
        if(flags != 0)
            pkt.flags = (uchar)flags;
        SBPacketComputeCrc(pkt);

        string tmpName = "adaptivebo_status_" + symbol + ".bin.tmp";
        string dstName = "adaptivebo_status_" + symbol + ".bin";
        int fh = FileOpen(tmpName, FILE_WRITE | FILE_BIN | FILE_COMMON);
        if(fh == INVALID_HANDLE)
            return;
        FileWriteStruct(fh, pkt);
        FileClose(fh);
        if(!FileMove(tmpName, FILE_COMMON, dstName, FILE_REWRITE))
            FileDelete(tmpName, FILE_COMMON);

        s_lastStatusMs = nowMs;
        s_lastStatusState = cmdState;
    }
};

// --- static member definitions (initialized in Configure) --------------------
bool AosCommand::s_enabled;
int  AosCommand::s_staleSec;
int  AosCommand::s_simCmd;
long AosCommand::s_lastStatusMs;
int  AosCommand::s_lastStatusState;
