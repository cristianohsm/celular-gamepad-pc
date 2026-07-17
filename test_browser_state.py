from __future__ import annotations

import subprocess
import unittest
from pathlib import Path


class BrowserXInputStateTests(unittest.TestCase):
    def test_node_state_transmitter_suite(self) -> None:
        result = subprocess.run(
            ["node", "--test", "test_xinput_state.js"],
            cwd=Path(__file__).resolve().parent,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
