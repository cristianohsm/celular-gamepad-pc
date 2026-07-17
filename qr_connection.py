"""Offline QR pairing helpers. This module never opens a network connection."""
from __future__ import annotations

from dataclasses import dataclass
import ipaddress
import json
import re
import subprocess
from typing import Any, Callable, Iterable
from urllib.parse import urlencode

from vendor.qrcodegen import QrCode


PRIVATE_NETWORKS = tuple(
    ipaddress.ip_network(network)
    for network in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16")
)
VALID_PLAYERS = frozenset({"auto", "1", "2"})


@dataclass(frozen=True)
class LanAddress:
    ip: str
    interface: str = "Rede local"
    active: bool = True


def is_private_ipv4(value: str) -> bool:
    """Accept only RFC1918 IPv4 addresses; reject loopback and APIPA."""
    try:
        address = ipaddress.ip_address(value)
    except ValueError:
        return False
    return isinstance(address, ipaddress.IPv4Address) and any(address in network for network in PRIVATE_NETWORKS)


def _interface_priority(name: str) -> int:
    lowered = name.casefold()
    if any(token in lowered for token in ("wi-fi", "wifi", "wlan", "wireless")):
        return 0
    if any(token in lowered for token in ("ethernet", "lan", "eth")):
        return 1
    return 2


def select_lan_addresses(candidates: Iterable[LanAddress]) -> list[LanAddress]:
    """Keep private active addresses, with Wi-Fi/Ethernet first and no duplicates."""
    unique: dict[str, LanAddress] = {}
    for item in candidates:
        if item.active and is_private_ipv4(item.ip) and item.ip not in unique:
            unique[item.ip] = item
    return sorted(unique.values(), key=lambda item: (_interface_priority(item.interface), item.interface.casefold(), item.ip))


def _parse_windows_addresses(raw: str) -> list[LanAddress]:
    if not raw.strip():
        return []
    try:
        decoded: Any = json.loads(raw)
    except json.JSONDecodeError:
        return []
    rows = decoded if isinstance(decoded, list) else [decoded]
    result: list[LanAddress] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        ip = row.get("ip")
        interface = row.get("interface")
        if isinstance(ip, str):
            result.append(LanAddress(ip=ip, interface=str(interface or "Rede local"), active=True))
    return result


def discover_lan_addresses(
    manual_ip: str = "",
    runner: Callable[..., Any] = subprocess.run,
) -> list[LanAddress]:
    """Read active Windows adapters locally; an optional RFC1918 address is a fallback."""
    candidates: list[LanAddress] = []
    if manual_ip.strip() and is_private_ipv4(manual_ip.strip()):
        candidates.append(LanAddress(manual_ip.strip(), "Endereço manual"))
    command = (
        "$ErrorActionPreference='Stop';Get-NetIPConfiguration|Where-Object "
        "{$_.NetAdapter.Status -eq 'Up' -and $_.IPv4Address}|ForEach-Object "
        "{$alias=$_.InterfaceAlias;$_.IPv4Address|ForEach-Object "
        "{[pscustomobject]@{ip=$_.IPAddress;interface=$alias}}}|ConvertTo-Json -Compress"
    )
    try:
        completed = runner(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", command],
            capture_output=True,
            text=True,
            check=False,
            timeout=3,
        )
        if getattr(completed, "returncode", 1) == 0:
            candidates.extend(_parse_windows_addresses(str(getattr(completed, "stdout", ""))))
    except (OSError, subprocess.SubprocessError):
        pass
    return select_lan_addresses(candidates)


def validate_player(value: object) -> str:
    player = str(value)
    if player not in VALID_PLAYERS:
        raise ValueError("Jogador de conexão inválido")
    return player


def build_pairing_url(ip: str, port: int, pin: str, player: object = "auto") -> str:
    if not is_private_ipv4(ip):
        raise ValueError("O QR exige um IPv4 privado válido")
    if not isinstance(port, int) or not 1 <= port <= 65535:
        raise ValueError("Porta inválida")
    if not re.fullmatch(r"\d{6}", pin):
        raise ValueError("PIN temporário inválido")
    return f"http://{ip}:{port}/?{urlencode({'pin': pin, 'player': validate_player(player)})}"


def qr_matrix(text: str) -> list[list[bool]]:
    code = QrCode.encode_text(text, QrCode.Ecc.MEDIUM)
    return [[code.get_module(x, y) for x in range(code.get_size())] for y in range(code.get_size())]


def render_terminal_qr(text: str, border: int = 4) -> list[str]:
    """Render a scan-friendly QR with Unicode half blocks, entirely in memory."""
    matrix = qr_matrix(text)
    size = len(matrix)

    def module(x: int, y: int) -> bool:
        return 0 <= x < size and 0 <= y < size and matrix[y][x]

    rows: list[str] = []
    for y in range(-border, size + border, 2):
        line = []
        for x in range(-border, size + border):
            top, bottom = module(x, y), module(x, y + 1)
            line.append("█" if top and bottom else "▀" if top else "▄" if bottom else " ")
        rows.append("".join(line))
    return rows


def render_qr_svg(text: str, border: int = 4) -> str:
    """Return an SVG string; it is generated locally and never written to disk."""
    matrix = qr_matrix(text)
    size = len(matrix)
    path = "".join(
        f"M{x + border},{y + border}h1v1h-1z"
        for y, row in enumerate(matrix)
        for x, dark in enumerate(row)
        if dark
    )
    total = size + border * 2
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total} {total}" role="img" '
        'aria-label="QR Code de conexão"><rect width="100%" height="100%" fill="#fff"/>'
        f'<path d="{path}" fill="#000"/></svg>'
    )


def redact_pin(text: str) -> str:
    return re.sub(r"(?i)([?&]pin=)[^&\s]+", r"\1***", text)
