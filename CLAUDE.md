# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

apko-cicd builds minimal, reproducible, multi-architecture OCI container images for CI/CD pipelines. Images are defined declaratively with [apko](https://github.com/chainguard-dev/apko) from [Wolfi](https://wolfi.dev) packages — no Dockerfiles involved.

Registry: `ghcr.io/pfenerty/apko-cicd/<image>:<tag>`

## Dev Environment

Uses Flox. All commands must be prefixed with `flox activate --`:

```bash
flox activate -- make base          # Build single image
flox activate -- make all           # Build all images
flox activate -- make publish       # Publish all to GHCR
flox activate -- make clean         # Remove dist/
```

## How the Makefile Works

The Makefile uses a single `IMAGE` macro that generates build and publish targets for each image. Each image is defined as:
```
$(eval $(call IMAGE,<target-name>,<config-path>,<image:tag>))
```

Build individual images with `make <target-name>` (e.g., `make nodejs-22`, `make tools-syft`, `make golang-1.25`).

## Directory Structure

- `base/apko.yaml` — Base image (git, curl, openssl, zstd, Nushell shell)
- `tools/<name>/apko.yaml` — CI/CD tool images (syft, grype, oras, apko, melange, golangci-lint)
- `languages/<name>/<version>.yaml` — Language runtime images (Node.js, Go, Java, Rust)
- `dist/` — Build output (tarballs + SBOMs), gitignored

## Version Management

Versions are pinned in individual apko YAML configs and updated automatically by [Renovate](https://docs.renovatebot.com/) using the `~` (compatible release) operator for patch-level auto-updates.
