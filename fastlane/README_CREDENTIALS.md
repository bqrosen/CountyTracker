Fastlane App Store Connect credentials
==================================

Recommended: use an App Store Connect API key (JWT) for Fastlane `deliver`.

1. Create API key
   - Go to App Store Connect → Users and Access → Keys.
   - Create a new key with the "App Manager" role (or appropriate role for uploads).
   - Download the JSON file (it contains `issuer_id`, `key_id`, and the private key).

2. Install the key locally (do NOT commit it to git)
   - Save the downloaded JSON to `fastlane/AppStoreConnectAPIKey.json`.
   - Ensure the file is ignored by git (the repo `.gitignore` already ignores `fastlane/metadata/`; add the key filename if needed).

3. Run Fastlane with the key
   - The `upload_screenshots` lane will automatically use `fastlane/AppStoreConnectAPIKey.json` if present.
   - Example:

```bash
cd fastlane
bundle install
./build_and_snapshot.sh
./organize_screenshots.sh
./resize_screenshots.sh
bundle exec fastlane upload_screenshots
```

Alternative: use `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` or `FASTLANE_SESSION`, but API keys are recommended for automation.
