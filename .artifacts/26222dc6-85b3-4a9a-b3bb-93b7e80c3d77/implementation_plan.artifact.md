# Google Play Store Release Build Implementation Plan

Prepare, configure signing, and build the production-ready Android App Bundle (`.aab`) for `cbc_schemes_mobile` to publish on the Google Play Store.

## User Review Required

> [!IMPORTANT]
> **Release Keystore Generation & Security**:
> A release keystore is required to sign the app for Google Play. If you do not already have an upload keystore, we will guide you on generating one securely using `keytool`. **Never commit your release keystore (`.jks`) or passwords to version control (`git`)**.

> [!NOTE]
> **Google Play Target API Requirements**:
> Google Play requires apps to target Android 14 (API level 34) or higher. We will verify that Gradle and Flutter configurations satisfy Google Play Console requirements.

## Open Questions

- Do you already have an existing upload keystore (`.jks`) for Google Play, or do you need instructions/assistance to generate a new one?
- Would you like to use Google Play App Signing (recommended by Google, where you upload an upload key and Google manages the app signing key)?

## Proposed Changes

### Android Build Configuration & Signing

#### [MODIFY] [build.gradle.kts](file:///C:/Users/hillary.kipkorir/Desktop/cbc_schemes_mobile/android/app/build.gradle.kts)
- Configure release signing configuration (`signingConfigs`) using properties loaded from `key.properties`.
- Ensure correct build types and optimization settings for release.

#### [NEW] [key.properties](file:///C:/Users/hillary.kipkorir/Desktop/cbc_schemes_mobile/android/key.properties)
- Template / configuration file for release keystore credentials (excluded from git).

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no lint or static analysis errors.
- Run `flutter test` to ensure all unit tests pass.

### Manual Verification
- Build release app bundle: `flutter build appbundle --release`
- Verify output `.aab` file located at `build/app/outputs/bundle/release/app-release.aab`.
- Test release build locally or via internal testing track on Google Play Console.
