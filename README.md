# gr4-dev

`gr4-dev` is a local multi-repo development workspace (superproject) for GNU Radio 4 related projects.

It provides monorepo-like developer ergonomics (bootstrap, shared env, build/install helpers) while keeping each project in its own repository under `src/`.  

**This is not intended as a dependency management system, just a quick dev workspace setup**

## What this repo owns

- Workspace bootstrap and repo orchestration
- Shared local environment wiring
- Shared install directory (`install/`)
- Build and runtime convenience scripts
- Integration-oriented docs and defaults

This repo does not own or merge application source trees.

## Quick start

1. Create local env file - edit to match your environment and build tools

```bash
cp .env.example .env
```

2. Bootstrap repos from `repos.yaml`.

```bash
./bootstrap.sh
```

3. Validate workspace state.

```bash
./scripts/doctor.sh
```

4. Load environment in your shell (do this each time a new shell is opened)

```bash
source scripts/dev-env.sh
```

5. Build and install all known repos in default order into the local prefix.

```bash
./scripts/build-all.sh
```

Default build order follows the sequence in `repos.yaml`.

## Common commands

Build one repo:

```bash
./scripts/build.sh gr4-incubator
```

Clean one repo build tree:

```bash
./scripts/clean.sh gr4-incubator
```

Clean all build trees:

```bash
./scripts/clean-all.sh
```

Wipe installed artifacts from `install/`:

```bash
./scripts/wipe.sh
# non-interactive
./scripts/wipe.sh --yes
```

## Scaffold New Projects

Create a new local out-of-tree project under `src/`:

```bash
./scripts/scaffold.sh my-new-project
```

By default, that creates a first module with the same normalized name as the
project. If you want a different initial module name, pass it as a second
argument:

```bash
./scripts/scaffold.sh my-new-project filters
```

Add another module to that project:

```bash
./scripts/add-module.sh my-new-project filters
```

Add a block to that module:

```bash
./scripts/add-block.sh my-new-project filters Gain
```

The scaffold is Bash-only and keeps the layout intentionally small:

- `src/gr4-<project>/CMakeLists.txt`
- `src/gr4-<project>/blocks/<module>/CMakeLists.txt`
- `src/gr4-<project>/blocks/<module>/include/gnuradio-4.0/<module>/`
- `src/gr4-<project>/blocks/<module>/test/`

Naming rules:

- project and module names may use lowercase letters, digits, hyphens, and underscores
- block names may use uppercase letters and are typically PascalCase, like `Copy`
- generated filesystem names use hyphens
- generated C++ identifiers use underscores

Hierarchy:

- project: repo under `src/gr4-<project>/`
- module: package under `blocks/<module>/`
- block: header/test pair under a module

## Bootstrap and refs (`repos.yaml`)

`repos.yaml` is the source of truth for:

- `name`
- `url`
- `dest`
- `ref` (branch, tag, or commit)

`./bootstrap.sh` is rerunnable and will:

- clone missing repos
- fetch updates for existing repos
- resolve refs with remote-first preference for branch names (for example `origin/main`)
- check out the resolved target in detached HEAD

If you want to develop on a local branch in a repo, create/switch branch inside that repo after bootstrap.

## Environment details

`source scripts/dev-env.sh` exports consistent workspace defaults, including:

- `CC`, `CXX` when `GR4_CC` / `GR4_CXX` are set
- `PKGCONF`, `PKG_CONFIG`
- `GR4_PREFIX` and `GR4_PREFIX_PATH`
- `PATH`, `CMAKE_PREFIX_PATH`, `PKG_CONFIG_PATH`
- `LD_LIBRARY_PATH`, `DYLD_LIBRARY_PATH`, `PYTHONPATH`
- `GNURADIO4_PLUGIN_DIRECTORIES`

## CMake args (shared and local)

For CMake repos, configure args are layered in this order:

1. `config/all.cmake.args` (committed shared defaults)
2. `config/<repo>.cmake.args` (committed per-repo defaults)
3. `build/<repo>/cmake.args` (local overrides, not committed)

`build-all.sh` always applies:

- `-DCMAKE_INSTALL_PREFIX=${GR4_PREFIX_PATH}`

Optional per-repo CMake source override:

- `config/<repo>.cmake.source`

Example: `config/gr4-studio.cmake.source` contains `blocks`, so Studio configures from `src/gr4-studio/blocks`.

When `build-all.sh` is called without args, it builds repos in `repos.yaml` order (`name` + `dest` entries).

## Notes

- No git submodules in this workspace (by design).
- Keep scripts simple and inspectable.
- Preserve repo boundaries; this is a workspace repo, not a monorepo.

## License

This project is licensed under the MIT License.

Copyright (c) 2026 Josh Morman, Altio Labs, LLC

See the LICENSE file for details.
