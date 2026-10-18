# better-blur-dx-rpm

openSUSE Tumbleweed packaging for
[Better Blur DX](https://github.com/xarblu/kwin-effects-better-blur-dx), built on
the Open Build Service as
[`home:kanonmaten/kwin-effects-better-blur-dx`](https://build.opensuse.org/package/show/home:kanonmaten/kwin-effects-better-blur-dx).

## Install

```bash
sudo zypper addrepo -f https://download.opensuse.org/repositories/home:/kanonmaten/openSUSE_Tumbleweed/home:kanonmaten.repo
sudo zypper install kwin-effects-better-blur-dx
```

Then log out and back in, open System Settings → Window Management → Desktop
Effects, turn off **Blur** and turn on **Better Blur DX**.

If you had `better-blur-dx` from `home:Mx775:Plasma`, zypper offers to replace
it (the two conflict).

## Updates

Both kinds of update arrive through a normal `zypper dup`, without any manual
step:

- **New KWin in Tumbleweed.** The effect only loads into the exact KWin
  version it was built for. OBS rebuilds this package by itself whenever
  `kwin6-devel` changes, and the package requires `kwin6 = <that version>`.
  If you run `zypper dup` in the few hours between a new KWin landing and the
  rebuild being published, zypper stops with a dependency problem for this
  package. Either cancel and run `zypper dup` again later, or let zypper
  remove the package and reinstall it once the rebuild is out.
- **New upstream release.** `.github/workflows/upstream-bump.yml` checks
  upstream's latest release every hour (at :17) and opens a PR. OBS test-builds the
  PR and it merges itself when the build is green. The merge triggers the real
  rebuild.

When a new Plasma release needs a new upstream version, the KWin rebuild fails
until upstream catches up. The old build stays published, and the KWin pin
keeps zypper from installing it next to the new KWin.

## Layout

| Path | Purpose |
|---|---|
| `packaging/` | What OBS builds (`<scmsync>` points at this subdirectory) |
| `packaging/_service` | Fetches the upstream tag tarball; `%prep` checks its SHA256 |
| `scripts/bump-version.sh` | Moves the spec and `_service` to a new upstream release |
| `scripts/obs-bootstrap.sh` | One-time OBS and GitHub wiring (webhooks, tokens, ruleset) |
| `.obs/workflows.yml` | PR test builds in `home:kanonmaten:ci` |

## License

Packaging files: MIT. Better Blur DX itself: GPL-3.0 / GPL-2.0-or-later.
