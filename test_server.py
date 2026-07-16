from __future__ import annotations

import ctypes
import json
import tempfile
import unittest
from pathlib import Path

from gamepad_protocol import ProtocolError, validate_gamepad_state
import server
from xinput_bridge import OutputCoordinator


class FakeKeyboard:
    def __init__(self) -> None:
        self.events: list[tuple[str, int]] = []
        self.fail_press = False
        self.fail_release = False

    def press(self, vk_code: int) -> None:
        if self.fail_press:
            raise OSError("press failure")
        self.events.append(("down", vk_code))

    def release(self, vk_code: int) -> None:
        if self.fail_release:
            raise OSError("release failure")
        self.events.append(("up", vk_code))


class InputStructureTests(unittest.TestCase):
    def test_input_size_matches_windows_contract(self) -> None:
        expected = 40 if ctypes.sizeof(ctypes.c_void_p) == 8 else 28
        self.assertEqual(ctypes.sizeof(server.INPUT), expected)

    def test_union_contains_all_native_input_variants(self) -> None:
        field_names = {name for name, *_ in server.INPUTUNION._fields_}
        self.assertEqual(field_names, {"mi", "ki", "hi"})

    def test_extra_virtual_keys_are_available(self) -> None:
        self.assertEqual(server.VK_CODES["NUMPAD8"], 0x68)
        self.assertEqual(server.VK_CODES["F12"], 0x7B)


class ConfigTests(unittest.TestCase):
    def test_missing_config_is_created_from_safe_defaults(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            config = server.load_config(path)
            saved = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(config, server.DEFAULT_CONFIG)
            self.assertEqual(saved, server.DEFAULT_CONFIG)
            self.assertNotIn("pin", json.dumps(saved).lower())
            self.assertNotIn("secret", json.dumps(saved).lower())
            self.assertEqual(saved["output_mode"], "keyboard")

    def test_legacy_bindings_are_merged_into_player_one(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            path.write_text('{"port": 9000, "bindings": {"snes_a": "P"}}', encoding="utf-8")
            config = server.load_config(path)
            self.assertEqual(config["port"], 9000)
            self.assertEqual(config["players"]["1"]["snes_a"], "P")
            self.assertEqual(config["players"]["2"]["snes_a"], "N")
            self.assertEqual(config["output_mode"], "keyboard")

    def test_xinput_config_is_bounded(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            path.write_text('{"output_mode":"xinput","xinput":{"dead_zone":9,"smoothing":-1,"max_update_hz":999}}', encoding="utf-8")
            config = server.load_config(path)
            self.assertEqual(config["output_mode"], "xinput")
            self.assertEqual(config["xinput"], {"dead_zone": 0.5, "smoothing": 0.0, "max_update_hz": 60})


class InputManagerTests(unittest.TestCase):
    def make_manager(self) -> tuple[server.InputManager, FakeKeyboard]:
        keyboard = FakeKeyboard()
        manager = server.InputManager({1: {"jump": "X"}, 2: {"jump": "N"}}, keyboard=keyboard)
        manager.register_client("client-1", 1)
        manager.register_client("client-2", 2)
        return manager, keyboard

    def test_players_use_independent_keys(self) -> None:
        manager, keyboard = self.make_manager()
        manager.press("client-1", "jump")
        manager.press("client-2", "jump")
        manager.release("client-1", "jump")
        manager.release("client-2", "jump")
        self.assertEqual(
            keyboard.events,
            [("down", ord("X")), ("down", ord("N")), ("up", ord("X")), ("up", ord("N"))],
        )

    def test_failed_press_does_not_leave_stuck_state(self) -> None:
        manager, keyboard = self.make_manager()
        keyboard.fail_press = True
        with self.assertRaises(OSError):
            manager.press("client-1", "jump")
        self.assertEqual(manager._client_buttons.get("client-1"), {})
        self.assertEqual(manager._key_counts, {})

    def test_cleanup_failure_does_not_escape(self) -> None:
        manager, keyboard = self.make_manager()
        manager.press("client-1", "jump")
        keyboard.fail_release = True
        manager.release_client("client-1")
        self.assertNotIn("client-1", manager._client_buttons)
        self.assertNotIn("client-1", manager._client_players)

    def test_disconnect_releases_held_keys(self) -> None:
        manager, keyboard = self.make_manager()
        manager.press("client-1", "jump")
        manager.release_client("client-1")
        self.assertEqual(keyboard.events, [("down", ord("X")), ("up", ord("X"))])

    def test_release_buttons_keeps_client_registered(self) -> None:
        manager, keyboard = self.make_manager()
        manager.press("client-1", "jump")
        manager.release_buttons("client-1")
        manager.press("client-1", "jump")
        self.assertEqual(keyboard.events[-1], ("down", ord("X")))


class PlayerSlotTests(unittest.TestCase):
    def test_auto_assigns_player_one_then_two(self) -> None:
        slots = server.PlayerSlots()
        self.assertEqual(slots.claim("a", "auto"), 1)
        self.assertEqual(slots.claim("b", "auto"), 2)
        self.assertIsNone(slots.claim("c", "auto"))

    def test_specific_occupied_slot_is_rejected(self) -> None:
        slots = server.PlayerSlots()
        self.assertEqual(slots.claim("a", "2"), 2)
        self.assertIsNone(slots.claim("b", "2"))
        self.assertEqual(slots.claim("b", "1"), 1)

    def test_released_slot_can_be_reused(self) -> None:
        slots = server.PlayerSlots()
        self.assertEqual(slots.claim("a", 1), 1)
        self.assertEqual(slots.release("a"), 1)
        self.assertEqual(slots.claim("b", 1), 1)

    def test_third_player_is_rejected(self) -> None:
        slots = server.PlayerSlots()
        slots.claim("a", 1)
        slots.claim("b", 2)
        self.assertIsNone(slots.claim("c", "auto"))


class MessageTests(unittest.TestCase):
    def test_invalid_messages_are_rejected_safely(self) -> None:
        self.assertIsNone(server.decode_client_message(b"not-json"))
        self.assertIsNone(server.decode_client_message(b"[]"))
        self.assertEqual(server.decode_client_message(b'{"type":"ping"}'), {"type": "ping"})


def make_gamepad_message(player: int = 1, sequence: int = 1) -> dict[str, object]:
    return {
        "type": "gamepad_state", "protocolVersion": 2, "player": player,
        "sequence": sequence, "timestamp": 123,
        "buttons": {"a": True}, "dpad": {"up": True},
        "axes": {"lx": 0.5, "ly": -0.5, "lt": 0.25, "rt": 0.75},
    }


class FakeBridge:
    def __init__(self, fail_start: bool = False) -> None:
        self.fail_start = fail_start
        self.states: list[dict[str, object]] = []
        self.neutralized: list[int] = []
        self.stopped = False
    def start(self) -> None:
        if self.fail_start:
            raise RuntimeError("not installed")
    def submit(self, state: dict[str, object]) -> bool:
        self.states.append(state)
        return True
    def neutralize(self, player: int) -> None:
        self.neutralized.append(player)
    def stop(self) -> None:
        self.stopped = True


class GamepadProtocolTests(unittest.TestCase):
    def test_bridge_unavailable_falls_back_to_keyboard(self) -> None:
        coordinator = OutputCoordinator("xinput", bridge=FakeBridge(fail_start=True))
        coordinator.start()
        self.assertEqual(coordinator.effective_mode, "keyboard")
        self.assertIsNotNone(coordinator.error)

    def test_fake_bridge_receives_isolated_player_states(self) -> None:
        bridge = FakeBridge()
        coordinator = OutputCoordinator("xinput", bridge=bridge)
        coordinator.start()
        one = validate_gamepad_state(make_gamepad_message(1, 1), 1, -1)
        two = validate_gamepad_state(make_gamepad_message(2, 1), 2, -1)
        coordinator.submit(one)
        coordinator.submit(two)
        self.assertEqual([state["player"] for state in bridge.states], [1, 2])

    def test_analog_values_are_clamped(self) -> None:
        message = make_gamepad_message()
        message["axes"] = {"lx": 2, "ly": -2, "lt": -1, "rt": 4}
        state = validate_gamepad_state(message, 1, -1)
        self.assertEqual(state["axes"], {"lx": 1.0, "ly": -1.0, "rx": 0.0, "ry": 0.0, "lt": 0.0, "rt": 1.0})

    def test_nan_and_infinity_are_rejected(self) -> None:
        for invalid in (float("nan"), float("inf"), float("-inf")):
            message = make_gamepad_message()
            message["axes"] = {"lx": invalid}
            with self.assertRaises(ProtocolError):
                validate_gamepad_state(message, 1, -1)

    def test_old_sequence_and_wrong_player_are_rejected(self) -> None:
        with self.assertRaisesRegex(ProtocolError, "Sequência antiga"):
            validate_gamepad_state(make_gamepad_message(1, 4), 1, 4)
        with self.assertRaisesRegex(ProtocolError, "slot reservado"):
            validate_gamepad_state(make_gamepad_message(2, 5), 1, 4)

    def test_incompatible_protocol_and_unknown_fields_are_rejected(self) -> None:
        message = make_gamepad_message()
        message["protocolVersion"] = 99
        with self.assertRaisesRegex(ProtocolError, "incompatível"):
            validate_gamepad_state(message, 1, -1)
        message = make_gamepad_message()
        message["command"] = "anything"
        with self.assertRaisesRegex(ProtocolError, "desconhecidos"):
            validate_gamepad_state(message, 1, -1)

    def test_disconnect_neutralizes_only_correct_player(self) -> None:
        bridge = FakeBridge()
        coordinator = OutputCoordinator("xinput", bridge=bridge)
        coordinator.start()
        coordinator.neutralize(2)
        self.assertEqual(bridge.neutralized, [2])


if __name__ == "__main__":
    unittest.main(verbosity=2)
