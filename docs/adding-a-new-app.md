# Adding a new app

This is the payoff of the monorepo: a new app is a folder + a few lines.

## 1. Scaffold

```bash
scripts/new-app.sh MyApp
```

This runs `tuist scaffold app --name MyApp`, creating:

```
apps/MyApp/
├── Project.swift          # 10 lines: Project.app(name: "MyApp", bundleIdSuffix: "myapp", …)
├── Sources/MyAppApp.swift # @main + RootView
├── Tests/                 # Swift Testing smoke test
├── UITests/               # XCUITest launch test
└── Resources/Assets.xcassets
```

`Workspace.swift` globs `apps/**`, so the app is picked up automatically — no
edit needed there.

## 2. Wire CI

Edit `.github/workflows/ci.yml`, copy the existing job, change the scheme:

```yaml
  my-app:
    uses: ./.github/workflows/reusable-ios-ci.yml
    with:
      scheme: MyApp
```

Push → the app builds, lints and tests on the next CI run.

## 3. (When ready) wire release

The release workflows already accept any scheme. Ship via manual dispatch:

- **Actions → Beta (TestFlight) → Run workflow →** scheme `MyApp`
- or tag `myapp-v0.1.0-beta` (adjust tag filters in `beta.yml` if you want
  per-app tag prefixes).

Register the app's bundle id + record in App Store Connect first
(see [app-store-setup.md](app-store-setup.md)). Signing is shared: add the new
bundle id to `app_identifier` in `fastlane/Matchfile` and run
`fastlane match appstore` once to mint its profile.

## 4. Share code

Put cross-app code in a module and depend on it:

```bash
tuist scaffold module --name Networking
```

Then in the app's `Project.swift`:

```swift
dependencies: [
    .project(target: "Networking", path: "../../Modules/Networking"),
]
```

## What you get for free

- Same Swift version, deployment targets, strict concurrency, lint/format rules.
- Unit + UI test targets and a coverage-enabled shared scheme.
- The full build → sign → TestFlight → App Store pipeline.
