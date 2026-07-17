from __future__ import annotations

from pathlib import Path
import tempfile
import unittest
from urllib.parse import parse_qs, urlsplit

import qr_connection


class FakeCompleted:
    returncode = 0
    stdout = '[{"ip":"192.168.20.7","interface":"Wi-Fi"},{"ip":"169.254.4.2","interface":"Ethernet"}]'


class QrConnectionTests(unittest.TestCase):
    def test_urls_cover_auto_and_specific_players(self) -> None:
        for player in ("auto", "1", "2"):
            url = qr_connection.build_pairing_url("192.168.20.7", 8765, "123456", player)
            values = parse_qs(urlsplit(url).query)
            self.assertEqual(values, {"pin": ["123456"], "player": [player]})

    def test_invalid_url_values_are_rejected(self) -> None:
        for ip in ("127.0.0.1", "169.254.1.1", "8.8.8.8"):
            with self.assertRaises(ValueError):
                qr_connection.build_pairing_url(ip, 8765, "123456")
        with self.assertRaises(ValueError):
            qr_connection.build_pairing_url("192.168.1.2", 8765, "abc123")
        with self.assertRaises(ValueError):
            qr_connection.build_pairing_url("192.168.1.2", 8765, "123456", "3")

    def test_private_ip_selection_ignores_loopback_apipa_and_public(self) -> None:
        addresses = qr_connection.select_lan_addresses([
            qr_connection.LanAddress("127.0.0.1", "Loopback"),
            qr_connection.LanAddress("169.254.5.2", "Ethernet"),
            qr_connection.LanAddress("8.8.8.8", "Public"),
            qr_connection.LanAddress("192.168.3.8", "Ethernet"),
            qr_connection.LanAddress("10.2.3.4", "Wi-Fi"),
        ])
        self.assertEqual([item.ip for item in addresses], ["10.2.3.4", "192.168.3.8"])

    def test_discovery_is_local_and_allows_manual_fallback(self) -> None:
        calls: list[object] = []
        def runner(*args: object, **kwargs: object) -> FakeCompleted:
            calls.append(args[0])
            return FakeCompleted()
        addresses = qr_connection.discover_lan_addresses("172.16.0.9", runner=runner)
        self.assertEqual([item.ip for item in addresses], ["192.168.20.7", "172.16.0.9"])
        self.assertEqual(calls[0][0], "powershell")

    def test_qr_is_generated_locally_without_temp_file_or_network(self) -> None:
        url = qr_connection.build_pairing_url("192.168.1.2", 8765, "123456")
        with tempfile.TemporaryDirectory() as directory:
            before = list(Path(directory).iterdir())
            terminal = qr_connection.render_terminal_qr(url)
            svg = qr_connection.render_qr_svg(url)
            after = list(Path(directory).iterdir())
        self.assertTrue(terminal)
        self.assertIn("<svg", svg)
        self.assertEqual(before, after)
        source = Path(qr_connection.__file__).read_text(encoding="utf-8")
        self.assertNotIn("requests", source)
        self.assertNotIn("urlopen", source)

    def test_pin_is_redacted_for_logs(self) -> None:
        self.assertEqual(qr_connection.redact_pin('GET /?pin=123456&player=1 HTTP/1.1'), 'GET /?pin=***&player=1 HTTP/1.1')


if __name__ == "__main__":
    unittest.main(verbosity=2)
