#!/usr/bin/env bash
set -Eeuo pipefail

patch_file=50_add_susfs_in_gki-android14-6.1.patch
test -f "$SUSFS_ROOT/kernel_patches/$patch_file"
cp "$SUSFS_ROOT/kernel_patches/$patch_file" "$KERNEL_ROOT/common/$patch_file"
cp "$SUSFS_ROOT"/kernel_patches/fs/* "$KERNEL_ROOT/common/fs/"
cp "$SUSFS_ROOT"/kernel_patches/include/linux/* "$KERNEL_ROOT/common/include/linux/"
cd "$KERNEL_ROOT/common"

# 6.1.138 的补丁上下文需要这个头文件；应用后恢复原始 include 列表。
added_dma_buf=0
if ! grep -qF '#include <linux/dma-buf.h>' fs/proc/base.c; then
  sed -i '/^#include <linux\/cpufreq_times.h>$/a #include <linux/dma-buf.h>' fs/proc/base.c
  grep -qF '#include <linux/dma-buf.h>' fs/proc/base.c
  added_dma_buf=1
fi

patch -p1 --batch --fuzz=3 < "$patch_file"
if (( added_dma_buf )); then
  sed -i '/^#include <linux\/dma-buf.h>$/d' fs/proc/base.c
fi

# SUSFS 补丁的新 exec hook 依赖较新的 SukiSU API；40900 的 builtin 尚未提供。
if grep -qF 'ksu_handle_post_execveat_sucompat(' fs/exec.c \
  && ! grep -RqsE '^[[:space:]]*int[[:space:]]+ksu_handle_post_execveat_sucompat[[:space:]]*\(' "$KERNEL_ROOT/KernelSU/kernel"; then
  sed -i '/^extern int ksu_handle_post_execveat_sucompat(/,+1d' fs/exec.c
  sed -i 's/is_su_session = !\(ksu_handle_execveat[^;]*;\)/\1/' fs/exec.c
  sed -i '/^[[:space:]]*bool is_su_session = false;$/d' fs/exec.c
  sed -i '/^[[:space:]]*if (unlikely(is_su_session && retval >= 0))$/,+1d' fs/exec.c
  sed -i '/^[[:space:]]*if (unlikely(is_su_session))$/,+1d' fs/exec.c
  sed -i '/^#ifdef CONFIG_KSU_SUSFS$/N;/^#ifdef CONFIG_KSU_SUSFS\n#endif \/\/ #ifdef CONFIG_KSU_SUSFS$/d' fs/exec.c
  if grep -qE 'ksu_handle_post_execveat_sucompat|is_su_session' fs/exec.c; then
    echo 'SUSFS exec hook compatibility fix failed' >&2
    exit 1
  fi
fi

if find . -type f -name '*.rej' | grep -q .; then
  find . -type f -name '*.rej' -print
  echo 'SUSFS patch has rejected hunks' >&2
  exit 1
fi
