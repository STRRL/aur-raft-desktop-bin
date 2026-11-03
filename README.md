# aur-raft-desktop-bin

Keeps the AUR package [raft-desktop-bin](https://aur.archlinux.org/packages/raft-desktop-bin) in sync with upstream releases of [botiverse/desktop](https://github.com/botiverse/desktop).

Every 6 hours a GitHub Actions workflow runs `update.sh` in an Arch Linux container. When upstream has a newer release it updates `PKGBUILD` and `.SRCINFO`, test builds the package, checks the result, then pushes to AUR and to this repo. Nothing is pushed when any step fails.

Run it by hand from the Actions tab. Pick `dry_run` to build without pushing.

To stop it, disable the workflow in the Actions tab or delete the `AUR_SSH_PRIVATE_KEY` secret.
