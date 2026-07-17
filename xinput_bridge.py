from __future__ import annotations

import json
import queue
import subprocess
import threading
import time
from pathlib import Path
from typing import Any, Sequence

ROOT = Path(__file__).resolve().parent
MAX_BRIDGE_LINE = 16 * 1024


def default_bridge_command() -> list[str] | None:
    candidates = [
        ROOT / "bridge" / "PhoneGamepad.Bridge.exe",
        ROOT / "bridge" / "PhoneGamepad.Bridge" / "bin" / "Release" / "net10.0-windows10.0.26100.0" / "win-x64" / "publish" / "PhoneGamepad.Bridge.exe",
    ]
    return next(([str(path)] for path in candidates if path.is_file()), None)


class BridgeProcess:
    def __init__(self, command: Sequence[str] | None = None, startup_timeout: float = 12.0) -> None:
        self.command = list(command) if command else default_bridge_command()
        self.startup_timeout = startup_timeout
        self.process: subprocess.Popen[str] | None = None
        self._responses: queue.Queue[dict[str, Any]] = queue.Queue(maxsize=64)
        self._latest: dict[int, dict[str, Any]] = {}
        self._lock = threading.RLock()
        self._wake = threading.Event()
        self._stopping = threading.Event()
        self._restart_in_progress = False
        self._writer: threading.Thread | None = None
        self.error: str | None = None

    @property
    def running(self) -> bool:
        return self.process is not None and self.process.poll() is None

    def start(self) -> None:
        if not self.command:
            raise FileNotFoundError("Controle virtual não instalado: bridge ausente")
        with self._lock:
            if self.running:
                return
            self._stopping.clear()
            self.process = subprocess.Popen(self.command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL, text=True, encoding="utf-8", bufsize=1, shell=False)
            threading.Thread(target=self._read_loop, name="xinput-bridge-reader", daemon=True).start()
        ready = self._wait_for_any({"bridge_ready", "error"})
        if ready.get("type") != "bridge_ready" or ready.get("protocolVersion") != 2:
            self.stop(); raise RuntimeError("Bridge indisponível ou incompatível")
        self._send({"type": "hello", "protocolVersion": 2})
        if self._wait_for_any({"hello", "error"}).get("type") != "hello":
            self.stop(); raise RuntimeError("Handshake do bridge falhou")
        self._send({"type": "create", "players": [1, 2]})
        response = self._wait_for_any({"controllers_ready", "error"})
        if response.get("type") != "controllers_ready":
            message = str(response.get("message") or response.get("code") or "falha ao criar controles")
            self.stop(); raise RuntimeError(message)
        if self._writer is None or not self._writer.is_alive():
            self._writer = threading.Thread(target=self._write_loop, name="xinput-bridge-writer", daemon=True)
            self._writer.start()
        self.error = None

    def _read_loop(self) -> None:
        process = self.process
        if process is None or process.stdout is None:
            return
        for line in process.stdout:
            if len(line.encode("utf-8")) > MAX_BRIDGE_LINE:
                continue
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(payload, dict):
                try:
                    self._responses.put_nowait(payload)
                except queue.Full:
                    try: self._responses.get_nowait(); self._responses.put_nowait(payload)
                    except queue.Empty: pass
        if not self._stopping.is_set():
            self.error = "Bridge encerrado inesperadamente"

    def _send(self, payload: dict[str, Any]) -> None:
        data = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        if len(data.encode("utf-8")) > MAX_BRIDGE_LINE:
            raise ValueError("Mensagem local excede o limite")
        with self._lock:
            if not self.running or self.process is None or self.process.stdin is None:
                raise BrokenPipeError("Bridge indisponível")
            self.process.stdin.write(data + "\n"); self.process.stdin.flush()

    def _wait_for_any(self, types: set[str]) -> dict[str, Any]:
        deadline = time.monotonic() + self.startup_timeout
        while time.monotonic() < deadline:
            if self.process is not None and self.process.poll() is not None:
                raise RuntimeError("Bridge encerrou durante a inicialização")
            try: message = self._responses.get(timeout=0.2)
            except queue.Empty: continue
            if message.get("type") in types: return message
        raise TimeoutError("Timeout aguardando o bridge")

    def submit(self, state: dict[str, Any]) -> bool:
        with self._lock:
            if not self.running:
                self._schedule_restart(); return False
            self._latest[int(state["player"])] = state; self._wake.set()
        return True

    def _write_loop(self) -> None:
        while not self._stopping.is_set():
            self._wake.wait(0.1); self._wake.clear()
            with self._lock: pending, self._latest = self._latest, {}
            for player in sorted(pending):
                try: self._send(pending[player])
                except (BrokenPipeError, OSError, ValueError) as exc:
                    self.error = str(exc); self._schedule_restart(); break

    def _schedule_restart(self) -> None:
        with self._lock:
            if self._restart_in_progress or self._stopping.is_set(): return
            self._restart_in_progress = True
        def restart() -> None:
            try: self.stop(restarting=True); time.sleep(0.5); self.start()
            except Exception as exc: self.error = str(exc)
            finally: self._restart_in_progress = False
        threading.Thread(target=restart, name="xinput-bridge-restart", daemon=True).start()

    def neutralize(self, player: int) -> None:
        try: self._send({"type": "neutralize", "player": player})
        except (BrokenPipeError, OSError): pass

    def stop(self, restarting: bool = False) -> None:
        if not restarting: self._stopping.set()
        process = self.process
        if process is None: return
        if process.poll() is None:
            try:
                for player in (1, 2): self._send({"type": "neutralize", "player": player})
                self._send({"type": "shutdown"}); process.wait(timeout=4)
            except (BrokenPipeError, OSError, subprocess.TimeoutExpired):
                process.terminate()
                try: process.wait(timeout=2)
                except subprocess.TimeoutExpired: process.kill(); process.wait(timeout=2)
        self.process = None; self._wake.set()


class OutputCoordinator:
    def __init__(self, configured_mode: str, bridge: BridgeProcess | None = None) -> None:
        self.configured_mode = configured_mode if configured_mode in {"keyboard", "xinput"} else "keyboard"
        self.effective_mode = "keyboard"; self.bridge = bridge or BridgeProcess(); self.error: str | None = None
    def start(self) -> None:
        if self.configured_mode != "xinput": return
        try: self.bridge.start(); self.effective_mode = "xinput"
        except Exception as exc: self.error = str(exc); self.effective_mode = "keyboard"
    def submit(self, state: dict[str, Any]) -> bool: return self.effective_mode == "xinput" and self.bridge.submit(state)
    def neutralize(self, player: int) -> None:
        if self.effective_mode == "xinput": self.bridge.neutralize(player)
    def stop(self) -> None: self.bridge.stop()
