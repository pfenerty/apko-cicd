# apko-cicd

A collection of minimal, reproducible, multi-architecture OCI container images purpose-built for CI/CD pipelines. Images are defined declaratively using [apko](https://github.com/chainguard-dev/apko) and built from [Wolfi](https://wolfi.dev) packages, with no Dockerfile or build-time shell commands involved.

## Registry

All images are published to the GitHub Container Registry:

```
ghcr.io/pfenerty/apko-cicd/<image>:<tag>
```

## Available Images

### Base

| Image | Tag | Description |
|-------|-----|-------------|
| `base` | `stable` | Wolfi base image shared by all images below |

The base image includes common tooling for CICD tasking: `git`, `curl`, `openssl`, `zstd`, `ca-certificates-bundle`, and [Nushell](https://www.nushell.sh) as the default shell.

### Tools

| Image | Tag | Description |
|-------|-----|-------------|
| `syft` | `1.42.3` | SBOM generator for container images and filesystems |
| `grype` | `0.110.0` | Vulnerability scanner for container images and filesystems |
| `oras` | `1.3.1` | OCI Registry As Storage CLI |
| `apko` | `1.1.16` | apk-based OCI image builder |
| `melange` | `0.46.1` | APK package builder for Wolfi and Alpine |
| `golangci-lint` | `2.11.4` | Fast linters runner for Go |

### Node.js

| Image | Tag |
|-------|-----|
| `nodejs` | `18` |
| `nodejs` | `20` |
| `nodejs` | `22` |
| `nodejs` | `24` |

### Go

| Image | Tag |
|-------|-----|
| `golang` | `1.22` |
| `golang` | `1.23` |
| `golang` | `1.24` |
| `golang` | `1.25` |

### Java

| Image | Tag | Description |
|-------|-----|-------------|
| `jdk` | `11`, `17`, `21`, `24` | OpenJDK only |
| `maven` | `3.9-jdk11`, `3.9-jdk17`, `3.9-jdk21`, `3.9-jdk24` | Maven 3.9 + OpenJDK |
| `gradle` | `8-jdk11`, `8-jdk17`, `8-jdk21`, `8-jdk24` | Gradle 8 + OpenJDK |

### Rust

| Image | Tag |
|-------|-----|
| `rust` | `1.92` |
| `rust` | `1.93` |
| `rust` | `1.94` |

## Version Management

Package versions are managed by [Renovate](renovate.json). Version constraints use the `~` (compatible release) operator so that patch-level updates are picked up automatically while major/minor versions remain pinned.
