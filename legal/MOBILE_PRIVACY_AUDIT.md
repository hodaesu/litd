# LITD — MOBILE PRIVACY / SDK AUDIT

Audit date: 2026-09-08
Status: **ORANGE — source/preset audit complete; final package audit pending.**

## Current repository findings

- Android export preset exists: package `com.hodaesu.lightinthedark`, signed export enabled.
- iOS export preset exists: bundle id `com.hodaesu.lightinthedark`, Xcode project-only export enabled.
- Source searches at this audit point did not identify Firebase, AdMob, Sentry, Mixpanel, Amplitude, HTTPRequest, HTTPClient or WebSocket references.
- No project `.gdextension` was identified by the repository scan.
- These findings do **not** establish what will be embedded by export templates, platform toolchains, future plugins, signing/build systems or release-only dependencies.

## Android final gate

Before Google Play submission, inspect the final AAB/APK and generated Android manifest for:

- all permissions;
- exported components;
- network/security configuration;
- embedded SDKs/libraries and versions;
- advertising/analytics identifiers, if any;
- user-data collection/sharing;
- runtime permission flows;
- privacy policy consistency;
- Google Play Data safety answers.

The Data safety declaration must include data handled through third-party libraries/SDKs, not only code authored by LITD.

## iOS final gate

Before App Store submission, inspect the actual Xcode archive/app bundle for:

- `Info.plist` usage descriptions;
- entitlements/capabilities;
- embedded frameworks and SDK versions;
- networking and tracking behavior;
- `PrivacyInfo.xcprivacy` files where applicable;
- required-reason APIs;
- App Store privacy-label answers.

Third-party SDK privacy manifests/signatures must be checked against Apple's then-current submission requirements.

## Release decision

Do not mark mobile privacy GREEN until the exact release candidates have been built and inspected. Any future analytics, crash-reporting, ads, authentication, cloud-save, community/network or telemetry integration reopens this audit automatically.
