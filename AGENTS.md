# Repository Guidelines

## Project Structure & Module Organization
This Flutter app lives under `lib/`, with `lib/data/e621` and `lib/data/pixiv` covering API clients and credentials while feature UIs (feed, settings, galleries) sit in `lib/features`. Network stacks rely on `rhttp` instead of `dio`, so reuse helpers under `lib/data` when adding requests. Platform scaffolding stays in `android`, `ios`, `linux`, `macos`, `web`, and `windows`, with reference docs in `docs/` and vendored assets in `third_party/`. Target the empty `test/` tree for new specs.

## Build, Test, and Development Commands
- `export PATH=/opt/flutter/bin:$PATH && flutter pub get`: installs and updates dependencies using the pinned SDK at `/opt/flutter`.
- `flutter run -d chrome` or `flutter run -d macos`: boots the app locally; pick a device that matches the feature you are targeting.
- `flutter analyze`: runs the static analyzer configured by `analysis_options.yaml`.
- `flutter test --coverage`: executes unit/widget tests (once they exist) and emits coverage in `coverage/lcov.info` for CI uploads.
- `flutter build apk --release`: produces the distributable Android artifact; use analogous `flutter build macos` / `ipa` commands for other platforms.

## Coding Style & Naming Conventions
Follow Dart defaults: two-space indentation, lowerCamelCase members, PascalCase widgets, and SCREAMING_SNAKE_CASE constants. Keep files focused on a single widget or service and keep mocks nearby. Run `dart format lib test` before opening a PR, and only silence `package:flutter_lints` rules with inline justification.

## Testing Guidelines
Add unit tests for credential and network helpers, and widget tests for feed/settings flows under `test/`. Name specs after the class under test (for example, `feed_controller_test.dart`). Prefer golden tests only when UI states stabilize, and ensure asynchronous tests pump frames (`tester.pumpAndSettle`) to catch flakes locally.

## Commit & Pull Request Guidelines
Commits must follow Conventional Commits (`feat(auth): add pixiv refresh flow`) with 72-character subjects and wrapped bodies for context. When opening a PR, link the relevant issue, describe UI changes (attach screenshots or recordings for feed/settings), and call out new configuration requirements. Keep PRs focused so API, UI, and state changes can be reviewed independently.

## Security & Configuration Tips
Store e621 usernames and API keys, along with Pixiv refresh tokens, only through the in-app Settings forms so they remain outside version control. When touching network layers, retain the Pixiv `Referer: https://app-api.pixiv.net/` header and avoid logging sensitive headers. Document new auth or caching steps in `docs/` so contributors can reproduce flows without guesswork.
