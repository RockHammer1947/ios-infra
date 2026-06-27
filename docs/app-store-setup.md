# App Store setup — from zero to a real TestFlight upload

The release pipeline is built and runs today with **placeholder** secrets. This
checklist fills in the real Apple-side pieces. Do it once; reuse for every app.

## 1. Apple Developer Program

1. Enroll at <https://developer.apple.com/programs/> (individual or organization;
   $99/yr). Organization enrollment needs a D-U-N-S number.
2. Note your **Team ID** (Membership page) → secret `TEAM_ID`.

## 2. Register the app in App Store Connect

1. <https://appstoreconnect.apple.com> → **Apps** → **+** → **New App**.
2. Platform: iOS (and macOS if shipping a separate Mac app).
3. Bundle ID: must match `Constants.organizationIdentifier` + suffix, e.g.
   `com.yourorg.daodejing`. Register it first under
   [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list).
4. Set `APP_IDENTIFIER` and `APPLE_ID` secrets accordingly.

> ⚠️ Change `organizationIdentifier`/`organizationName` in
> `Tuist/ProjectDescriptionHelpers/Settings+Base.swift` to your own org once.

## 3. App Store Connect API key (no 2FA in CI)

1. App Store Connect → **Users and Access** → **Integrations** → **App Store
   Connect API** → **+**. Role: *App Manager* (or *Admin*).
2. Download `AuthKey_XXXXXX.p8` — **you can only download it once**.
3. Capture three secrets:
   - `APP_STORE_CONNECT_API_KEY_ID` — the key ID (e.g. `2X9R4HXF34`)
   - `APP_STORE_CONNECT_API_ISSUER_ID` — the issuer UUID shown on that page
   - `APP_STORE_CONNECT_API_KEY` — base64 of the .p8:
     ```bash
     base64 -i AuthKey_XXXXXX.p8 | pbcopy
     ```

## 4. Code signing via fastlane match

`match` stores certificates + provisioning profiles encrypted in a **private**
git repo, and CI reads them read-only.

1. Create a private repo, e.g. `your-org/certificates`.
2. From a Mac, generate and push App Store signing assets once:
   ```bash
   bundle exec fastlane match appstore
   ```
   You'll be asked for an encryption passphrase → secret `MATCH_PASSWORD`.
3. Secrets:
   - `MATCH_GIT_URL` — the certs repo URL
   - `MATCH_PASSWORD` — the passphrase
   - `MATCH_GIT_BASIC_AUTHORIZATION` — base64 of `git-user:personal-access-token`
     so CI can clone the private repo:
     ```bash
     echo -n "your-user:ghp_xxx" | base64
     ```

## 5. CI keychain

- `KEYCHAIN_PASSWORD` — any random string. `setup_ci` creates a throwaway
  keychain on the runner with it.

## 6. Add all secrets to GitHub

Repo → **Settings** → **Secrets and variables** → **Actions** → add every name
from `fastlane/.env.example`:

```
APP_IDENTIFIER  APPLE_ID  TEAM_ID
APP_STORE_CONNECT_API_KEY_ID  APP_STORE_CONNECT_API_ISSUER_ID  APP_STORE_CONNECT_API_KEY
MATCH_GIT_URL  MATCH_PASSWORD  MATCH_GIT_BASIC_AUTHORIZATION
KEYCHAIN_PASSWORD
```

(For local runs instead, `cp fastlane/.env.example fastlane/.env` and fill it in.)

## 7. First upload

```bash
# Tag-triggered:
git tag v0.1.0-beta && git push origin v0.1.0-beta      # → TestFlight
# or run the "Beta (TestFlight)" workflow manually from the Actions tab.
```

A successful run uploads a build to TestFlight. For App Store review, push a
`vX.Y.Z` tag (runs the `release` lane → `deliver` with the metadata in
`fastlane/metadata/`).

## 8. In-app purchase (解锁全本) + pricing

常道 is free to download with a free preview (chapters 1–3); a single
non-consumable unlocks all 81 chapters. Code lives in the reusable `Purchases`
module (StoreKit 2) and `ReaderFeature` (paywall + gating).

### Create the product in App Store Connect

1. **App Store Connect → your app → In-App Purchases → +** → **Non-Consumable**.
2. **Product ID:** `com.example.daodejing.fullaccess` (must match
   `ReaderProducts.fullAccess`; change the org prefix to your own).
3. Reference name: `Full Access`; add localizations (zh-Hans「常道 · 完整版」,
   en「Chang Dao · Full Access」).

### Pricing — $6 international, ¥6 China

1. Set the **base price** to the **$5.99 / US$6 price point** (this fills in
   localized prices for every storefront automatically).
2. The auto-filled China price will be ~¥40; override it. In the price
   schedule, choose **Edit prices per territory → China mainland (CNY)** and set
   the custom price to the **¥6 price point**. App Store Connect keeps the rest
   of the world at the $6-derived prices.
3. The app shows whatever StoreKit returns for the buyer's storefront
   (`product.displayPrice`) — no hardcoded prices.

### Testing the flow

- **Local / CI (no account):** open `apps/DaodejingReader/StoreKit/Configuration.storekit`
  in Xcode, then **Edit Scheme → Run → Options → StoreKit Configuration →
  Configuration.storekit**. Run the app, open a gated chapter (e.g. 第八章
  上善若水) → the paywall purchases instantly in test mode.
- **Device sandbox:** create a Sandbox tester in App Store Connect (Users and
  Access → Sandbox), sign in on the device, and buy against the real product.
- Gating logic (`AccessPolicy`) is unit-tested in `PurchasesTests`.

## Troubleshooting

- **`No profiles for '...' were found`** — bundle id mismatch, or run
  `fastlane match appstore` again to (re)generate the profile.
- **`Authentication credentials are missing or invalid`** — re-check the three
  `APP_STORE_CONNECT_API_*` secrets; the key must be base64-encoded.
- **match can't clone repo** — `MATCH_GIT_BASIC_AUTHORIZATION` token lacks repo
  read scope.
