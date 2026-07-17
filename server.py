from __future__ import annotations

import base64
import argparse
import ctypes
import hashlib
import json
import os
import secrets
import socket
import struct
import threading
import time
from ctypes import wintypes
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

from gamepad_protocol import MAX_WEBSOCKET_PAYLOAD, ProtocolError, validate_gamepad_state
from xinput_bridge import OutputCoordinator

ROOT = Path(__file__).resolve().parent
STATIC_DIR = ROOT / "static"
WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


def resolve_data_dir(environ: dict[str, str] | None = None) -> Path:
    environment = os.environ if environ is None else environ
    configured = environment.get("CELULAR_GAMEPAD_DATA_DIR", "").strip()
    return Path(configured).expanduser().resolve() if configured else ROOT


DATA_DIR = resolve_data_dir()
CONFIG_PATH = DATA_DIR / "config.json"

DEFAULT_CONFIG: dict[str, Any] = {
    "port": 8765,
    "output_mode": "keyboard",
    "xinput": {
        "dead_zone": 0.12,
        "smoothing": 0.15,
        "max_update_hz": 60,
    },
    "players": {
        "1": {
            "snes_up": "UP",
            "snes_down": "DOWN",
            "snes_left": "LEFT",
            "snes_right": "RIGHT",
            "snes_a": "X",
            "snes_b": "Z",
            "snes_x": "S",
            "snes_y": "A",
            "snes_l": "Q",
            "snes_r": "W",
            "snes_start": "ENTER",
            "snes_select": "SHIFT",

            "ps5_dpad_up": "UP",
            "ps5_dpad_down": "DOWN",
            "ps5_dpad_left": "LEFT",
            "ps5_dpad_right": "RIGHT",
            "ps5_lstick_up": "W",
            "ps5_lstick_down": "S",
            "ps5_lstick_left": "A",
            "ps5_lstick_right": "D",
            "ps5_rstick_up": "I",
            "ps5_rstick_down": "K",
            "ps5_rstick_left": "J",
            "ps5_rstick_right": "L",
            "ps5_triangle": "T",
            "ps5_circle": "X",
            "ps5_cross": "Z",
            "ps5_square": "R",
            "ps5_l1": "Q",
            "ps5_r1": "E",
            "ps5_l2": "1",
            "ps5_r2": "3",
            "ps5_l3": "C",
            "ps5_r3": "V",
            "ps5_create": "SHIFT",
            "ps5_options": "ENTER",
            "ps5_touchpad": "SPACE",
            "ps5_home": "ESC"
        },
        "2": {
            "snes_up": "NUMPAD8",
            "snes_down": "NUMPAD2",
            "snes_left": "NUMPAD4",
            "snes_right": "NUMPAD6",
            "snes_a": "N",
            "snes_b": "M",
            "snes_x": "H",
            "snes_y": "U",
            "snes_l": "O",
            "snes_r": "P",
            "snes_start": "B",
            "snes_select": "G",

            "ps5_dpad_up": "F1",
            "ps5_dpad_down": "F2",
            "ps5_dpad_left": "F3",
            "ps5_dpad_right": "F4",
            "ps5_lstick_up": "NUMPAD8",
            "ps5_lstick_down": "NUMPAD2",
            "ps5_lstick_left": "NUMPAD4",
            "ps5_lstick_right": "NUMPAD6",
            "ps5_rstick_up": "F5",
            "ps5_rstick_down": "F6",
            "ps5_rstick_left": "F7",
            "ps5_rstick_right": "F8",
            "ps5_triangle": "U",
            "ps5_circle": "N",
            "ps5_cross": "M",
            "ps5_square": "O",
            "ps5_l1": "P",
            "ps5_r1": "Y",
            "ps5_l2": "F9",
            "ps5_r2": "F10",
            "ps5_l3": "F11",
            "ps5_r3": "F12",
            "ps5_create": "B",
            "ps5_options": "H",
            "ps5_touchpad": "G",
            "ps5_home": "NUMPAD0"
        }
    }
}

VK_CODES: dict[str, int] = {
    "BACKSPACE": 0x08,
    "TAB": 0x09,
    "ENTER": 0x0D,
    "SHIFT": 0x10,
    "CTRL": 0x11,
    "ALT": 0x12,
    "ESC": 0x1B,
    "SPACE": 0x20,
    "LEFT": 0x25,
    "UP": 0x26,
    "RIGHT": 0x27,
    "DOWN": 0x28,
    "DELETE": 0x2E,
}
for digit in "0123456789":
    VK_CODES[digit] = ord(digit)
for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
    VK_CODES[letter] = ord(letter)
for number in range(10):
    VK_CODES[f"NUMPAD{number}"] = 0x60 + number
for number in range(1, 13):
    VK_CODES[f"F{number}"] = 0x6F + number


def load_config(config_path: Path | None = None) -> dict[str, Any]:
    """Load a local config, creating a safe default when it is absent."""
    path = config_path or CONFIG_PATH
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(DEFAULT_CONFIG, indent=2, ensure_ascii=False), encoding="utf-8")
        return json.loads(json.dumps(DEFAULT_CONFIG))

    try:
        user_config = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"Não foi possível ler config.json: {exc}") from exc

    if not isinstance(user_config, dict):
        raise RuntimeError("config.json deve conter um objeto JSON.")

    merged = json.loads(json.dumps(DEFAULT_CONFIG))
    if isinstance(user_config.get("port"), int):
        merged["port"] = user_config["port"]
    if user_config.get("output_mode") in {"keyboard", "xinput"}:
        merged["output_mode"] = user_config["output_mode"]
    xinput = user_config.get("xinput")
    if isinstance(xinput, dict):
        for field, minimum, maximum in (
            ("dead_zone", 0.0, 0.5),
            ("smoothing", 0.0, 0.9),
            ("max_update_hz", 10, 60),
        ):
            value = xinput.get(field)
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                merged["xinput"][field] = min(max(value, minimum), maximum)

    # Compatibilidade com a v1.2: o antigo bloco "bindings" vira Jogador 1.
    legacy_bindings = user_config.get("bindings")
    if isinstance(legacy_bindings, dict):
        merged["players"]["1"].update(legacy_bindings)

    players = user_config.get("players")
    if isinstance(players, dict):
        for player_number in ("1", "2"):
            player_bindings = players.get(player_number)
            if isinstance(player_bindings, dict):
                merged["players"][player_number].update(player_bindings)
    return merged


# Tipos Win32 com largura fixa. O SendInput exige que cbSize seja exatamente
# sizeof(INPUT). A union precisa conter também MOUSEINPUT/HARDWAREINPUT; caso
# contrário, em Windows 64 bits a estrutura fica menor e a API retorna erro 87.
WORD = ctypes.c_uint16
DWORD = ctypes.c_uint32
LONG = ctypes.c_int32
UINT = ctypes.c_uint32
ULONG_PTR = ctypes.c_size_t


class MOUSEINPUT(ctypes.Structure):
    _fields_ = [
        ("dx", LONG),
        ("dy", LONG),
        ("mouseData", DWORD),
        ("dwFlags", DWORD),
        ("time", DWORD),
        ("dwExtraInfo", ULONG_PTR),
    ]


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [
        ("wVk", WORD),
        ("wScan", WORD),
        ("dwFlags", DWORD),
        ("time", DWORD),
        ("dwExtraInfo", ULONG_PTR),
    ]


class HARDWAREINPUT(ctypes.Structure):
    _fields_ = [
        ("uMsg", DWORD),
        ("wParamL", WORD),
        ("wParamH", WORD),
    ]


class INPUTUNION(ctypes.Union):
    _fields_ = [
        ("mi", MOUSEINPUT),
        ("ki", KEYBDINPUT),
        ("hi", HARDWAREINPUT),
    ]


class INPUT(ctypes.Structure):
    _anonymous_ = ("union",)
    _fields_ = [("type", DWORD), ("union", INPUTUNION)]


class Win32Keyboard:
    """Injeta pressionamentos de teclado no Windows por meio de SendInput."""

    INPUT_KEYBOARD = 1
    KEYEVENTF_KEYUP = 0x0002

    def __init__(self) -> None:
        if os.name != "nt":
            raise RuntimeError("Win32Keyboard só funciona no Windows.")

        # use_last_error=True permite recuperar corretamente o código de erro
        # da API, em vez de depender do valor global incorreto de outra chamada.
        user32 = ctypes.WinDLL("user32", use_last_error=True)
        self._send_input = user32.SendInput
        self._send_input.argtypes = (UINT, ctypes.POINTER(INPUT), ctypes.c_int)
        self._send_input.restype = UINT

        expected_size = 40 if ctypes.sizeof(ctypes.c_void_p) == 8 else 28
        actual_size = ctypes.sizeof(INPUT)
        if actual_size != expected_size:
            raise RuntimeError(
                f"Estrutura INPUT inválida: {actual_size} bytes; esperado {expected_size}."
            )

    def _send(self, vk_code: int, key_up: bool) -> None:
        flags = self.KEYEVENTF_KEYUP if key_up else 0
        event = INPUT(
            type=self.INPUT_KEYBOARD,
            ki=KEYBDINPUT(
                wVk=vk_code,
                wScan=0,
                dwFlags=flags,
                time=0,
                dwExtraInfo=0,
            ),
        )
        ctypes.set_last_error(0)
        sent = self._send_input(1, ctypes.byref(event), ctypes.sizeof(INPUT))
        if sent != 1:
            error_code = ctypes.get_last_error()
            raise ctypes.WinError(error_code or None)

    def press(self, vk_code: int) -> None:
        self._send(vk_code, key_up=False)

    def release(self, vk_code: int) -> None:
        self._send(vk_code, key_up=True)


class ConsoleKeyboard:
    """Modo de teste para Linux/macOS; apenas mostra os eventos no terminal."""

    def press(self, vk_code: int) -> None:
        print(f"[TESTE] key down VK={vk_code}")

    def release(self, vk_code: int) -> None:
        print(f"[TESTE] key up   VK={vk_code}")


class InputManager:
    def __init__(self, player_bindings: dict[int, dict[str, str]], keyboard: Any | None = None) -> None:
        if keyboard is not None:
            self.keyboard = keyboard
        elif os.environ.get("GAMEPAD_TEST_MODE") == "1" or os.name != "nt":
            self.keyboard = ConsoleKeyboard()
        else:
            self.keyboard = Win32Keyboard()
        self.bindings: dict[int, dict[str, int]] = {}
        for player, bindings in player_bindings.items():
            converted: dict[str, int] = {}
            for logical_button, key_name in bindings.items():
                normalized = str(key_name).strip().upper()
                if normalized not in VK_CODES:
                    print(f"AVISO: tecla ignorada em config.json: jogador {player}, {logical_button}={key_name}")
                    continue
                converted[logical_button] = VK_CODES[normalized]
            self.bindings[player] = converted

        self._lock = threading.RLock()
        self._client_players: dict[str, int] = {}
        self._client_buttons: dict[str, dict[str, int]] = {}
        self._key_counts: dict[int, int] = {}

    def register_client(self, client_id: str, player: int) -> None:
        if player not in self.bindings:
            raise ValueError(f"Jogador inválido: {player}")
        with self._lock:
            self._client_players[client_id] = player
            self._client_buttons.setdefault(client_id, {})

    def press(self, client_id: str, logical_button: str) -> None:
        with self._lock:
            player = self._client_players.get(client_id)
            if player is None:
                return
            vk_code = self.bindings.get(player, {}).get(logical_button)
            if vk_code is None:
                return
            active = self._client_buttons.setdefault(client_id, {})
            if logical_button in active:
                return

            old_count = self._key_counts.get(vk_code, 0)
            if old_count == 0:
                self.keyboard.press(vk_code)
            active[logical_button] = vk_code
            self._key_counts[vk_code] = old_count + 1

    def release(self, client_id: str, logical_button: str) -> None:
        with self._lock:
            active = self._client_buttons.setdefault(client_id, {})
            vk_code = active.get(logical_button)
            if vk_code is None:
                return

            old_count = self._key_counts.get(vk_code, 0)
            new_count = max(old_count - 1, 0)
            if new_count == 0:
                try:
                    self.keyboard.release(vk_code)
                finally:
                    self._key_counts.pop(vk_code, None)
                    active.pop(logical_button, None)
            else:
                self._key_counts[vk_code] = new_count
                active.pop(logical_button, None)

    def release_client(self, client_id: str) -> None:
        self.release_buttons(client_id)
        with self._lock:
            self._client_buttons.pop(client_id, None)
            self._client_players.pop(client_id, None)

    def release_buttons(self, client_id: str) -> None:
        """Release held keys while keeping the authenticated client registered."""
        with self._lock:
            for logical_button in list(self._client_buttons.get(client_id, {})):
                try:
                    self.release(client_id, logical_button)
                except OSError as exc:
                    print(f"AVISO: falha ao soltar {logical_button}: {exc}")
                    self._client_buttons.get(client_id, {}).pop(logical_button, None)

    def release_all(self) -> None:
        with self._lock:
            for client_id in list(self._client_buttons):
                self.release_client(client_id)


class PlayerSlots:
    """Reserva dois slots para que cada celular use teclas independentes."""

    def __init__(self, player_numbers: tuple[int, ...] = (1, 2)) -> None:
        self.player_numbers = player_numbers
        self._lock = threading.RLock()
        self._player_clients: dict[int, str] = {}
        self._client_players: dict[str, int] = {}

    def claim(self, client_id: str, requested: str | int | None) -> int | None:
        with self._lock:
            existing = self._client_players.get(client_id)
            if existing is not None:
                return existing

            if str(requested) in {"1", "2"}:
                candidates = [int(str(requested))]
            else:
                candidates = list(self.player_numbers)

            for player in candidates:
                if player not in self._player_clients:
                    self._player_clients[player] = client_id
                    self._client_players[client_id] = player
                    return player
            return None

    def release(self, client_id: str) -> int | None:
        with self._lock:
            player = self._client_players.pop(client_id, None)
            if player is not None and self._player_clients.get(player) == client_id:
                self._player_clients.pop(player, None)
            return player

    def active_players(self) -> list[int]:
        with self._lock:
            return sorted(self._player_clients)


CONFIG = load_config()
PAIRING_PIN = f"{secrets.randbelow(10000):04d}"
INPUT_MANAGER = InputManager({int(player): bindings for player, bindings in CONFIG["players"].items()})
PLAYER_SLOTS = PlayerSlots()
OUTPUT_COORDINATOR = OutputCoordinator(str(CONFIG.get("output_mode", "keyboard")))


def websocket_send(sock: socket.socket, payload: dict[str, Any], opcode: int = 0x1) -> None:
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    header = bytearray([0x80 | opcode])
    length = len(data)
    if length < 126:
        header.append(length)
    elif length < 65536:
        header.extend([126])
        header.extend(struct.pack("!H", length))
    else:
        header.extend([127])
        header.extend(struct.pack("!Q", length))
    sock.sendall(bytes(header) + data)


def websocket_send_raw(sock: socket.socket, data: bytes, opcode: int) -> None:
    header = bytearray([0x80 | opcode])
    length = len(data)
    if length < 126:
        header.append(length)
    elif length < 65536:
        header.extend([126])
        header.extend(struct.pack("!H", length))
    else:
        header.extend([127])
        header.extend(struct.pack("!Q", length))
    sock.sendall(bytes(header) + data)


def recv_exact(sock: socket.socket, size: int) -> bytes:
    buffer = bytearray()
    while len(buffer) < size:
        chunk = sock.recv(size - len(buffer))
        if not chunk:
            raise ConnectionError("Conexão encerrada")
        buffer.extend(chunk)
    return bytes(buffer)


def websocket_recv(sock: socket.socket) -> tuple[int, bytes]:
    first, second = recv_exact(sock, 2)
    opcode = first & 0x0F
    masked = bool(second & 0x80)
    length = second & 0x7F
    if length == 126:
        length = struct.unpack("!H", recv_exact(sock, 2))[0]
    elif length == 127:
        length = struct.unpack("!Q", recv_exact(sock, 8))[0]
    if length > MAX_WEBSOCKET_PAYLOAD:
        raise ValueError("Mensagem WebSocket excede 64 KiB")
    mask_key = recv_exact(sock, 4) if masked else b""
    payload = bytearray(recv_exact(sock, length))
    if masked:
        for index in range(length):
            payload[index] ^= mask_key[index % 4]
    return opcode, bytes(payload)


def decode_client_message(payload: bytes) -> dict[str, Any] | None:
    """Decode a client message without allowing malformed JSON to escape."""
    try:
        message = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return None
    return message if isinstance(message, dict) else None


class GamepadHandler(BaseHTTPRequestHandler):
    server_version = "CelularGamepad/1.3"

    MIME_TYPES = {
        ".html": "text/html; charset=utf-8",
        ".css": "text/css; charset=utf-8",
        ".js": "application/javascript; charset=utf-8",
        ".json": "application/json; charset=utf-8",
        ".svg": "image/svg+xml",
        ".png": "image/png",
    }

    def log_message(self, fmt: str, *args: Any) -> None:
        print(f"[{self.log_date_time_string()}] {self.client_address[0]} - {fmt % args}")

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/ws" and self.headers.get("Upgrade", "").lower() == "websocket":
            self.handle_websocket()
            return

        if self.path == "/status":
            self.send_json({
                "ok": True,
                "service": "celular-gamepad",
                "version": "1.4.0-beta.2",
                "active_players": PLAYER_SLOTS.active_players(),
                "configured_output_mode": OUTPUT_COORDINATOR.configured_mode,
                "output_mode": OUTPUT_COORDINATOR.effective_mode,
                "virtual_controller_ready": OUTPUT_COORDINATOR.effective_mode == "xinput",
                "time": int(time.time()),
            })
            return

        requested = "index.html" if self.path in {"/", ""} else self.path.lstrip("/").split("?", 1)[0]
        file_path = (STATIC_DIR / requested).resolve()
        if not str(file_path).startswith(str(STATIC_DIR.resolve())) or not file_path.is_file():
            self.send_error(HTTPStatus.NOT_FOUND, "Arquivo não encontrado")
            return

        content = file_path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", self.MIME_TYPES.get(file_path.suffix.lower(), "application/octet-stream"))
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(content)

    def send_json(self, payload: dict[str, Any], status: int = 200) -> None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def handle_websocket(self) -> None:
        ws_key = self.headers.get("Sec-WebSocket-Key")
        if not ws_key:
            self.send_error(HTTPStatus.BAD_REQUEST, "WebSocket inválido")
            return

        accept = base64.b64encode(hashlib.sha1((ws_key + WS_GUID).encode("ascii")).digest()).decode("ascii")
        self.send_response(HTTPStatus.SWITCHING_PROTOCOLS)
        self.send_header("Upgrade", "websocket")
        self.send_header("Connection", "Upgrade")
        self.send_header("Sec-WebSocket-Accept", accept)
        self.end_headers()
        self.wfile.flush()

        client_id = secrets.token_hex(8)
        authenticated = False
        assigned_player: int | None = None
        last_sequence = -1
        last_state_at = 0.0
        self.close_connection = True

        try:
            while True:
                opcode, payload = websocket_recv(self.connection)
                if opcode == 0x8:
                    websocket_send_raw(self.connection, b"", opcode=0x8)
                    break
                if opcode == 0x9:
                    websocket_send_raw(self.connection, payload, opcode=0xA)
                    continue
                if opcode != 0x1:
                    continue

                message = decode_client_message(payload)
                if message is None:
                    websocket_send(self.connection, {"type": "error", "message": "Mensagem inválida"})
                    continue

                message_type = message.get("type")
                if not authenticated:
                    if message_type != "auth" or str(message.get("pin", "")) != PAIRING_PIN:
                        websocket_send(self.connection, {"type": "auth", "ok": False, "message": "PIN incorreto"})
                        continue

                    requested_player = message.get("player", "auto")
                    assigned_player = PLAYER_SLOTS.claim(client_id, requested_player)
                    if assigned_player is None:
                        if str(requested_player) in {"1", "2"}:
                            error_message = f"O Jogador {requested_player} já está conectado. Escolha o outro jogador."
                        else:
                            error_message = "Os dois jogadores já estão conectados."
                        websocket_send(self.connection, {"type": "auth", "ok": False, "message": error_message})
                        continue

                    INPUT_MANAGER.register_client(client_id, assigned_player)
                    authenticated = True
                    websocket_send(self.connection, {
                        "type": "auth", "ok": True, "player": assigned_player,
                        "outputMode": OUTPUT_COORDINATOR.effective_mode,
                        "configuredOutputMode": OUTPUT_COORDINATOR.configured_mode,
                        "virtualControllerReady": OUTPUT_COORDINATOR.effective_mode == "xinput",
                    })
                    print(f"Jogador {assigned_player} conectado: {self.client_address[0]} ({client_id})")
                    continue

                if message_type == "button":
                    if OUTPUT_COORDINATOR.effective_mode != "keyboard":
                        continue
                    button = str(message.get("button", ""))
                    state = message.get("state")
                    try:
                        if state == "down":
                            INPUT_MANAGER.press(client_id, button)
                        elif state == "up":
                            INPUT_MANAGER.release(client_id, button)
                    except OSError as exc:
                        # Um erro de injeção não deve fechar o WebSocket.
                        print(f"ERRO ao processar {button}/{state}: {exc}")
                        websocket_send(
                            self.connection,
                            {"type": "input_error", "message": str(exc)},
                        )
                elif message_type == "gamepad_state" and assigned_player is not None:
                    if OUTPUT_COORDINATOR.effective_mode != "xinput":
                        websocket_send(self.connection, {"type": "error", "message": "Controle virtual não instalado"})
                        continue
                    now = time.monotonic()
                    if now - last_state_at < (1 / 120):
                        continue
                    try:
                        validated = validate_gamepad_state(message, assigned_player, last_sequence)
                    except ProtocolError as exc:
                        if str(exc) != "Sequência antiga":
                            websocket_send(self.connection, {"type": "error", "message": str(exc)})
                        continue
                    last_sequence = int(validated["sequence"])
                    last_state_at = now
                    if not OUTPUT_COORDINATOR.submit(validated):
                        websocket_send(self.connection, {"type": "input_error", "message": "Bridge indisponível"})
                elif message_type == "release_all":
                    if OUTPUT_COORDINATOR.effective_mode == "xinput" and assigned_player is not None:
                        OUTPUT_COORDINATOR.neutralize(assigned_player)
                    else:
                        INPUT_MANAGER.release_buttons(client_id)
                elif message_type == "ping":
                    websocket_send(self.connection, {"type": "pong", "at": int(time.time() * 1000)})
        except (ConnectionError, ConnectionResetError, BrokenPipeError, OSError, ValueError):
            pass
        finally:
            if assigned_player is not None:
                OUTPUT_COORDINATOR.neutralize(assigned_player)
            INPUT_MANAGER.release_client(client_id)
            released_player = PLAYER_SLOTS.release(client_id)
            if authenticated:
                player_label = released_player if released_player is not None else "?"
                print(f"Jogador {player_label} desconectado: {self.client_address[0]} ({client_id})")


def find_lan_ips() -> list[str]:
    """Retorna endereços IPv4 locais úteis, evitando loopback e duplicados."""
    candidates: list[str] = []

    # A rota padrão costuma indicar o endereço certo mesmo sem acesso real
    # à internet; nenhum pacote precisa ser enviado.
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        candidates.append(sock.getsockname()[0])
    except OSError:
        pass
    finally:
        sock.close()

    try:
        for item in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            candidates.append(item[4][0])
    except OSError:
        pass

    result: list[str] = []
    for ip in candidates:
        if ip.startswith("127.") or ip == "0.0.0.0":
            continue
        if ip not in result:
            result.append(ip)
    return result or ["127.0.0.1"]


def parse_arguments(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Celular Gamepad para PC")
    parser.add_argument(
        "--output-mode",
        choices=("keyboard", "xinput"),
        help="Sobrepõe o modo configurado somente nesta execução.",
    )
    return parser.parse_args(argv)


def selected_output_mode(config: dict[str, Any], override: str | None) -> str:
    if override in {"keyboard", "xinput"}:
        return override
    configured = str(config.get("output_mode", "keyboard"))
    return configured if configured in {"keyboard", "xinput"} else "keyboard"


def main(argv: list[str] | None = None) -> None:
    global OUTPUT_COORDINATOR
    args = parse_arguments(argv)
    OUTPUT_COORDINATOR = OutputCoordinator(selected_output_mode(CONFIG, args.output_mode))
    port = int(os.environ.get("GAMEPAD_PORT", CONFIG.get("port", 8765)))
    OUTPUT_COORDINATOR.start()
    server = ThreadingHTTPServer(("0.0.0.0", port), GamepadHandler)
    server.daemon_threads = True
    lan_ips = find_lan_ips()

    print("=" * 62)
    print(" CELULAR GAMEPAD PARA PC - v1.4.0-beta.2 | 2 JOGADORES")
    print("=" * 62)
    print("Abra no celular um destes endereços:")
    for lan_ip in lan_ips:
        print(f"  http://{lan_ip}:{port}")
    print(f"PIN de conexão: {PAIRING_PIN}")
    print("Dois celulares podem conectar: escolha Jogador 1 e Jogador 2 em cada tela.")
    if OUTPUT_COORDINATOR.effective_mode == "xinput":
        print("Saída: Controle virtual / Jogos de PC (experimental)")
    elif OUTPUT_COORDINATOR.configured_mode == "xinput":
        print("Controle virtual não instalado ou indisponível; usando Teclado / Emuladores.")
    else:
        print("Saída: Teclado / Emuladores")
    if os.name == "nt":
        print(f"Entrada Win32: OK | INPUT={ctypes.sizeof(INPUT)} bytes | {ctypes.sizeof(ctypes.c_void_p) * 8} bits")
    print("Deixe o celular e o PC na mesma rede Wi-Fi.")
    print("Para encerrar, pressione Ctrl+C.")
    if os.name != "nt":
        print("AVISO: fora do Windows, o servidor roda somente em modo de teste.")
    print("=" * 62)

    try:
        server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        print("\nEncerrando...")
    finally:
        INPUT_MANAGER.release_all()
        OUTPUT_COORDINATOR.stop()
        server.server_close()


if __name__ == "__main__":
    main()
