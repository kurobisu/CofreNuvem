# Redistributables

This folder is used by the Inno Setup installer to bundle runtime dependencies.

## Visual C++ Redistributable

The build scripts automatically download the latest **Microsoft Visual C++ Redistributable 2015-2022 (x64)** from:

```text
https://aka.ms/vs/17/release/vc_redist.x64.exe
```

The file is **not committed** to Git (see `.gitignore`). It is downloaded on demand when building the installer locally or in CI.
