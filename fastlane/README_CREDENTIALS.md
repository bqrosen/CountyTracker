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

Environment variables (CI-friendly)
----------------------------------
You can also provide the API key via environment variables instead of a JSON file. This is convenient for CI systems.

Required env vars:
- `APP_STORE_CONNECT_KEY_ID` — the Key ID shown in App Store Connect (e.g. `ABC123DEFG`).
- `APP_STORE_CONNECT_ISSUER_ID` — the Issuer ID (UUID) shown in App Store Connect.
- `APP_STORE_CONNECT_PRIVATE_KEY` — the contents of the downloaded `.p8` private key file.

Example (local shell):

```bash
# export the private key contents into the env var (keeps newlines intact)
export APP_STORE_CONNECT_KEY_ID="ABC123DEFG"
export APP_STORE_CONNECT_ISSUER_ID="00000000-0000-0000-0000-000000000000"
export APP_STORE_CONNECT_PRIVATE_KEY="$(cat /path/to/AuthKey_ABC123DEFG.p8)"

# then run the upload lane (from project root)
cd fastlane
bundle install
bundle exec fastlane upload_screenshots
```

If your CI doesn't allow multiline env vars easily, store the private key as a secure file and inject it into the environment at runtime, or base64-encode/decode during the job:

```bash
export APP_STORE_CONNECT_PRIVATE_KEY_B64=$(base64 /path/to/AuthKey_ABC123DEFG.p8)
export APP_STORE_CONNECT_PRIVATE_KEY=$(echo "$APP_STORE_CONNECT_PRIVATE_KEY_B64" | base64 --decode)
```

The `upload_screenshots` lane in `Fastfile` will use these env vars automatically when present.
