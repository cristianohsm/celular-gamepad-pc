from __future__ import annotations

import math
from typing import Any

PROTOCOL_VERSION = 2
MAX_WEBSOCKET_PAYLOAD = 64 * 1024
BUTTON_NAMES = ("a", "b", "x", "y", "lb", "rb", "view", "menu", "leftStick", "rightStick")
DPAD_NAMES = ("up", "down", "left", "right")
AXIS_NAMES = ("lx", "ly", "rx", "ry", "lt", "rt")
ROOT_FIELDS = {"type", "protocolVersion", "player", "sequence", "timestamp", "buttons", "dpad", "axes"}


class ProtocolError(ValueError):
    pass


def _booleans(value: Any, allowed: tuple[str, ...], field: str) -> dict[str, bool]:
    if value is None:
        return {name: False for name in allowed}
    if not isinstance(value, dict) or any(name not in allowed or not isinstance(item, bool) for name, item in value.items()):
        raise ProtocolError(f"Campo {field} inválido")
    return {name: value.get(name, False) for name in allowed}


def _axes(value: Any) -> dict[str, float]:
    if value is None:
        return {name: 0.0 for name in AXIS_NAMES}
    if not isinstance(value, dict) or any(name not in AXIS_NAMES for name in value):
        raise ProtocolError("Campo axes inválido")
    result: dict[str, float] = {}
    for name in AXIS_NAMES:
        raw = value.get(name, 0.0)
        if isinstance(raw, bool) or not isinstance(raw, (int, float)) or not math.isfinite(raw):
            raise ProtocolError(f"Eixo {name} inválido")
        minimum, maximum = (0.0, 1.0) if name in {"lt", "rt"} else (-1.0, 1.0)
        result[name] = min(max(float(raw), minimum), maximum)
    return result


def validate_gamepad_state(message: Any, expected_player: int, last_sequence: int) -> dict[str, Any]:
    if not isinstance(message, dict) or set(message) - ROOT_FIELDS:
        raise ProtocolError("Mensagem contém campos desconhecidos")
    if message.get("type") != "gamepad_state":
        raise ProtocolError("Tipo de mensagem inválido")
    if message.get("protocolVersion") != PROTOCOL_VERSION:
        raise ProtocolError("Versão de protocolo incompatível")
    player = message.get("player")
    if isinstance(player, bool) or player != expected_player:
        raise ProtocolError("Jogador não corresponde ao slot reservado")
    sequence = message.get("sequence")
    if isinstance(sequence, bool) or not isinstance(sequence, int) or sequence < 0:
        raise ProtocolError("Sequência inválida")
    if sequence <= last_sequence:
        raise ProtocolError("Sequência antiga")
    timestamp = message.get("timestamp", 0)
    if isinstance(timestamp, bool) or not isinstance(timestamp, (int, float)) or not math.isfinite(timestamp):
        raise ProtocolError("Timestamp inválido")
    return {
        "type": "state", "protocolVersion": PROTOCOL_VERSION, "player": expected_player,
        "sequence": sequence, "timestamp": int(timestamp),
        "buttons": _booleans(message.get("buttons"), BUTTON_NAMES, "buttons"),
        "dpad": _booleans(message.get("dpad"), DPAD_NAMES, "dpad"),
        "axes": _axes(message.get("axes")),
    }
