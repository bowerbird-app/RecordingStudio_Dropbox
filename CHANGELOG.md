# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-22

### Added
- `RecordingStudioDropbox::Client` for folder listing with cursor paging, search, fetch_file, download, and upload.
- Chunked Dropbox upload sessions when the body is larger than 8 MiB.
- `RecordingStudioDropbox::AccessToken` (`#call` first, then `#access_token`). This gem does not depend on RecordingStudioOauth.
- Shared public shape with RecordingStudio Google Drive: `search(query:, cursor:, page_size:)` (not folder-scoped; no `path:`), `list(path:, cursor:, page_size:)`, `fetch_file(path:)`, `upload_file(path:, io:)` (no `content_type:`; Dropbox does not use it), `Page = Data.define(:entries, :next_cursor)`, `DownloadedFile = Data.define(:body, :filename, :content_type)`, `RequestError.new(message = nil, status: nil, code: nil)`, `configure` returns the config. Locators stay provider-native: Dropbox `path:` vs Google Drive ids.
- `ReconnectRequired` for HTTP 401, `invalid_grant`, and `expired_access_token`.
- `RequestError` with `status` and `code` (the Dropbox error tag). The message is `error_summary`, not the response body.

### Upgrade notes
- First release. Hosts should depend on git tag `v0.1.0`. Do not add RecordingStudioOauth until that gem ships.
- Pass tokens through `AccessToken`, not a public `TokenProvider` class.
- Failed API calls raise `RequestError`, not `ApiError`. Paging uses `Page` and `cursor:`, not `Listing`. Download bytes are on `body`. `DownloadedFile#content_type` is always `nil`.
- Call `list`, `fetch_file`, and `upload_file(path:, io:)`. There are no `list_folder`, `metadata`, `content:`, or `content_type:` aliases.

[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_Dropbox/releases/tag/v0.1.0
