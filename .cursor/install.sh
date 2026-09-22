#!/usr/bin/env bash
#
# Cloud Agent environment bootstrap for Actions-OpenWrt.
#
# Installs the system packages required to build OpenWrt / Lean's LEDE
# firmware (the same toolchain the "Build OpenWrt" GitHub Actions workflow
# relies on) so an agent can run the build pipeline end to end.
#
# This script is intended to be idempotent: it can be re-run safely and
# converges to the same state without rewriting project files.

set -euo pipefail

# OpenWrt / LEDE build dependencies (Ubuntu). Mirrors the package set the
# upstream workflow installs via "git.io/depends-ubuntu-2004", curated to the
# packages that are available on modern Ubuntu (22.04/24.04).
PACKAGES=(
  ack antlr3 asciidoc autoconf automake autopoint binutils bison
  build-essential bzip2 ccache clang cmake cpio curl device-tree-compiler
  flex gawk gcc-multilib g++-multilib gettext genisoimage git gperf haveged
  help2man intltool libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev
  libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev
  libpython3-dev libreadline-dev libssl-dev libtool llvm lrzsz mkisofs msmtp
  ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip
  python3-ptyprocess python3-docutils qemu-utils re2c rsync scons
  squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget
  xmlto xxd zlib1g-dev
)

echo "==> Installing OpenWrt build dependencies (${#PACKAGES[@]} packages)"
export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get -qq update
sudo -E apt-get -y install --no-install-recommends "${PACKAGES[@]}"
sudo -E apt-get -qq autoremove --purge
sudo -E apt-get -qq clean

# OpenWrt's build system expects the host `cc`/`c++` to be GCC (as on the
# ubuntu-20.04 runner the Build OpenWrt workflow targets). Some base images
# alias `cc` -> clang; clang then looks for libstdc++.so under a GCC version
# whose -dev package is not installed, so `-lstdc++` fails and host tools such
# as elfutils fail to configure. Point the default C/C++ compiler back to GCC.
echo "==> Ensuring the default cc/c++ compiler is GCC (required by OpenWrt host tools)"
sudo update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 100 >/dev/null 2>&1 || true
sudo update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 100 >/dev/null 2>&1 || true
sudo update-alternatives --set cc /usr/bin/gcc >/dev/null 2>&1 || true
sudo update-alternatives --set c++ /usr/bin/g++ >/dev/null 2>&1 || true

# OpenWrt's build system emits locale warnings without a UTF-8 locale.
echo "==> Ensuring en_US.UTF-8 locale is available"
sudo locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
sudo update-locale LANG=en_US.UTF-8 >/dev/null 2>&1 || true

# Make the customization hooks executable (the workflow chmods these too).
echo "==> Marking DIY scripts executable"
chmod +x "$(dirname "$0")/../diy-part1.sh" "$(dirname "$0")/../diy-part2.sh" 2>/dev/null || true

echo "==> OpenWrt build environment is ready."
echo "    gcc:    $(gcc -dumpversion 2>/dev/null)"
echo "    make:   $(make --version 2>/dev/null | head -1)"
echo "    python: $(python3 --version 2>/dev/null)"
