# ios-infra

Reusable infrastructure for shipping iOS + macOS apps to the App Store. The
first app is **道德经阅读器 / Tao Te Ching Reader** (a placeholder — no reader
logic yet), but everything here is built so the **next** app is a new folder and
a few lines of config.

## What's inside

| Layer | Tooling | Where |
|---|---|---|
| Project generation | [Tuist](https://tuist.dev) (Swift manifests + scaffold templates) | `Tuist/`, `Workspace.swift`, `apps/*/Project.swift` |
| Shared code | Static-framework modules | `Modules/AppCore`, `Modules/DesignSystem` |
| Tests | Swift Testing (unit) + XCUITest (UI) + coverage | `apps/*/Tests`, `apps/*/UITests` |
| Lint/format | SwiftLint + SwiftFormat | `.swiftlint.yml`, `.swiftformat` |
| Signing | fastlane **match** + App Store Connect API key | `fastlane/Matchfile`, `fastlane/Fastfile` |
| Release | fastlane (TestFlight + App Store) | `fastlane/Fastfile` |
| CI/CD | GitHub Actions, reusable workflows | `.github/workflows/` |
| Toolchain pinning | mise + Bundler | `.mise.toml`, `Gemfile` |

## Quick start (macOS, Xcode 16+)

```bash
scripts/bootstrap.sh        # installs tools, gems, generates iOSInfra.xcworkspace
open iOSInfra.xcworkspace
```

Generated `*.xcodeproj`/`*.xcworkspace` are **not committed** — always regenerate
with `tuist generate`.

### Run / debug locally

- **On the Mac** (no signing needed): pick the `DaodejingReader` scheme, choose the
  **My Mac** destination, `⌘R`.
- **On a real iPhone**: export your Apple Developer **Team ID** before generating so
  it's baked into the project (never committed) and survives regeneration:

  ```bash
  export DEVELOPMENT_TEAM=XXXXXXXXXX   # Xcode ▸ Settings ▸ Accounts ▸ your team
  mise exec -- tuist generate
  ```

  Then select your device and `⌘R`; first run, trust the developer cert on the
  phone under **Settings ▸ General ▸ VPN & Device Management**.
- **Test the paywall locally**: Edit Scheme ▸ Run ▸ Options ▸ StoreKit Configuration →
  `apps/DaodejingReader/StoreKit/Configuration.storekit`.

## Everyday commands

```bash
bundle exec fastlane ios lint     # SwiftLint --strict + SwiftFormat --lint
bundle exec fastlane ios test     # generate + unit/UI tests on a simulator
bundle exec fastlane ios beta     # build + upload to TestFlight  (needs secrets)
bundle exec fastlane ios release  # build + submit to App Store    (needs secrets)
```

## Adding a new app (the point of this repo)

```bash
scripts/new-app.sh MyApp          # scaffolds apps/MyApp + regenerates
```

Then add a one-line CI job (`.github/workflows/ci.yml`) with `scheme: MyApp`.
Full walkthrough: [docs/adding-a-new-app.md](docs/adding-a-new-app.md).

## Shipping to the App Store

The release pipeline is fully wired but ships with **placeholder secrets**. To
make TestFlight/App Store uploads real, follow
[docs/app-store-setup.md](docs/app-store-setup.md) — create an Apple Developer
account, an App Store Connect API key, and a private `match` certificates repo,
then add the secrets to GitHub. CI/CD details: [docs/ci-cd.md](docs/ci-cd.md).

## Status

- ✅ Build + lint + test pipeline runs on every PR (no secrets required).
- ⏳ TestFlight/App Store upload lanes are wired and waiting on real Apple
  credentials (see setup doc).
