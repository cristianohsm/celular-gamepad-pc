from __future__ import annotations

import ctypes
import json
import tempfile
import unittest
from pathlib import Path

import server


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

    def test_legacy_bindings_are_merged_into_player_one(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            path.write_text('{"port": 9000, "bindings": {"snes_a": "P"}}', encoding="utf-8")
            config = server.load_config(path)
            self.assertEqual(config["port"], 9000)
            self.assertEqual(config["players"]["1"]["snes_a"], "P")
            self.assertEqual(config["players"]["2"]["snes_a"], "N")


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


if __name__ == "__main__":
    unittest.main(verbosity=2)
