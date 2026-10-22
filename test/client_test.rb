# frozen_string_literal: true

require "json"
require "net/http"
require "stringio"
require "test_helper"

class ClientTest < Minitest::Test
  UNICODE_PATH = "/Résumé/naïve.pdf"

  def test_list_folder_returns_entries_and_cursor
    captured = []
    body = {
      "entries" => [
        { ".tag" => "folder", "id" => "id:folder-1", "name" => "Docs", "path_display" => "/Docs" },
        {
          ".tag" => "file",
          "id" => "id:file-1",
          "name" => "Brief.pdf",
          "path_display" => "/Docs/Brief.pdf",
          "size" => 12
        }
      ],
      "cursor" => "cur-1",
      "has_more" => true
    }

    stub_http([{ path: "/2/files/list_folder", response: json_ok(body), capture: captured }]) do
      page = client.list_folder(path: "Docs")

      assert_equal "cur-1", page.next_cursor
      assert page.more?
      assert page.entries[0].folder?
      assert page.entries[1].file?
      assert_equal "Brief.pdf", page.entries[1].name
    end

    assert_equal({ "path" => "/Docs" }, JSON.parse(captured.first[:body]))
    assert_equal "Bearer access-token", captured.first[:authorization]
    assert_equal "api.dropboxapi.com", captured.first[:host]
  end

  def test_list_folder_continues_with_a_cursor
    captured = []
    body = { "entries" => [], "cursor" => "cur-2", "has_more" => false }

    stub_http([{ path: "/2/files/list_folder/continue", response: json_ok(body), capture: captured }]) do
      page = client.list_folder(cursor: "cur-1")

      assert_nil page.next_cursor
      refute page.more?
      assert_empty page.entries
    end

    assert_equal({ "cursor" => "cur-1" }, JSON.parse(captured.first[:body]))
  end

  def test_list_folder_keeps_an_id_scoped_path
    captured = []
    body = { "entries" => [], "cursor" => "cur-id", "has_more" => false }

    stub_http([{ path: "/2/files/list_folder", response: json_ok(body), capture: captured }]) do
      page = client.list_folder(path: "id:abc")

      refute page.more?
    end

    assert_equal({ "path" => "id:abc" }, JSON.parse(captured.first[:body]))
  end

  def test_search_unwraps_match_metadata
    captured = []
    body = {
      "matches" => [
        {
          "metadata" => {
            "metadata" => {
              ".tag" => "file",
              "id" => "id:file-9",
              "name" => "Notes.txt",
              "path_display" => "/Notes.txt"
            }
          }
        }
      ],
      "cursor" => "search-cur",
      "has_more" => false
    }

    stub_http([{ path: "/2/files/search_v2", response: json_ok(body), capture: captured }]) do
      page = client.search(query: "Notes", path: "")

      assert_equal "Notes.txt", page.entries.first.name
      assert_equal "id:file-9", page.entries.first.id
    end

    assert_equal "Notes", JSON.parse(captured.first[:body])["query"]
  end

  def test_search_continues_with_a_cursor
    captured = []
    body = { "matches" => [], "cursor" => "search-2", "has_more" => false }

    stub_http([{ path: "/2/files/search/continue_v2", response: json_ok(body), capture: captured }]) do
      page = client.search(query: "Notes", cursor: "search-1")

      assert_nil page.next_cursor
      assert_empty page.entries
    end

    assert_equal({ "cursor" => "search-1" }, JSON.parse(captured.first[:body]))
  end

  def test_search_keeps_an_id_scoped_path
    captured = []
    body = { "matches" => [], "cursor" => "search-id", "has_more" => false }

    stub_http([{ path: "/2/files/search_v2", response: json_ok(body), capture: captured }]) do
      client.search(query: "pdf", path: "id:abc")
    end

    assert_equal "id:abc", JSON.parse(captured.first[:body]).dig("options", "path")
  end

  def test_metadata_posts_get_metadata
    captured = []
    body = {
      ".tag" => "file",
      "id" => "id:file-1",
      "name" => "Brief.pdf",
      "path_display" => "/Brief.pdf",
      "size" => 12
    }

    stub_http([{ path: "/2/files/get_metadata", response: json_ok(body), capture: captured }]) do
      entry = client.metadata(path: "id:file-1")

      assert_equal "Brief.pdf", entry.name
      assert_equal true, entry.file?
    end

    assert_equal({ "path" => "id:file-1" }, JSON.parse(captured.first[:body]))
  end

  def test_metadata_keeps_ns_and_rev_paths
    captured = []
    body = { ".tag" => "file", "id" => "id:file-1", "name" => "Brief.pdf", "path_display" => "/Brief.pdf" }

    stub_http([{ path: "/2/files/get_metadata", response: json_ok(body), capture: captured }]) do
      client.metadata(path: "ns:123")
    end
    stub_http([{ path: "/2/files/get_metadata", response: json_ok(body), capture: captured }]) do
      client.metadata(path: "rev:abc")
    end

    assert_equal({ "path" => "ns:123" }, JSON.parse(captured[0][:body]))
    assert_equal({ "path" => "rev:abc" }, JSON.parse(captured[1][:body]))
  end

  def test_download_returns_body_and_result_metadata
    captured = []
    result = { ".tag" => "file", "id" => "id:file-1", "name" => "Brief.pdf", "path_display" => "/Brief.pdf" }
    response = http_response(
      code: 200,
      body: "pdf-bytes",
      headers: { "Dropbox-API-Result" => JSON.generate(result), "Content-Type" => "application/pdf" }
    )

    stub_http([{ path: "/2/files/download", response: response, capture: captured }]) do
      file = client.download(path: "id:file-1")

      assert_equal "pdf-bytes", file.body
      assert_equal "Brief.pdf", file.filename
      assert_equal "application/pdf", file.content_type
    end

    assert_equal "content.dropboxapi.com", captured.first[:host]
    assert_equal JSON.generate({ path: "id:file-1" }, ascii_only: true), captured.first[:dropbox_arg]
  end

  def test_download_without_result_header_still_returns_body
    response = http_response(code: 200, body: "raw", headers: { "Content-Type" => "application/octet-stream" })

    stub_http([{ path: "/2/files/download", response: response }]) do
      file = client.download(path: "/Brief.pdf")

      assert_equal "raw", file.body
      assert_equal "Brief.pdf", file.filename
      assert_equal "application/octet-stream", file.content_type
    end
  end

  def test_download_escapes_non_ascii_path_in_dropbox_api_arg
    captured = []
    result = { ".tag" => "file", "name" => "naïve.pdf", "path_display" => UNICODE_PATH }
    response = http_response(
      code: 200,
      body: "pdf",
      headers: { "Dropbox-API-Result" => JSON.generate(result), "Content-Type" => "application/pdf" }
    )

    stub_http([{ path: "/2/files/download", response: response, capture: captured }]) do
      file = client.download(path: UNICODE_PATH)

      assert_equal "pdf", file.body
      assert_equal "naïve.pdf", file.filename
    end

    assert_includes captured.first[:dropbox_arg], '\u00e9'
  end

  def test_upload_uses_simple_upload_for_small_files
    captured = []
    body = { ".tag" => "file", "id" => "id:up-1", "name" => "note.txt", "path_display" => "/note.txt" }

    stub_http([{ path: "/2/files/upload", response: json_ok(body), capture: captured }]) do
      uploaded = client.upload(path: "/note.txt", content: "hi")

      assert_equal "id:up-1", uploaded.id
      assert_equal "note.txt", uploaded.name
      assert_equal "/note.txt", uploaded.path
    end

    assert_equal "hi", captured.first[:body]
    assert_equal JSON.generate({ path: "/note.txt", mode: "add" }, ascii_only: true), captured.first[:dropbox_arg]
  end

  def test_upload_escapes_non_ascii_path_in_dropbox_api_arg
    captured = []
    body = { ".tag" => "file", "id" => "id:up-u", "name" => "naïve.pdf", "path_display" => UNICODE_PATH }

    stub_http([{ path: "/2/files/upload", response: json_ok(body), capture: captured }]) do
      client.upload(path: UNICODE_PATH, content: "pdf")
    end

    assert_includes captured.first[:dropbox_arg], '\u00e9'
  end

  def test_upload_at_chunk_size_uses_a_single_simple_upload
    captured = []
    body = { ".tag" => "file", "id" => "id:up-eq", "name" => "exact.bin", "path_display" => "/exact.bin" }
    content = "abcd"

    stub_http([{ path: "/2/files/upload", response: json_ok(body), capture: captured }]) do
      uploaded = client.upload(path: "/exact.bin", content: content, chunk_size: content.bytesize)

      assert_equal "id:up-eq", uploaded.id
    end

    assert_equal 1, captured.size
    assert_equal content, captured.first[:body]
    assert_equal "/2/files/upload", captured.first[:path]
  end

  def test_upload_just_over_chunk_size_starts_then_finishes_without_append
    captured = []
    start = json_ok("session_id" => "sess-eq")
    finish = json_ok(".tag" => "file", "id" => "id:up-plus", "name" => "over.bin", "path_display" => "/over.bin")
    requests = [
      { path: "/2/files/upload_session/start", response: start, capture: captured },
      { path: "/2/files/upload_session/finish", response: finish, capture: captured }
    ]

    stub_http(requests) do
      uploaded = client.upload(path: "/over.bin", content: "abcde", chunk_size: 4)

      assert_equal "id:up-plus", uploaded.id
    end

    assert_equal 2, captured.size
    assert_equal "abcd", captured[0][:body]
    assert_equal "e", captured[1][:body]
    refute(captured.any? { |request| request[:path] == "/2/files/upload_session/append_v2" })
  end

  def test_upload_uses_a_session_when_content_exceeds_chunk_size
    captured = []
    start = json_ok("session_id" => "sess-1")
    finish = json_ok(".tag" => "file", "id" => "id:up-2", "name" => "big.bin", "path_display" => "/big.bin")
    requests = [
      { path: "/2/files/upload_session/start", response: start, capture: captured },
      { path: "/2/files/upload_session/append_v2", response: json_ok({}), capture: captured },
      { path: "/2/files/upload_session/finish", response: finish, capture: captured }
    ]

    stub_http(requests) do
      uploaded = client.upload(path: "/big.bin", content: "abcdefghij", chunk_size: 4)

      assert_equal "id:up-2", uploaded.id
    end

    assert_equal 3, captured.size
    assert_equal "abcd", captured[0][:body]
    assert_equal "efgh", captured[1][:body]
    assert_equal "ij", captured[2][:body]
    finish_arg = {
      cursor: { session_id: "sess-1", offset: 8 },
      commit: { path: "/big.bin", mode: "add" }
    }
    assert_equal JSON.generate(finish_arg, ascii_only: true), captured[2][:dropbox_arg]
  end

  def test_expired_access_token_raises_reconnect_required
    response = json_error(401, { "error" => { ".tag" => "expired_access_token" } })

    stub_http([{ path: "/2/files/list_folder", response: response }]) do
      assert_raises(RecordingStudioDropbox::ReconnectRequired) { client.list_folder }
    end
  end

  def test_invalid_grant_raises_reconnect_required
    response = json_error(400, { "error" => "invalid_grant" })

    stub_http([{ path: "/2/files/list_folder", response: response }]) do
      assert_raises(RecordingStudioDropbox::ReconnectRequired) { client.list_folder }
    end
  end

  def test_revoked_token_raises_reconnect_required
    response = json_error(401, { "error" => { ".tag" => "invalid_access_token" } })

    stub_http([{ path: "/2/files/get_metadata", response: response }]) do
      assert_raises(RecordingStudioDropbox::ReconnectRequired) { client.metadata(path: "/gone") }
    end
  end

  def test_missing_scope_raises_reconnect_required
    response = json_error(403, { "error" => { ".tag" => "missing_scope" } })

    stub_http([{ path: "/2/files/list_folder", response: response }]) do
      assert_raises(RecordingStudioDropbox::ReconnectRequired) { client.list_folder }
    end
  end

  def test_http_401_raises_reconnect_required_without_a_tag
    response = json_error(401, {})

    stub_http([{ path: "/2/files/list_folder", response: response }]) do
      assert_raises(RecordingStudioDropbox::ReconnectRequired) { client.list_folder }
    end
  end

  def test_path_errors_raise_request_error
    response = json_error(409, { "error" => { ".tag" => "path" } })

    stub_http([{ path: "/2/files/get_metadata", response: response }]) do
      error = assert_raises(RecordingStudioDropbox::RequestError) { client.metadata(path: "/missing") }

      assert_equal 409, error.status
      assert_equal "path", error.code
      refute_includes error.message, "path"
    end
  end

  def test_empty_upload_raises_error
    assert_raises(RecordingStudioDropbox::Error) do
      client.upload(path: "/empty.txt", content: "")
    end
  end

  def test_metadata_requires_a_path
    assert_raises(RecordingStudioDropbox::Error) { client.metadata(path: "  ") }
  end

  def test_upload_reads_an_io
    captured = []
    body = { ".tag" => "file", "id" => "id:up-io", "name" => "io.txt", "path_display" => "/io.txt" }
    io = StringIO.new("from-io")

    stub_http([{ path: "/2/files/upload", response: json_ok(body), capture: captured }]) do
      uploaded = client.upload(path: "/io.txt", content: io)

      assert_equal "id:up-io", uploaded.id
    end

    assert_equal "from-io", captured.first[:body]
  end

  def test_non_json_failure_raises_request_error
    response = http_response(code: 504, body: "gateway timeout")

    stub_http([{ path: "/2/files/list_folder", response: response }]) do
      error = assert_raises(RecordingStudioDropbox::RequestError) { client.list_folder }

      assert_equal 504, error.status
      refute_includes error.message, "gateway timeout"
    end
  end

  def test_string_token_provider_raises_argument_error
    assert_raises(ArgumentError) do
      RecordingStudioDropbox::Client.new(token_provider: "static-token").list_folder
    end
  end

  def test_blank_token_raises_reconnect_required_before_http
    started = false
    Net::HTTP.stub(:start, lambda { |*|
      started = true
      raise "should not connect"
    }) do
      error_client = RecordingStudioDropbox::Client.new(token_provider: -> { "" })
      assert_raises(RecordingStudioDropbox::ReconnectRequired) { error_client.list_folder }
    end

    refute started
  end

  private

  def client
    RecordingStudioDropbox::Client.new(token_provider: -> { "access-token" })
  end

  def json_ok(payload)
    http_response(code: 200, body: JSON.generate(payload))
  end

  def json_error(status, payload)
    http_response(code: status, body: JSON.generate(payload))
  end

  def http_response(code:, body:, headers: {})
    response = Net::HTTPResponse::CODE_TO_OBJ.fetch(code.to_s).new("1.1", code.to_s, "")
    headers.each { |key, value| response[key] = value }
    response.define_singleton_method(:body) { body }
    response
  end

  def stub_http(queue, &)
    remaining = queue.dup
    Net::HTTP.stub(:start, lambda { |host, _port, **_options, &http_block|
      http = Object.new
      http.define_singleton_method(:request) do |request|
        spec = remaining.shift
        raise "unexpected Dropbox request #{request.path}" unless spec
        raise "path mismatch #{request.path} vs #{spec[:path]}" unless request.path == spec[:path]

        if spec[:capture]
          spec[:capture] << {
            host: host,
            path: request.path,
            body: request.body,
            authorization: request["Authorization"],
            dropbox_arg: request["Dropbox-API-Arg"]
          }
        end
        spec[:response]
      end
      http_block.call(http)
    }, &)
  end
end
