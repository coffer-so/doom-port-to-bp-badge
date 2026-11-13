"""Packaging filenames follow app metadata; explicit destinations still work."""
from contextlib import redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location("packager", Path(__file__).parents[1] / "tools/package.py")
packager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / 'app'
        self.manifest = {'id': 'doom-by-coffer', 'version': '1.0.1', 'permissions': ['led'], 'hosts': []}
        for name in packager.FILES:
            path = self.app / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'fixture')
        self.write_manifest()

    def write_manifest(self):
        (self.app / 'app.json').write_text(json.dumps(self.manifest))

    def build(self, output=None):
        with patch.object(packager, 'ROOT', self.root), redirect_stdout(io.StringIO()):
            packager.package(self.app, output)

    def test_default_filename_tracks_manifest_version(self):
        for version in ('1.0.1', '1.0.2'):
            with self.subTest(version=version):
                self.manifest['version'] = version
                self.write_manifest()
                self.build()
                output = self.root / 'dist' / f'doom-by-coffer-{version}.zip'
                with zipfile.ZipFile(output) as archive:
                    self.assertEqual(archive.namelist(), list(packager.FILES))
                    self.assertEqual(json.loads(archive.read('app.json'))['version'], version)

    def test_explicit_output_path_is_preserved(self):
        output = self.root / 'release' / 'review.zip'
        self.build(output)
        self.assertTrue(output.is_file())
        self.assertFalse((self.root / 'dist').exists())

    def test_version_cannot_escape_output_directory(self):
        self.manifest['version'] = '../escape'
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, 'Invalid app version'):
            self.build()
        self.assertFalse((self.root / 'dist').exists())


if __name__ == '__main__':
    unittest.main()
