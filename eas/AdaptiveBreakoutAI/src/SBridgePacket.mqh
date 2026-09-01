//+------------------------------------------------------------------+
//| SBridgePacket.mqh - 104-byte AOS<->EA wire contract (MI-001)      |
//|                                                                    |
//| NON-NEGOTIABLE: the packet is EXACTLY 104 bytes. Never add,        |
//| remove, or reorder fields. Layout changes bump SB_VERSION and      |
//| BOTH ends (EA + AOS decoder) reject mismatches (see                |
//| docs/ADAPTIVEBO_MI_MAP.md section 3).                              |
//|                                                                    |
//| pack(1) equivalent: every field is uchar, so natural alignment     |
//| is 1 and sizeof(SBridgePacket) == 104 is arithmetic, not luck.     |
//| The EA OnInit() prints the size and returns INIT_FAILED (HOLD-     |
//| safe) if it ever differs.                                          |
//|                                                                    |
//| Layout (little-endian numerics), total 104 bytes:                  |
//|   0   magic[2]    'S','R' (0x53 0x52)                               |
//|   2   version     = 1                                              |
//|   3   cmd_type    0=HOLD 1=BUY 2=SELL 3=BLOCK/EXIT                 |
//|   4   status      0=OK 1=STALE 2=ERROR 3=LOCKED                    |
//|   5   flags       bit0 override_valid, bit1 risk_veto              |
//|   6   reserved1[2]                                                 |
//|   8   seq_id[4]    uint32 LE                                       |
//|   12  ts_sec[4]    uint32 LE, UTC epoch seconds                    |
//|   16  symbol[20]   fixed, null-padded                              |
//|   36  lot[4]       float32 LE (IEEE-754)                           |
//|   40  price_ref[4] float32 LE (IEEE-754)                           |
//|   44  reserved2[56]                                                |
//|   100 reserved3[2]                                                 |
//|   102 crc16[2]     CRC-16/MODBUS over bytes 0..101                 |
//+------------------------------------------------------------------+
#property strict

#define SB_PACKET_SIZE   104
#define SB_MAGIC_0       0x53                    // 'S'
#define SB_MAGIC_1       0x52                    // 'R'
#define SB_VERSION       1
#define SB_CRC_COVERED   102                     // crc16 covers bytes 0..101

// cmd_type values (precedence BLOCK > HOLD > BUY/SELL)
#define SB_CMD_HOLD      0
#define SB_CMD_BUY       1
#define SB_CMD_SELL      2
#define SB_CMD_BLOCK     3

// status values
#define SB_STATUS_OK     0
#define SB_STATUS_STALE  1
#define SB_STATUS_ERROR  2
#define SB_STATUS_LOCKED 3

// flags bits
#define SB_FLAG_OVERRIDE_VALID  1
#define SB_FLAG_RISK_VETO       2

//+------------------------------------------------------------------+
//| The contract struct: all-uchar => 1-byte alignment, sizeof == 104|
//+------------------------------------------------------------------+
struct SBridgePacket
{
    uchar  magic[2];
    uchar  version;
    uchar  cmd_type;
    uchar  status;
    uchar  flags;
    uchar  reserved1[2];
    uchar  seq_id[4];
    uchar  ts_sec[4];
    uchar  symbol[20];
    uchar  lot[4];
    uchar  price_ref[4];
    uchar  reserved2[56];
    uchar  reserved3[2];
    uchar  crc16[2];
};

//+------------------------------------------------------------------+
//| IEEE-754 binary32 <-> bytes (little-endian; x86 target).          |
//+------------------------------------------------------------------+
union SB_FloatBytes
{
    float f;
    uchar b[4];
};

//+------------------------------------------------------------------+
//| Copy the struct into a 104-byte buffer (explicit, field by field,|
//| so layout drift can never silently corrupt the wire image).      |
//+------------------------------------------------------------------+
inline void SBPacketToBytes(const SBridgePacket &pkt, uchar &out[])
{
    ArrayResize(out, SB_PACKET_SIZE);
    ArrayInitialize(out, 0);
    int dst = 0;
    ArrayCopy(out, pkt.magic,     dst, 0, 2);  dst += 2;
    out[dst++] = pkt.version;
    out[dst++] = pkt.cmd_type;
    out[dst++] = pkt.status;
    out[dst++] = pkt.flags;
    ArrayCopy(out, pkt.reserved1, dst, 0, 2);  dst += 2;
    ArrayCopy(out, pkt.seq_id,    dst, 0, 4);  dst += 4;
    ArrayCopy(out, pkt.ts_sec,    dst, 0, 4);  dst += 4;
    ArrayCopy(out, pkt.symbol,    dst, 0, 20); dst += 20;
    ArrayCopy(out, pkt.lot,       dst, 0, 4);  dst += 4;
    ArrayCopy(out, pkt.price_ref, dst, 0, 4);  dst += 4;
    ArrayCopy(out, pkt.reserved2, dst, 0, 56); dst += 56;
    ArrayCopy(out, pkt.reserved3, dst, 0, 2);  dst += 2;
    ArrayCopy(out, pkt.crc16,     dst, 0, 2);  dst += 2;
}

//+------------------------------------------------------------------+
//| CRC-16/MODBUS (poly 0x8005 reflected = 0xA001), init 0xFFFF,      |
//| over the first SB_CRC_COVERED bytes.                              |
//+------------------------------------------------------------------+
inline int SBPacketCrc16(const uchar &data[], const int len)
{
    int crc = 0xFFFF;
    for(int i = 0; i < len; i++)
    {
        crc ^= (int)data[i];
        for(int b = 0; b < 8; b++)
        {
            if((crc & 1) != 0)
                crc = (crc >> 1) ^ 0xA001;
            else
                crc >>= 1;
        }
    }
    return(crc & 0xFFFF);
}

//+------------------------------------------------------------------+
//| Setters (callers must re-run SBPacketComputeCrc after mutation).  |
//+------------------------------------------------------------------+
inline void SBPacketSetSymbol(SBridgePacket &pkt, const string symbol)
{
    ArrayInitialize(pkt.symbol, 0);
    StringToCharArray(symbol, pkt.symbol, 0, 19, 0);
}

inline void SBPacketSetSeqId(SBridgePacket &pkt, const uint seq)
{
    pkt.seq_id[0] = (uchar)((seq >> 24) & 0xFF);
    pkt.seq_id[1] = (uchar)((seq >> 16) & 0xFF);
    pkt.seq_id[2] = (uchar)((seq >> 8)  & 0xFF);
    pkt.seq_id[3] = (uchar)(seq & 0xFF);
}

inline void SBPacketSetLot(SBridgePacket &pkt, const double lot)
{
    SB_FloatBytes u;
    u.f = (float)lot;
    ArrayCopy(pkt.lot, u.b, 0, 0, 4);
}

inline void SBPacketSetPriceRef(SBridgePacket &pkt, const double price)
{
    SB_FloatBytes u;
    u.f = (float)price;
    ArrayCopy(pkt.price_ref, u.b, 0, 0, 4);
}

//+------------------------------------------------------------------+
//| Compute and store crc16 over bytes 0..SB_CRC_COVERED-1.           |
//+------------------------------------------------------------------+
inline void SBPacketComputeCrc(SBridgePacket &pkt)
{
    uchar tmp[];
    SBPacketToBytes(pkt, tmp);
    int crc = SBPacketCrc16(tmp, SB_CRC_COVERED);
    pkt.crc16[0] = (uchar)((crc >> 8) & 0xFF);
    pkt.crc16[1] = (uchar)(crc & 0xFF);
}

//+------------------------------------------------------------------+
//| Initialize a packet: zero everything, set magic/version/cmd/      |
//| status, stamp seq/ts, recompute crc.                              |
//+------------------------------------------------------------------+
inline void SBPacketInit(SBridgePacket &pkt, const uchar cmdType, const uchar status)
{
    pkt.magic[0]    = SB_MAGIC_0;
    pkt.magic[1]    = SB_MAGIC_1;
    pkt.version     = SB_VERSION;
    pkt.cmd_type    = cmdType;
    pkt.status      = status;
    pkt.flags       = 0;
    pkt.reserved1[0]= 0;
    pkt.reserved1[1]= 0;
    pkt.seq_id[0]   = 0;
    pkt.seq_id[1]   = 0;
    pkt.seq_id[2]   = 0;
    pkt.seq_id[3]   = 0;
    long now = (long)TimeGMT();
    pkt.ts_sec[0]   = (uchar)((now >> 24) & 0xFF);
    pkt.ts_sec[1]   = (uchar)((now >> 16) & 0xFF);
    pkt.ts_sec[2]   = (uchar)((now >> 8)  & 0xFF);
    pkt.ts_sec[3]   = (uchar)(now & 0xFF);
    ArrayInitialize(pkt.symbol, 0);
    pkt.lot[0]      = 0;
    pkt.lot[1]      = 0;
    pkt.lot[2]      = 0;
    pkt.lot[3]      = 0;
    pkt.price_ref[0]= 0;
    pkt.price_ref[1]= 0;
    pkt.price_ref[2]= 0;
    pkt.price_ref[3]= 0;
    ArrayInitialize(pkt.reserved2, 0);
    pkt.reserved3[0]= 0;
    pkt.reserved3[1]= 0;
    pkt.crc16[0]    = 0;
    pkt.crc16[1]    = 0;
    SBPacketSetSeqId(pkt, (uint)TimeLocal());
    SBPacketComputeCrc(pkt);
}

//+------------------------------------------------------------------+
//| Verify magic + version + crc. Returns true when the packet is a   |
//| valid current-contract packet.                                    |
//+------------------------------------------------------------------+
inline bool SBPacketVerify(const SBridgePacket &pkt)
{
    if(pkt.magic[0] != SB_MAGIC_0 || pkt.magic[1] != SB_MAGIC_1)
        return(false);
    if(pkt.version != SB_VERSION)
        return(false);
    uchar tmp[];
    SBPacketToBytes(pkt, tmp);
    int crc = SBPacketCrc16(tmp, SB_CRC_COVERED);
    return(pkt.crc16[0] == (uchar)((crc >> 8) & 0xFF) &&
           pkt.crc16[1] == (uchar)(crc & 0xFF));
}

//+------------------------------------------------------------------+
//| HOLD-safe layout self-check: sizeof must equal the contract size. |
//| Call from OnInit(); on false the EA must NOT trade.               |
//+------------------------------------------------------------------+
inline bool SBPacketValidateLayout()
{
    if(sizeof(SBridgePacket) != SB_PACKET_SIZE)
    {
        PrintFormat("SBridgePacket layout FAILED: sizeof=%d, contract=%d - staying HOLD.",
                    (int)sizeof(SBridgePacket), SB_PACKET_SIZE);
        return(false);
    }
    return(true);
}
