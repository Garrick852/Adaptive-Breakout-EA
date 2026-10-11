"""Contract tests for the MI-001 104-byte SBridgePacket (AOS side).

Pins the non-negotiable wire contract: exactly 104 bytes, magic "SR",
version 1, contiguous field map, CRC-16/MODBUS over bytes 0..101, and
HOLD-safe defaults (cmd_type=HOLD, status=OK).
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from bridge.contracts.sbridge_packet import (  # noqa: E402
    FIELD_MAP,
    PACKET_SIZE,
    CmdType,
    ContractError,
    Status,
    crc16_modbus,
    decode,
    encode,
    validate,
    validate_field_map,
)

EXPECTED_OFFSETS = {
    "magic": (0, 2),
    "version": (2, 1),
    "cmd_type": (3, 1),
    "status": (4, 1),
    "flags": (5, 1),
    "reserved1": (6, 2),
    "seq_id": (8, 4),
    "ts_sec": (12, 4),
    "symbol": (16, 20),
    "lot": (36, 4),
    "price_ref": (40, 4),
    "reserved2": (44, 56),
    "reserved3": (100, 2),
    "crc16": (102, 2),
}


def test_packet_is_exactly_104_bytes():
    assert PACKET_SIZE == 104
    assert len(encode()) == 104
    assert len(encode({"symbol": "XAUUSD", "lot": 0.5})) == 104


def test_field_map_is_contiguous_and_covers_exactly_104():
    validate_field_map()  # raises on gap/overlap/miscount
    assert {name: (off, size) for name, off, size in FIELD_MAP} == EXPECTED_OFFSETS


def test_roundtrip_preserves_values():
    pkt = encode(
        {
            "cmd_type": CmdType.SELL,
            "status": Status.OK,
            "flags": 1,
            "seq_id": 7,
            "ts_sec": 1_752_998_400,
            "symbol": "EURUSD",
            "lot": 0.10,
            "price_ref": 1.0850,
        }
    )
    parsed = decode(pkt)
    assert parsed["cmd_type"] == CmdType.SELL
    assert parsed["status"] == Status.OK
    assert parsed["seq_id"] == 7
    assert parsed["symbol"] == "EURUSD"
    assert abs(parsed["lot"] - 0.10) < 1e-6
    assert abs(parsed["price_ref"] - 1.0850) < 1e-6


def test_defaults_are_hold_safe():
    pkt = encode()
    parsed = decode(pkt)
    assert parsed["cmd_type"] == CmdType.HOLD  # 0 = HOLD by default
    assert parsed["status"] == Status.OK
    assert parsed["symbol"] == ""
    assert parsed["lot"] == 0.0
    assert parsed["price_ref"] == 0.0


def test_rejects_wrong_size():
    with pytest.raises(ContractError, match="size mismatch"):
        validate(b"\x00" * 103)
    with pytest.raises(ContractError, match="size mismatch"):
        validate(b"\x00" * 105)


def test_rejects_bad_magic():
    pkt = bytearray(encode())
    pkt[0], pkt[1] = pkt[1], pkt[0]  # "SR" -> "RS"
    with pytest.raises(ContractError, match="magic"):
        validate(bytes(pkt))


def test_rejects_unknown_version():
    pkt = bytearray(encode())
    pkt[2] = 99
    with pytest.raises(ContractError, match="version"):
        validate(bytes(pkt))


def test_rejects_corrupted_payload_via_crc():
    pkt = bytearray(encode({"symbol": "EURUSD", "lot": 0.1}))
    pkt[20] ^= 0xFF  # flip a byte inside symbol (payload region)
    with pytest.raises(ContractError, match="crc"):
        validate(bytes(pkt))


def test_rejects_tampered_crc_field():
    pkt = bytearray(encode())
    pkt[102] ^= 0xFF
    with pytest.raises(ContractError, match="crc"):
        validate(bytes(pkt))


def test_crc_known_vector():
    # CRC-16/MODBUS("123456789") == 0x4B37
    assert crc16_modbus(b"123456789") == 0x4B37


def test_symbol_padding_and_truncation():
    pkt = encode({"symbol": "EURUSD"})
    assert pkt[16:36] == b"EURUSD" + b"\x00" * 14
    long_sym = encode({"symbol": "X" * 30})
    assert long_sym[16:36] == b"X" * 20
