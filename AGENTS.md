# AGENTS.md — game repository conventions

This file is **identical in every game repository** of the Oh-My-Games workspace. If you are
working on a fork or opening a PR (including with an AI agent), follow it exactly.

## Project facts

- **Engine:** Godot **4.7**, GDScript with static typing. Project file: `project.godot`.
- **File names:** `snake_case`. One scene per purpose under `scenes/`, scripts under `scripts/`,
  tests under `tests/`.
- **Assets are not in Git.** `assets/`, `assets.tar.gz` and `assets.zip` are git-ignored; only
  `assets.sha256` (a content hash of `assets/`) is committed.
- **Asset bundles live on this repo's GitHub Release tagged `assets`** as two equivalent files:
  `assets.tar.gz` (macOS/Linux) and `assets.zip` (Windows).
- **No Git LFS, ever.** LFS quota is shared by every game repo in the account.
- **License:** `LICENSE` at the repo root covers the code (MIT by default — fill in the copyright
  line). Third-party asset terms live in `assets/LICENSES.md` (inside the bundle) and in
  `docs/CREDITS.md`.

## Read the README first

`README.md` has a fixed structure: Overview, Requirements, Getting the assets, Run and Tests,
Project layout, Development, Contributing. The H1 title is **centered**, carries **several badges**
(>= 4), and is followed by a single **italic one-line hook** that captures the game in a sentence —
write something evocative, not a stiff genre label. Overview shows `docs/screenshot.png`. Keep that
structure and keep **gameplay out of it** — rules, controls, walkthroughs and balance go in
`docs/GAMEPLAY.md`; credits/licenses go in `docs/CREDITS.md`.

## Assets: download them first (after clone)

`assets/` is **not** in Git. Restore it, then import once before running the project, tests or the
editor:

```bash
tools/fetch-assets.sh                        # Linux / macOS / Git Bash
powershell -File tools\fetch-assets.ps1      # Windows PowerShell
godot --headless --path . --import           # rebuild .import sidecars + .godot/ cache
```

The script uses a local `assets.tar.gz` / `assets.zip` if present, otherwise downloads the two
archives from this repo's GitHub **Release tagged `assets`**, extracts to `assets/`, and verifies
the committed `assets.sha256`. Requires Python 3.8+; `gh` only if the release is private.

The bundle ships raw files only - `.import` sidecars and the `.godot/` cache are per-machine,
git-ignored, and regenerated on import. If you pulled new code that adds a `class_name` and see
`Identifier "..." not declared` or `No loader found for resource ...`, clear the stale cache and
re-import:

```bash
rm -rf .godot && godot --headless --path . --import
```

Manual alternative - download the archive from the `assets` release into the repo root and run
`tools/fetch-assets.sh` (it uses the local bundle, extracts it, and verifies the stamp). If you
extract by hand anyway, verify with `tools/check-assets.sh`:

```bash
tar -xzf assets.tar.gz                          # macOS / Linux
Expand-Archive assets.zip -DestinationPath .    # Windows PowerShell
tools/check-assets.sh                           # verify assets/ matches assets.sha256
```

If the repo has no GitHub remote yet, only a local bundle can be used - never delete `assets/`.

## Assets: change or add them (how to contribute)

Prerequisites: Python 3.8+; `gh` authenticated; a GitHub remote to publish to.

1. Edit or add files under `assets/` (keep third-party terms in `assets/LICENSES.md`).
2. Rebuild both archives and the stamp:

   ```bash
   tools/pack-assets.sh                      # macOS / Linux / Git Bash
   powershell -File tools\pack-assets.ps1    # Windows
   ```

   This writes `assets.tar.gz`, `assets.zip` and the new `assets.sha256`.
3. Publish both archives to a GitHub Release tagged `assets` (same tag, `--clobber`):

   ```bash
   tools/push-assets.sh
   powershell -File tools\push-assets.ps1
   ```

   `tools/assets.py push` reads the `origin` remote, so it publishes to whichever repo `origin`
   points at.
4. Commit **only** the stamp, with a complete Conventional Commit (body + sign-off, see below):

   ```bash
   git add assets.sha256
   git commit    # message: chore(assets): update bundle  + body + Signed-off-by
   ```

5. Verify: `tools/check-assets.sh` must pass.

### Contributor with write access (maintainer, or a branch in the repo)

Step 3 above publishes straight to the upstream repo's `assets` Release. Nothing more to do.

### Contributor opening a PR from a fork (the normal case for agents)

You cannot publish to the upstream repo's Release (no write access). Instead:

1. Keep `origin` pointing at **your fork** (the fork default), then run `tools/push-assets.sh` — it
   publishes both bundles to **your fork's** Release tagged `assets`.
2. Commit **only** `assets.sha256`, open the PR, and **state in the PR body which fork + Release
   holds the bundle**, e.g. `bundle: https://github.com/<you>/<repo>/releases/tag/assets`.
3. Never bump `assets.sha256` without publishing the bundle somewhere the maintainer can fetch. A
   PR whose stamp has no matching bundle is **unmergeable**: the maintainer cannot verify the hash
   or rebuild the game.

### Merging a PR that changed assets (maintainer)

1. Check out the PR branch (so `assets.sha256` is the PR's new stamp), then download the
   contributor's bundle from their fork Release and let `fetch` verify it:

   ```bash
   git fetch origin pull/<N>/head:pr-<N>
   git checkout pr-<N>
   gh release download assets -R <fork-owner>/<repo> -p 'assets.tar.gz' --clobber -D .
   tools/fetch-assets.sh    # uses the local bundle, extracts it, verifies against pr-<N>'s stamp
   ```

2. Publish to the **upstream** `assets` Release (you have write access):

   ```bash
   tools/push-assets.sh
   ```

3. Run the tests, then merge.

Hard rules:

- Never `git add assets/ assets.tar.gz assets.zip`; only `assets.sha256` is committed.
- The `pre-commit` hook blocks a commit when `assets/` no longer matches `assets.sha256`.
- If `pack` or `push` cannot run (no Python, no `gh`, no remote), **stop and ask the user**. Do
  not commit a stale stamp, and do not bypass the hook with `--no-verify`.

## Commit messages (mandatory, including AI-generated commits)

Every commit - human or AI - must be complete. A bare one-line message is rejected by the hook.

```
<type>(<scope>): <summary>

<body>

Signed-off-by: <name> <email>
```

- **type**: `feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert`.
- **scope**: **required**, lowercase, the area touched (`assets`, `cards`, `ui`, `docs`, `repo`, ...).
- **summary**: imperative mood, <= 72 characters, no trailing period.
- **body**: required. Explain **what** changed and **why** (not a line-by-line retelling of the
  diff). Wrap at ~72 columns.
- **trailers**: required. End with a `Signed-off-by:` trailer. **Query the values with git config;
  never guess or hard-code them:**

```bash
git config user.name
git config user.email
# then append exactly:
#   Signed-off-by: <$(git config user.name)> <$(git config user.email)>
```

  Optional trailers: `Co-authored-by:`, `Refs:`, `Closes:`.
- `Merge`, `Revert`, `fixup!` and `squash!` commits are exempt.
- Do not use `--no-verify` to skip `commit-msg`.

Example:

```
chore(assets): host bundles on GitHub Release

Publish assets.tar.gz and assets.zip to the `assets` release and keep only
assets.sha256 in git. Remove the LFS setup and add cross-platform tooling.

Signed-off-by: Jane Doe <jane@example.com>
```

## Git and review

- Hooks are enabled via `core.hooksPath=.githooks`:
  - `pre-commit` — blocks a stale asset stamp; checks `gdformat` when installed.
  - `commit-msg` — enforces Conventional Commits.
  - `pre-push` — re-checks the asset stamp.
- CI (`.github/workflows/ci.yml`) verifies the asset stamp and runs advisory `gdformat`/`gdlint`;
  `.github/pull_request_template.md` is the PR checklist.
- Only commit or push when the user asks.

## Cross-platform

Every script ships as `*.sh` (Linux/macOS/Git Bash) and `*.ps1` (Windows PowerShell 5.1+). If
something cannot run on an OS, say so in the README.

## Scope and safety

- Do not add Git LFS, and do not commit build output (`.godot/`, exports, `*.pck`).
- Do not introduce dependencies on sibling game folders or on the workspace root; this repo must
  build and run when cloned on its own.
- Keep third-party asset terms in `assets/LICENSES.md` (it travels inside the bundle) and in
  `docs/CREDITS.md`.
