#!/usr/bin/env bash
set -Eeuo pipefail

readonly GKI_BRANCH=common-android14-6.1-2025-06
readonly GKI_TAG=android14-6.1-2025-06_r11
readonly GKI_COMMIT=6ab8c9a86a331cece499c7edac062ceffbe2e320
readonly KSU_COMMIT=b20dee702035af09cb2ecb5f35443bbc1747f3e6
readonly SUSFS_COMMIT=596ec8fcdcb5a6ee366494304333c7fdc76d8862
readonly ANYKERNEL_COMMIT=e1e9dce98430c5c6f231f7094a8c7f4ecaf50948
readonly WORK_ROOT="${RUNNER_TEMP:-/tmp}/sukisu-40900"
readonly KERNEL_ROOT="$WORK_ROOT/kernel"
readonly SUSFS_ROOT="$WORK_ROOT/susfs4ksu"
readonly ANYKERNEL_ROOT="$WORK_ROOT/AnyKernel3"
readonly REPO_TOOL="$WORK_ROOT/bin/repo"
readonly PROJECT_ROOT="$PWD"

mkdir -p "$WORK_ROOT/bin" "$KERNEL_ROOT" "$PROJECT_ROOT/artifacts"

echo '=== Sync Android GKI source ==='
curl -fsSL --retry 5 https://storage.googleapis.com/git-repo-downloads/repo -o "$REPO_TOOL"
chmod +x "$REPO_TOOL"
cd "$KERNEL_ROOT"
"$REPO_TOOL" init --depth=1 -u https://android.googlesource.com/kernel/manifest -b "$GKI_BRANCH"
manifest=.repo/manifests/default.xml
test -f "$manifest"
# 月度分支已删除；r11 的提交哈希与设备 uname 的 g6ab8c9a86a33 对应。
python3 - "$manifest" "$GKI_TAG" <<'PY'
from pathlib import Path
import sys

path, tag = Path(sys.argv[1]), sys.argv[2]
source = path.read_text()
old = 'revision="android14-6.1-2025-06" upstream="android14-6.1-2025-06" dest-branch="android14-6.1-2025-06"'
new = f'revision="refs/tags/{tag}" upstream="refs/tags/{tag}" dest-branch="android14-6.1-2025-06"'
if source.count(old) != 1:
    raise SystemExit('Expected GKI manifest project was not found exactly once')
path.write_text(source.replace(old, new))
PY
"$REPO_TOOL" sync -c -j4 --no-tags --no-clone-bundle --retry-fetches=3

# 必须使用用户指定的 6.1.138 月度分支，避免分支变动生成误标文件。
test -f common/Makefile
test "$(git -C common rev-parse HEAD)" = "$GKI_COMMIT"
grep -Eq '^VERSION = 6$' common/Makefile
grep -Eq '^PATCHLEVEL = 1$' common/Makefile
grep -Eq '^SUBLEVEL = 138$' common/Makefile

echo '=== Add pinned SukiSU builtin source ==='
git clone --depth 1 --branch builtin https://github.com/SukiSU-Ultra/SukiSU-Ultra.git KernelSU
git -C KernelSU fetch --depth 1 origin "$KSU_COMMIT"
git -C KernelSU checkout --detach "$KSU_COMMIT"
test "$(git -C KernelSU rev-parse HEAD)" = "$KSU_COMMIT"
ln -s ../../KernelSU/kernel common/drivers/kernelsu
test -f common/drivers/kernelsu/Makefile
printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> common/drivers/Makefile
sed -i '/^endmenu$/i source "drivers/kernelsu/Kconfig"' common/drivers/Kconfig

# builtin 内核代码比管理器发布晚两个提交；固定展示版本，与 40900 APK 对应。
sed -i -E 's/^KSU_VERSION[[:space:]]*:=.*/KSU_VERSION := 40900/' KernelSU/kernel/Makefile
sed -i -E 's/^VERSION_TAG[[:space:]]*:=.*/VERSION_TAG := 4.2.0/' KernelSU/kernel/Makefile
grep -q '^KSU_VERSION := 40900$' KernelSU/kernel/Makefile

echo '=== Apply pinned SUSFS v2.3.0 patches ==='
git clone --branch gki-android14-6.1 https://github.com/ShirkNeko/susfs4ksu.git "$SUSFS_ROOT"
git -C "$SUSFS_ROOT" checkout --detach "$SUSFS_COMMIT"
test "$(git -C "$SUSFS_ROOT" rev-parse HEAD)" = "$SUSFS_COMMIT"
export KERNEL_ROOT SUSFS_ROOT
bash "$PROJECT_ROOT/scripts/apply-susfs.sh"

echo '=== Configure and compile GKI ==='
cat > common/arch/arm64/configs/ksu.fragment <<'EOF'
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_SUS_MAP=y
EOF

sed -i '/"protected_exports_list".*"android\/abi_gki_protected_exports_aarch64"/d' common/BUILD.bazel
sed -i '/kmi_symbol_list_strict_mode/d' common/BUILD.bazel
sed -i 's/BUILD_SYSTEM_DLKM=1/BUILD_SYSTEM_DLKM=0/; /MODULES_ORDER=android\/gki_aarch64_modules/d; /KMI_SYMBOL_LIST_STRICT_MODE/d' common/build.config.gki.aarch64
sed -i 's/check_defconfig//' common/build.config.gki
if test -f build/kernel/kleaf/impl/stamp.bzl; then
  sed -i 's/-maybe-dirty//g' build/kernel/kleaf/impl/stamp.bzl
fi

tools/bazel build --disk_cache="$WORK_ROOT/bazel-cache" --config=fast --lto=thin \
  --defconfig_fragment=//common:arch/arm64/configs/ksu.fragment \
  //common:kernel_aarch64_dist

readonly IMAGE="$KERNEL_ROOT/bazel-bin/common/kernel_aarch64/Image"
test -s "$IMAGE"
strings "$IMAGE" | grep -m1 'Linux version 6.1.138-android14-11'

echo '=== Package AnyKernel3 ==='
git clone --depth 1 --branch gki-2.0 https://github.com/WildPlusKernel/AnyKernel3.git "$ANYKERNEL_ROOT"
git -C "$ANYKERNEL_ROOT" fetch --depth 1 origin "$ANYKERNEL_COMMIT"
git -C "$ANYKERNEL_ROOT" checkout --detach "$ANYKERNEL_COMMIT"
test "$(git -C "$ANYKERNEL_ROOT" rev-parse HEAD)" = "$ANYKERNEL_COMMIT"
cp "$IMAGE" "$ANYKERNEL_ROOT/Image"
rm -rf "$ANYKERNEL_ROOT/.git"
(cd "$ANYKERNEL_ROOT" && zip -q -r "$PROJECT_ROOT/artifacts/android14-6.1.138-2025-06-AnyKernel3.zip" .)

cat > "$PROJECT_ROOT/artifacts/BUILD_INFO.txt" <<EOF
GKI branch: $GKI_BRANCH
GKI release tag: $GKI_TAG
GKI commit: $(git -C "$KERNEL_ROOT/common" rev-parse HEAD)
SukiSU builtin commit: $KSU_COMMIT
SukiSU kernel version: 40900
SukiSU manager: v4.2.0 / 40900
SUSFS commit: $SUSFS_COMMIT (v2.3.0)
AnyKernel3 commit: $ANYKERNEL_COMMIT
Build run: ${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-dejun0318-ops/sukisu-40900-build}/actions/runs/${GITHUB_RUN_ID:-local}
EOF
