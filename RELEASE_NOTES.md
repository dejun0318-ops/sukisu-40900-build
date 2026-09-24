Android 14 GKI 6.1.138 (2025-06), SukiSU-Ultra 40900 and SUSFS v2.3.0.

- `android14-6.1.138-2025-06-AnyKernel3.zip`: kernel built by this repository's GitHub Actions.
- `SukiSU_v4.2.0_40900-release.apk`: unmodified manager from the official SukiSU-Ultra v4.2.0 release.
- `ksu_module_susfs.zip`: unmodified module from `zzh20188/GKI_KernelSU_SUSFS` v2.3.0-r4.
- `BUILD_INFO.txt` and `SHA256SUMS.txt`: source revisions and file hashes.

The kernel uses SukiSU builtin commit `b20dee702035af09cb2ecb5f35443bbc1747f3e6` (v4.2.0 plus a build fix), with the kernel version set to 40900. It uses SUSFS commit `596ec8fcdcb5a6ee366494304333c7fdc76d8862` and Android GKI release tag `android14-6.1-2025-06_r11`, commit `6ab8c9a86a331cece499c7edac062ceffbe2e320`.

The compiled kernel release string is `6.1.138-android14-11-g6ab8c9a86a33-ab14396278`, matching the provided device version.

Back up the original boot image before flashing. This build has not been tested on a device.
