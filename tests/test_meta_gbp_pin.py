# -*- coding: utf-8 -*-
from __future__ import annotations

import importlib.machinery
import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parents[1]
META_GBP = HERE / 'meta-gbp'


def _load_meta_gbp():
    loader = importlib.machinery.SourceFileLoader('meta_gbp', str(META_GBP))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _git(cwd: str, *args: str) -> str:
    return subprocess.check_output(
        ('git', *args), cwd=cwd, text=True,
    ).strip()


class VersionReTests(unittest.TestCase):
    def setUp(self) -> None:
        self.mod = _load_meta_gbp()

    def test_release_tag_is_not_dev_snapshot(self) -> None:
        match = self.mod.VERSION_RE.fullmatch('go1.26.5')
        assert match is not None
        self.assertFalse(self.mod._is_dev_snapshot(match))

    def test_dev_snapshot_is_detected(self) -> None:
        match = self.mod.VERSION_RE.fullmatch('go1.26.5-1-g5bbd22ff78')
        assert match is not None
        self.assertTrue(self.mod._is_dev_snapshot(match))


class PinAndUpdateTargetTests(unittest.TestCase):
    def setUp(self) -> None:
        self.mod = _load_meta_gbp()
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / 'go1.26'
        self.root.mkdir()
        self.go = self.root / 'go'
        self.go.mkdir()
        _git(str(self.go), 'init')
        _git(str(self.go), 'config', 'user.email', 'test@example.com')
        _git(str(self.go), 'config', 'user.name', 'test')
        (self.go / 'README').write_text('release\n')
        _git(str(self.go), 'add', 'README')
        _git(str(self.go), 'commit', '-m', 'release')
        _git(str(self.go), 'tag', 'go1.26.5')
        (self.go / 'README').write_text('dev\n')
        _git(str(self.go), 'add', 'README')
        _git(str(self.go), 'commit', '-m', 'Working on go1.26.6')
        _git(str(self.go), 'branch', '-M', 'release-branch.go1.26')
        _git(str(self.go), 'checkout', '-B', 'master', 'release-branch.go1.26')
        _git(str(self.root), 'init')
        _git(str(self.root), 'config', 'user.email', 'test@example.com')
        _git(str(self.root), 'config', 'user.name', 'test')
        (self.root / 'changelogs' / 'mainline').mkdir(parents=True)
        (self.root / 'changelogs' / 'mainline' / 'trixie').write_text(
            'golang-1.26-go (1.26.5-1+trixie1) trixie; urgency=medium\n\n'
            '  * Initial.\n\n'
            ' -- Test <t@e.com>  Mon, 15 Jun 2026 00:00:00 +0000\n',
        )
        (self.root / 'debiandirs' / 'trixie').mkdir(parents=True)
        (self.root / 'debiandirs' / 'trixie' / 'control').write_text(
            'Source: golang-1.26-go\nPackage: golang-1.26-go\n',
        )
        _git(str(self.root), 'add', 'changelogs', 'debiandirs')
        _git(str(self.root), 'commit', '-m', 'init packaging')
        self._old_cwd = os.getcwd()
        os.chdir(self.root)

    def tearDown(self) -> None:
        os.chdir(self._old_cwd)
        self.tmp.cleanup()

    def test_describe_at_marks_branch_head_as_dev_snapshot(self) -> None:
        head = _git(str(self.go), 'rev-parse', 'HEAD')
        match = self.mod._describe_at(head)
        self.assertTrue(self.mod._is_dev_snapshot(match))

    def test_pin_go_to_release_tag_checks_out_latest_tag(self) -> None:
        pinned = self.mod._pin_go_to_release_tag()
        self.assertEqual(pinned, 'go1.26.5')
        head = _git(str(self.go), 'rev-parse', 'HEAD')
        tag = _git(str(self.go), 'rev-parse', 'go1.26.5')
        self.assertEqual(head, tag)

    def test_update_target_returns_current_when_already_on_branch_tip(self) -> None:
        self.mod._pin_go_to_release_tag()
        _git(str(self.go), 'checkout', 'release-branch.go1.26')
        tip = _git(str(self.go), 'rev-parse', 'HEAD')
        _git(str(self.go), 'branch', '-f', 'go-upstream', tip)

        original_cmd_q = self.mod._cmd_q

        def _cmd_q_noop(*cmd: str, cwd: str | None = None) -> None:
            if cmd[:3] == ('git', '-C', 'go') and 'fetch' in cmd:
                return None
            return original_cmd_q(*cmd, cwd=cwd)

        self.mod._cmd_q = _cmd_q_noop  # type: ignore[method-assign]
        try:
            got = self.mod._update_target()
        finally:
            self.mod._cmd_q = original_cmd_q  # type: ignore[method-assign]
        self.assertEqual(got, tip)


if __name__ == '__main__':
    unittest.main()
