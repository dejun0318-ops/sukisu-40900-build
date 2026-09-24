# android14-6.1.138-2025-06 · SukiSU-Ultra 40900 + SUSFS

This repository builds one GKI kernel in GitHub Actions for a device reporting `6.1.138-android14-11-g6ab8c9a86a33-ab14396278`.

Run **Build SukiSU 40900 for android14-6.1.138** from the Actions tab. The workflow builds `android14-6.1.138-2025-06-AnyKernel3.zip` and publishes it with the official [SukiSU-Ultra v4.2.0 manager (40900)](https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases/tag/v4.2.0) and the matching [SUSFS module](https://github.com/zzh20188/GKI_KernelSU_SUSFS/releases/tag/v2.3.0-r4). The release also includes source revisions and SHA-256 checksums.

The build process follows [ShirkNeko/GKI_KernelSU_SUSFS](https://github.com/ShirkNeko/GKI_KernelSU_SUSFS) and the Android 14 / 6.1 SUSFS compatibility fix from [zzh20188/GKI_KernelSU_SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS). It pins the SukiSU builtin, SUSFS, and AnyKernel3 commits. The GKI source is the `2025-06` monthly branch and is checked for `6.1.138` before compilation. `BUILD_INFO.txt` records the exact GKI commit.

Back up the original boot image before flashing. No device test is part of this workflow.
