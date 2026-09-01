"""AOS-side SBridgePacket decoder — MI-001 dual-end static check.

Mirrors the MQL5 contract in ``eas/AdaptiveBreakoutAI/src/SBridgePacket.mqh``:

- exactly 104 bytes, little-endian numerics
- ``magic`` "SR", ``version`` == 1
- ``crc16`` = CRC-16/MODBUS over bytes 0..101

At AOS startup call :func:`validate_field_map` + :func:`validate` so a drifted
layout fails loudly instead of silently mis-parsing (the same guarantee the EA
gets from ``SBPacketValidateLayout()`` in ``OnInit``).

Layout (see docs/ADAPTIVEBO_MI_MAP.md §3):
    magic[2] | version[1] | cmd_type[1] | status[1] | flags[1] | reserved1[2]
    | seq_id[4] | ts_sec[4] | symbol[20] | lot[4] | price_ref[4]
    | reserved2[56] | reserved3[2] | crc16[2]
"""
from __future__ import annotations

import enum
import struct
from typing import Dict, Optional

PACKET_SIZE = 104
MAGIC = b"SR"
VERSION = 1
CRC_COVERED = 102  # crc16 field (102..103) is excluded from the CRC itself

# (name, offset, size) — single source of truth for offset validation.
FIELD_MAP: tuple[tuple[str, int, int], ...] = (
    ("magic", 0, 2),
    ("version", 2, 1),
    ("cmd_type", 3, 1),
    ("status", 4, 1),
    ("flags", 5, 1),
    ("reserved1", 6, 2),
    ("seq_id", 8, 4),
    ("ts_sec", 12, 4),
    ("symbol", 16, 20),
    ("lot", 36, 4),
    ("price_ref", 40, 4),
    ("reserved2", 44, 56),
    ("reserved3", 100, 2),
    ("crc16", 102, 2),
)


class CmdType(enum.IntEnum):
    HOLD = 0
    BUY = 1
    SELL = 2
    BLOCK = 3


class Status(enum.IntEnum):
    OK = 0
    STALE = 1
    ERROR = 2
    LOCKED = 3


class ContractError(RuntimeError):
    """Raised on any contract violation (size, magic, version, CRC, offsets)."""


def crc16_modbus(data: bytes) -> int:
    """CRC-16/MODBUS (poly 0x8005 reflected = 0xA001), init 0xFFFF."""
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0xA001
            else:
                crc >>= 1
    return crc & 0xFFFF


def validate_field_map() -> None:
    """Assert the field map covers 0..104 contiguously with no gap/overlap."""
    cursor = 0
    for name, offset, size in FIELD_MAP:
        if offset != cursor:
            raise ContractError(
                f"field map gap/overlap at {name!r}: expected offset {cursor}, got {offset}"
            )
        cursor += size
    if cursor != PACKET_SIZE:
        raise ContractError(
            f"field map covers {cursor} bytes, contract is {PACKET_SIZE}"
        )


def _encode_symbol(value: str) -> bytes:
    raw = value.encode("ascii", "replace")[:20]
    return raw + b"\x00" * (20 - len(raw))


def _decode_symbol(raw: bytes) -> str:
    return raw.rstrip(b"\x00").decode("ascii", "replace")


def encode(fields: Optional[Dict] = None) -> bytes:
    """Build a 104-byte packet. Defaults are the HOLD-safe zeros + magic/version."""
    buf = bytearray(PACKET_SIZE)
    buf[0:2] = MAGIC
    buf[2] = VERSION
    fields = fields or {}
    buf[3] = fields.get("cmd_type", CmdType.HOLD)
    buf[4] = fields.get("status", Status.OK)
    buf[5] = fields.get("flags", 0)
    struct.pack_into("<I", buf, 8, int(fields.get("seq_id", 0)))
    struct.pack_into("<I", buf, 12, int(fields.get("ts_sec", 0)))
    buf[16:36] = _encode_symbol(str(fields.get("symbol", "")))
    if "lot" in fields:
        struct.pack_into("<f", buf, 36, float(fields["lot"]))
    if "price_ref" in fields:
        struct.pack_into("<f", buf, 40, float(fields["price_ref"]))
    # reserved2/reserved3 stay zero; crc16 covers bytes 0..101
    crc = crc16_modbus(bytes(buf[:CRC_COVERED]))
    buf[102] = (crc >> 8) & 0xFF
    buf[103] = crc & 0xFF
    return bytes(buf)


def decode(buffer: bytes) -> Dict:
    """Validate + decode a packet into a dict. Raises ContractError on any violation."""
    validate(buffer)
    buf = buffer
    return {
        "magic": buf[0:2].decode("ascii"),
        "version": buf[2],
        "cmd_type": buf[3],
        "status": buf[4],
        "flags": buf[5],
        "seq_id": struct.unpack_from("<I", buf, 8)[0],
        "ts_sec": struct.unpack_from("<I", buf, 12)[0],
        "symbol": _decode_symbol(buf[16:36]),
        "lot": struct.unpack_from("<f", buf, 36)[0],
        "price_ref": struct.unpack_from("<f", buf, 40)[0],
    }


def validate(buffer: bytes) -> None:
    """Startup/receive validation: length, magic, version, CRC (and field map)."""
    validate_field_map()
    if len(buffer) != PACKET_SIZE:
        raise ContractError(
            f"payload size mismatch: got {len(buffer)} bytes, contract is {PACKET_SIZE}"
        )
    if buffer[0:2] != MAGIC:
        raise ContractError(f"magic mismatch: got {buffer[0:2]!r}, expected {MAGIC!r}")
    if buffer[2] != VERSION:
        raise ContractError(f"version mismatch: got {buffer[2]}, expected {VERSION}")
    expected = crc16_modbus(buffer[:CRC_COVERED])
    got = (buffer[102] << 8) | buffer[103]
    if got != expected:
        raise ContractError(f"crc mismatch: got 0x{got:04X}, expected 0x{expected:04X}")


if __name__ == "__main__":
    pkt = encode(
        {
            "cmd_type": CmdType.BUY,
            "status": Status.OK,
            "seq_id": 42,
            "ts_sec": 1_752_998_400,
            "symbol": "EURUSD",
            "lot": 0.10,
            "price_ref": 1.0850,
        }
    )
    validate(pkt)
    parsed = decode(pkt)
    assert len(pkt) == PACKET_SIZE == 104, "contract size violated"
    assert parsed["cmd_type"] == CmdType.BUY
    assert parsed["symbol"] == "EURUSD"
    assert abs(parsed["lot"] - 0.10) < 1e-6
    print(f"[MI-001] SBridgePacket size: {len(pkt)} bytes (contract {PACKET_SIZE})")
    print("[MI-001] dual-end static checks PASS (length/magic/version/offsets/crc)")
