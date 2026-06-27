# CI/CD

All pipelines run on GitHub-hosted **macOS** runners. Tooling is pinned by
`.mise.toml` (Tuist/SwiftLint/SwiftFormat) and `Gemfile` (fastlane), so local
and CI behave identically.

## Workflows

| File | Trigger | Does | Secrets |
|---|---|---|---|
| `ci.yml` | push to `main`/`claude/**`, PRs | calls `reusable-ios-ci` per app | none |
| `reusable-ios-ci.yml` | `workflow_call` | select Xcode → mise → ruby → `fastlane lint` → `fastlane test` | none |
| `beta.yml` | tag `*-beta`, manual | calls `reusable-ios-release` with `lane: beta` | inherited |
| `release.yml` | tag `vX.Y.Z`, manual | calls `reusable-ios-release` with `lane: release` | inherited |
| `reusable-ios-release.yml` | `workflow_call` | build + sign (match) + upload | all Apple secrets |

The two `reusable-*` workflows are the **reuse seam**: a new app adds one job
that calls them with its `scheme`; no pipeline logic is copied.

## Stage → fastlane mapping

```
lint     → swiftlint --strict + swiftformat --lint
test     → tuist generate + scan (simulator, coverage, no signing)
beta     → api key → setup_ci → match → tuist generate → gym → upload_to_testflight
release  → … same build … → upload_to_app_store (deliver, submit for review)
```

Build number = `github.run_number`, injected as `CURRENT_PROJECT_VERSION` via
gym `xcargs` (so Tuist regeneration never clobbers it). Marketing version comes
from the git tag.

## Why it's green without secrets

`ci.yml` only builds and tests on a **simulator**, which needs no signing. That
is the proof the whole generate→build→test→lint chain works. The signing/upload
steps live exclusively in the release workflows and only run on tags, where the
secrets exist.

## Running a stage locally

```bash
bundle exec fastlane ios test     # same as CI's test stage
bundle exec fastlane ios lint     # same as CI's lint stage
```

## Tuning

- **Xcode version**: `xcode-version` input on the reusable workflows (default
  `16.1`).
- **Runner**: `runner` input (default `macos-14`). Swap for a self-hosted label
  to cut cost/latency.
- **Simulator**: `destination` in `fastlane/Fastfile` (`test` lane).
