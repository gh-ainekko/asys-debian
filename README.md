# asys-debian

Self-contained Debian packaging for [asys](https://github.com/glguida/asys)
and [dcomp](https://github.com/glguida/dcomp) on Ubuntu 24.04 (noble, amd64).
Upstream sources are pinned as git submodules under `upstream/`; GitHub
Actions builds, smoke-tests and (on `v*` tags) releases the `.deb`s.
Design notes: [PLAN.md](PLAN.md).

| Package | Built by | Contents |
|---|---|---|
| `dcomp` | `ci/build-dcomp.sh` | `dcomp`, `dcomp-proxy`, `dcomp-healthcheck` |
| `asys` | `ci/build-asys.sh` | all host commands, Python, vendored TUI deps, skills, designs, examples |
| `asys-images` | `ci/build-images.sh` (needs Docker) | base container images; loaded by postinst / `asys-images-load` |
| `asys-server` | `ci/build-asys.sh` | shared team instance under `/srv/asys` |

## Layout

```
upstream/dcomp, upstream/asys   pinned upstream releases (submodules)
dcomp/debian, asys/debian       Debian packaging (asys/debian also builds asys-server)
asys-images/                    control template + load script for the image package
ci/                             build-*.sh, build-all.sh, smoke-test.sh
.github/workflows/build.yml     CI: build -> smoke test -> artifacts -> release on tag
```

## Build locally

```sh
git clone --recursive <this repo> && cd asys-debian
ci/build-all.sh                 # -> build/dist/*.deb
sudo ci/smoke-test.sh           # installs them and runs the team workflow as user "smoke"
```

Needs Go ≥ 1.25 on PATH, `debhelper`, `dh-python`, `devscripts`, `fakeroot`,
`python3-pip`, `zstd`, Docker. The scripts default to the submodules; pass
another checkout and revision to build something else
(`ci/build-asys.sh ~/asys HEAD`). Package versions come from
`*/debian/changelog` (`dch -i`), image tags from the upstream part of the
asys version.

## Updating upstream

```sh
git -C upstream/dcomp fetch --tags && git -C upstream/dcomp checkout vX.Y.Z
git -C upstream/asys  fetch --tags && git -C upstream/asys  checkout <release commit>
dch -c dcomp/debian/changelog -v X.Y.Z-1~noble1 -D noble "New upstream release."
dch -c asys/debian/changelog  -v A.B.C-1~noble1 -D noble "New upstream release."
git add -A upstream dcomp asys && git commit && git tag vA.B.C-1 && git push --tags
```

## Team server

```sh
sudo apt install ./dcomp_*.deb ./asys-images_*.deb ./asys_*.deb ./asys-server_*.deb
sudo asys-adduser alice bob            # group asys + docker; re-login
source /srv/asys/asys-env              # in every shell that uses asys
asys-inference gateway login PROVIDER --as ACCOUNT && asys-inference start   # once
asys system-model set simple MODEL
```

`asys-skills --codex|--claude|DIR [--force]` exports the bundled skills for
agents. The dashboard runs as `asys-dashboard.service` on 127.0.0.1:8766; front
it with `/usr/share/asys-server/nginx-asys-dashboard.conf`. Upgrading
`asys-server` runs `asys update` (refreshes the inference gateway and Human
service; running workflow containers keep their old images);
`asys-server-update --update` reruns it by hand. Shared git checkouts under
`/srv/asys/workspaces` need a per-member
`git config --global --add safe.directory /srv/asys/workspaces/NAME`.
