# SPDX-License-Identifier: GPL-2.0-or-later
from collections import Counter
import contextlib
import importlib.util
import io
from pathlib import Path
import shutil
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'app' if (ROOT / 'app').is_dir() else ROOT
SPEC = importlib.util.spec_from_file_location('render_map', ROOT / 'tools' / 'render_map.py')
MAP = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MAP)
LUA = shutil.which('lua5.5')
PILLOW = importlib.util.find_spec('PIL') is not None


def export_fixture(extra=''):
    rows = ['1' * 31] + ['1' + '0' * 29 + '1'] * 29 + ['1' * 31]
    kinds = ['spawn', 'chest', 'solana_coin', 'coffer_coin'] + ['enemy'] * 6 + ['door'] * 2 + ['medkit'] * 3 + ['ammo'] * 3
    records = ['SIZE\t31\t31', *('ROW\t' + row for row in rows)]
    records.extend(f'{kind}\t{i + 1}.5\t2.5\t0' for i, kind in enumerate(kinds))
    return '\n'.join(records) + '\n' + extra


class MapTests(unittest.TestCase):
    def test_supply_records_are_preserved(self):
        with patch.object(MAP.subprocess, 'run', return_value=SimpleNamespace(stdout=export_fixture())):
            width, height, rows, points = MAP.load_level('lua5.5', APP)
        self.assertEqual((width, height, len(rows), len(points)), (31, 31, 31, 18))
        self.assertEqual(Counter(p[0] for p in points),
                         Counter(spawn=1, chest=1, solana_coin=1, coffer_coin=1,
                                 enemy=6, door=2, medkit=3, ammo=3))
        self.assertEqual(points[-1], ('ammo', 18.5, 2.5, 0.0))

    def test_off_map_supply_is_rejected(self):
        text = export_fixture('medkit\t31\t2.5\t0\n')
        with patch.object(MAP.subprocess, 'run', return_value=SimpleNamespace(stdout=text)):
            with self.assertRaisesRegex(ValueError, 'Entity outside'):
                MAP.load_level('lua5.5', APP)

    def test_unknown_pickup_is_rejected(self):
        text = export_fixture('unknown_pickup\t2.5\t2.5\t0\n')
        with patch.object(MAP.subprocess, 'run', return_value=SimpleNamespace(stdout=text)):
            with self.assertRaisesRegex(ValueError, 'Unexpected Lua'):
                MAP.load_level('lua5.5', APP)

    @unittest.skipUnless(LUA, 'Lua 5.5 is needed to export the actual game')
    def test_actual_level_has_all_eighteen_markers(self):
        width, height, _, points = MAP.load_level(LUA, APP)
        self.assertEqual((width, height), (31, 31))
        self.assertEqual(len(points), 18)
        counts = Counter(kind for kind, *_ in points)
        self.assertEqual((counts['medkit'], counts['ammo'], counts['enemy']), (3, 3, 6))

    @unittest.skipUnless(PILLOW and LUA, 'Pillow and Lua 5.5 are needed for PNG validation')
    def test_actual_supply_markers_and_deterministic_png(self):
        from PIL import Image, ImageColor
        level = MAP.load_level(LUA, APP)
        with tempfile.TemporaryDirectory() as directory:
            first, second = Path(directory) / 'first.png', Path(directory) / 'second.png'
            with contextlib.redirect_stdout(io.StringIO()):
                MAP.render_map(level, first)
                MAP.render_map(level, second)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with Image.open(first) as image:
                left = (image.width - level[0] * 22) // 2
                for kind, x, y, _ in level[3]:
                    if kind in ('medkit', 'ammo'):
                        px, py = int(left + x * 22), int(94 + y * 22)
                        colors = set(image.crop((px - 6, py - 6, px + 7, py + 7)).get_flattened_data())
                        self.assertIn(ImageColor.getrgb(MAP.COLORS[kind]), colors)


if __name__ == '__main__':
    unittest.main()
