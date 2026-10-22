# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-22

### Added
- `RecordingStudioDropbox::Client` for folder listing with cursor paging, search, metadata, download, and upload.
- Chunked Dropbox upload sessions when the body is larger than 8 MiB.
- Token provider interface (`#call` or `#access_token`). This gem does not depend on RecordingStudioOauth.
- `ReconnectRequired` for expired, revoked, and missing-scope tokens, classified from HTTP status and Dropbox error tags.

### Upgrade notes
- First release. Hosts should depend on git tag `v0.1.0`. Do not add RecordingStudioOauth until that gem ships.

[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_Dropbox/releases/tag/v0.1.0
