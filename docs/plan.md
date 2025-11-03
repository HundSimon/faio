# Furry All-In-One (FAIO) — Execution Plan

## 1. Product Scope & Requirements
- **Content types**: illustrations, comics, novels; unified feed showing mixed content with source badges.
- **Target platforms**: Flutter multi-platform (Android/iOS/Desktop/Web as feasible). Prioritise mobile, keep desktop responsive.
- **Account & privacy**: local credential storage per service using encrypted storage; optional PIN/biometric lock; no server proxy.
- **Content safety**: rating filters (General/Mature/Adult), hide sensitive content by default, quick toggles and PIN-protected overrides.
- **Value-add features**: update reminders, daily check-in tracking, reading bookmarks, optional automatic novel translation, DoH/Proxy config for SNI bypass, cache encryption, offline viewing, statistics dashboard.
- **Legal & compliance**: review each service’s Terms of Service, API usage limits, copyright, and user privacy rules; ensure user-provided credentials stay on-device.

## 2. Technical Architecture (Client-Only)
- **State management**: Riverpod (or Riverpod + StateNotifier) layered over feature modules; GoRouter for navigation.
- **Layers**:
  - `core`: shared utilities, networking abstractions, error handling, secure storage helpers.
  - `data`: per-service API clients, DTOs, parsers, throttling/rate-limit handling.
  - `domain`: unified models (`FaioContent`, `FaioAuthor`, `FaioFeedItem`, etc.), repositories aggregating multiple services.
  - `presentation`: feature modules (home feed, search, detail viewers, library, settings).
- **Networking**:
  - HTTP clients using `dio` with interceptor chain for logging, retry, throttling, custom DNS/DoH.
  - SNI mitigation: in-app proxy toggle, domain fronting (where legal), and instructions for user-provided DNS-over-HTTPS endpoints.
  - OAuth / login flows handled in-app (Pixiv PKCE, FurAffinity session storage, etc.).
- **Storage**: Isar (structured cache), Hive/SharedPreferences for lightweight settings, file system for media with AES encryption and manifest for integrity.
- **Background tasks**: use `workmanager`/`android_alarm_manager_plus` for reminders, check-ins, download queues; iOS background fetch equivalents.

## 3. Service Integrations (No Backend Proxy)
| Service | Strategy | Notes |
| --- | --- | --- |
| e621 | JSON API via API key/basic auth; handle tag search, post fetch, favourites, comments. Respect rate limits, provide exponential backoff. |
| FurAffinity | HTML scraping with session cookies; Cloudflare challenges mitigated via WebView login + cookie persistence. Detect layout changes via sanity checks. |
| E-Hentai | `api.php` JSON, gallery token handling, throttle requests; integrate `g.e-hentai` fallback. Respect archive/torrent limits and user cookies. |
| Pixiv | OAuth PKCE flow using in-app browser (or WebView); refresh tokens securely stored; support illustration & novel endpoints, rankings, search. |
| Extensibility | Define plugin interface so new services (RSS, communities, novel sites) can be added with minimal wiring. |

## 4. Core Feature Modules
- **Unified Feed**: timeline aggregator merging content from all services, deduplicating by source ID, presenting multi-column responsive layout, infinite pagination.
- **Search & Filters**: global search dispatching to each service adapter concurrently; filters for rating, tags, creator; saved searches and subscriptions.
- **Detail Viewers**:
  - Illustration/comic viewer: paging, zoom, downloads, multi-resolution handling.
  - Novel reader: scroll/paginated modes, font/spacing controls, inline translation (toggleable), reading progress sync.
- **User Library**: favourites, downloads, reading history, check-in tracking; local stats.
- **Reminders & Notifications**: subscription-based updates, daily check-in reminders, configurable quiet hours; local notifications only.
- **Settings & Connectivity**: content filters, DNS/DoH settings, proxy toggle, credential management, import/export of configuration.

## 5. Infrastructure & Tooling
- **CI/CD**: set up GitHub Actions or Codemagic for build/test; secrets injected locally since no server.
- **Logging & Diagnostics**: integrate `logger` with toggled verbose mode, optional Crashlytics/Sentry (must respect privacy toggle).
- **Testing**:
  - Unit tests for parsers, API adapters with recorded fixtures.
  - Integration tests using mocked HTTP clients.
  - Golden tests for key screens, widget tests for navigation/state flows.
  - Manual E2E scenarios documented for login flows.

## 6. Milestones
1. **Foundations**: confirm legal constraints; implement project structure, core theme, navigation shell, placeholder feed with mock data.
2. **Networking Layer**: build HTTP abstraction, secure storage, e621 client MVP, Pixiv OAuth flow scaffolding.
3. **Feed & Content Models**: implement domain models, aggregator, basic feed UI bound to e621 data; add caching.
4. **Additional Services**: integrate Pixiv novels/illustrations, E-Hentai galleries, FurAffinity HTML parsing; feature flag each integration.
5. **Value-Add Features**: add translation pipeline, reminders/check-in, download manager, DoH/proxy settings.
6. **Polish & Release Prep**: performance tuning, content safety review, localization, accessibility, packaging, privacy documentation.

## 7. Immediate Next Steps
1. Scaffold project modules/folders, add base dependencies (Riverpod, Dio, Isar, etc.).
2. Implement core configuration (theme, routing) and placeholder screens (Home/Feed, Search, Library, Settings).
3. Establish network/security helpers (interceptors, secure storage abstraction) and mock service adapters for UI testing.
