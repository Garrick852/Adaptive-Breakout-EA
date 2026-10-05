"""Source-level MQL regression checks; no terminal, account or file-channel writes.

Evaluate the actual EA gate/direction/status expressions rather than a copied
Python policy. Pin the surrounding safety wiring separately. These checks do
not replace MT5 strategy/backtest validation.
"""

import re
from pathlib import Path

import pytest

SRC = Path(__file__).resolve().parents[2] / "eas" / "AdaptiveBreakoutAI" / "src"
EA = (SRC / "AdaptiveBreakoutAI.mq5").read_text(encoding="utf-8")
COMMAND = (SRC / "aos_command.mqh").read_text(encoding="utf-8")
TRADE = (SRC / "trade_exec.mqh").read_text(encoding="utf-8")
CONSTANTS = {
    name: int(value)
    for name, value in re.findall(r"\b((?:AOS_STATE_|DIR_)\w+)\s*=\s*(-?\d+)", COMMAND + TRADE)
}


def expression(pattern: str, source: str = EA) -> str:
    match = re.search(pattern, source, re.DOTALL)
    assert match, f"Missing MQL expression: {pattern}"
    return match[1].strip()


def evaluate(code: str, **values):
    """Evaluate only the small C/MQL expression subset used at this boundary."""
    code = code.strip()
    # Remove balanced enclosing parentheses, not parentheses around a subexpression.
    while code.startswith("(") and code.endswith(")"):
        depth = 0
        for _index, char in enumerate(code):
            depth += (char == "(") - (char == ")")
            if depth == 0:
                break
        if _index != len(code) - 1:
            break
        code = code[1:-1].strip()
    depth = 0
    question = None
    for index, char in enumerate(code):
        depth += (char == "(") - (char == ")")
        if depth == 0 and char == "?":
            question = index
        elif depth == 0 and char == ":" and question is not None:
            if code[index - 1] == ":" or code[index + 1] == ":":
                continue
            branch = (
                code[question + 1 : index]
                if evaluate(code[:question], **values)
                else code[index + 1 :]
            )
            return evaluate(branch, **values)
    code = code.replace("TradeExec::", "").replace("AosCommand::", "")
    code = code.replace("&&", " and ").replace("||", " or ")
    code = re.sub(r"!(?!=)", " not ", code).strip()
    return eval(code, {"__builtins__": {}}, CONSTANTS | values)  # trusted repository expressions


def boundary(controlled: bool, armed: bool, observed: bool, command: int):
    reads = []

    def read_command(_symbol):
        reads.append(command)
        return command

    values = {
        "InpAosCmdEnabled": controlled,
        "InpEnableTrading": armed,
        "obsOk": observed,
        "_Symbol": "TEST",
        "ReadCommand": read_command,
        "PriorityGate": lambda state: evaluate(
            expression(r"static bool PriorityGate.*?return\((.*?)\);", COMMAND), state=state
        ),
    }
    values["aosCmd"] = evaluate(expression(r"int aosCmd = (.*?);"), **values)
    values["aosOk"] = evaluate(expression(r"bool aosOk = (.*?);"), **values)
    holds = evaluate(expression(r"if\((!obsOk.*?)\)\s*\{"), **values)
    direction = (
        None
        if holds
        else evaluate(expression(r"TradeExec::Direction allowedDir = (.*?);"), **values)
    )
    return holds, direction, reads


@pytest.mark.parametrize("controlled", [False, True])
@pytest.mark.parametrize("command", [-1, 0, 1, 2, 3, 99])
def test_disabled_execution_always_holds(controlled, command):
    assert boundary(controlled, False, True, command)[:2] == (True, None)


@pytest.mark.parametrize("command", [-1, 0, 1, 2, 3, 99])
def test_native_never_reads_publisher_and_allows_both_local_directions(command):
    assert boundary(False, True, True, command) == (False, CONSTANTS["DIR_ANY"], [])


@pytest.mark.parametrize("controlled", [False, True])
@pytest.mark.parametrize("command", [-1, 0, 1, 2, 3, 99])
def test_observation_veto_survives_mode_selection(controlled, command):
    assert boundary(controlled, True, False, command)[:2] == (True, None)


@pytest.mark.parametrize("command", [-1, 0, 3, 99])
def test_controlled_unknown_hold_block_and_invalid_commands_hold(command):
    assert boundary(True, True, True, command)[:2] == (True, None)


@pytest.mark.parametrize("command,direction", [(1, "DIR_BUY"), (2, "DIR_SELL")])
def test_controlled_valid_commands_restrict_direction(command, direction):
    assert boundary(True, True, True, command) == (False, CONSTANTS[direction], [command])


@pytest.mark.parametrize("controlled", [False, True])
@pytest.mark.parametrize("attempted", [False, True])
@pytest.mark.parametrize("command", [-1, 1, 2])
def test_native_status_never_fabricates_remote_buy_or_sell(controlled, attempted, command):
    status = evaluate(
        expression(r"AosCommand::WriteStatus\(_Symbol,\s*(\(InpAosCmdEnabled.*?)\s*,"),
        InpAosCmdEnabled=controlled,
        trade_executed=attempted,
        aosCmd=command,
    )
    assert status == (command if controlled and attempted else CONSTANTS["AOS_STATE_HOLD"])


def test_defaults_are_unarmed_controlled_and_not_simulated():
    assert re.search(r"input bool\s+InpEnableTrading\s*=\s*false;", EA)
    assert re.search(r"input bool\s+InpAosCmdEnabled\s*=\s*true;", EA)
    assert re.search(r"input AosSimCmd\s+InpAosSimCmd\s*=\s*AOS_SIM_OFF;", EA)
    assert re.search(r"input bool\s+InpTapEnabled\s*=\s*true;", EA)


@pytest.mark.parametrize(
    "condition",
    [
        "Escalation::OnTick(_Symbol)",
        "!Utils::IsWithinSession(InpSessionStartHour, InpSessionEndHour)",
        "!PropRules::AllowTrading(InpOperMode, InpDailyLossStopPct, InpMaxTotalDDPct)",
        "!PortfolioAgent::AllowNewTrade(InpMaxGlobalRiskPct)",
        "!Utils::PassedCooldownMinutes(InpMinMinutesBetweenTrades)",
        "Risk::HasOpenPosition(_Symbol)",
        "atr <= 0.0",
    ],
)
def test_local_veto_returns_before_either_strategy_in_all_modes(condition):
    tick = EA[EA.index("void OnTick()") : EA.index("double OnTester()")]
    guard = re.search(r"if\s*\(" + re.escape(condition) + r"\)\s*\{([^{}]*)\}", tick)
    assert guard
    assert "return;" in guard[1]
    assert "InpAosCmdEnabled" not in guard[1]
    assert guard.end() < tick.index("StrategyBreakout::Run")
    assert guard.end() < tick.index("StrategyMeanRevert::Run")
    assert tick.index("Escalation::OnTick") < tick.index("ReadCommand")
    assert tick.index("Escalation::OnTick") < tick.index("ObservationTap::OnTick")


@pytest.mark.parametrize("strategy", ["strategy_breakout.mqh", "strategy_meanrevert.mqh"])
def test_both_strategies_receive_and_enforce_allowed_direction(strategy):
    source = (SRC / strategy).read_text(encoding="utf-8")
    assert "allowedDir != TradeExec::DIR_ANY && dir != allowedDir" in source
    assert source.index("dir != allowedDir") < source.index("TradeExec::MarketOrder")
    if "PendingStopOrder" in source:
        assert source.index("dir != allowedDir") < source.index("TradeExec::PendingStopOrder")
    assert len(re.findall(r"\ballowedDir\);", EA)) == 2


def test_command_reader_retains_fail_closed_checks():
    reader = COMMAND[
        COMMAND.index("static int ReadCommand") : COMMAND.index("static bool PriorityGate")
    ]
    for check in [
        "!FileIsExist(fname, FILE_COMMON)",
        "fh == INVALID_HANDLE",
        "!ok || !SBPacketVerify(pkt)",
        "ageSec < 0 || ageSec > (long)s_staleSec",
        "cmd < AOS_STATE_HOLD || cmd > AOS_STATE_BLOCK",
    ]:
        guard = re.search(r"if\(" + re.escape(check) + r"\)\s*return\((.*?)\);", reader)
        assert guard and guard[1] == "AOS_STATE_UNKNOWN"
    assert "SB_U32FromBytes(pkt.ts_sec)" in reader
    assert re.search(r"InpAosCmdStaleSec\s*=\s*2;", EA)


@pytest.mark.parametrize("age", [-1, 0, 2, 3])
def test_payload_freshness_boundary(age):
    stale = evaluate(
        expression(r"if\((ageSec < 0.*?)\)\s*return", COMMAND).replace("(long)", ""),
        ageSec=age,
        s_staleSec=2,
    )
    assert stale == (age < 0 or age > 2)
