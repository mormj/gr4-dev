# Builder Images

This tree mirrors the dependency-image layout from `gr4-ci` and keeps the
builder definitions local to this workspace.

## Layout

```text
builders/
  <distro>/
    base/
      Dockerfile
    profiles/
      <profile>/
        Dockerfile
```

## Conventions

- `base` images install distro-wide build prerequisites.
- `profiles` layer toolchain-specific compilers or SDKs on top of the matching
  base image.
- The builder tree is a dependency reference, not part of the host workspace
  bootstrap flow.

## Build

Run from `builders/`:

```bash
make list
make build-all
make build-ubuntu-24.04-base
make build-ubuntu-24.04-gcc-13
make build-ubuntu-24.04-clang-18
```
