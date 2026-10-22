# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-22

### Added
- `RecordingStudioDropbox::Client` for folder listing with cursor paging, search, metadata, download, and upload.
- Chunked Dropbox upload sessions when the body is larger than 8 MiB.
- `RecordingStudioDropbox::AccessToken` (`#call` first, then `#access_token`). This gem does not depend on RecordingStudioOauth.
- `Page` (`entries`, `next_cursor`, `more?`) for list and search paging.
- `DownloadedFile` (`body`, `filename`, `content_type`).
- `ReconnectRequired` for HTTP 401, `invalid_grant`, and `expired_access_token`.
- `RequestError` with `status` and `code` readers for other failed Dropbox responses.

### Upgrade notes
- First release. Hosts should depend on git tag `v0.1.0`. Do not add RecordingStudioOauth until that gem ships.
- Pass tokens through `AccessToken`, not a public `TokenProvider` class.
- Failed API calls raise `RequestError`, not `ApiError`. Paging uses `Page` and `cursor:`, not `Listing`. Download bytes are on `body`.

[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_Dropbox/releases/tag/v0.1.0
