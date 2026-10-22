# frozen_string_literal: true

require "json"
require "net/http"
require "stringio"
require "test_helper"

class ClientTest < Minitest::Test
  FakeResponse = Struct.new(:body, :code, :headers, :success, keyword_init: true) do
    def [](key)
      headers[key]
    end

    def is_a?(klass)
      return success if klass == Net::HTTPSuccess

      super
    end
  end

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
      listing = client.list_folder(path: "Docs")

      assert_equal :folder, listing.kind
      assert_equal "cur-1", listing.cursor
      assert_equal true, listing.has_more
      assert listing.entries[0].folder?
      assert listing.entries[1].file?
      assert_equal "Brief.pdf", listing.entries[1].name
    end

    assert_equal({ "path" => "/Docs" }, JSON.parse(captured.first[:body]))
    assert_equal "Bearer access-token", captured.first[:authorization]
    assert_equal "api.dropboxapi.com", captured.first[:host]
  end

  def test_list_folder_continues_with_a_cursor
    captured = []
    body = { "entries" => [], "cursor" => "cur-2", "has_more" => false }

    stub_http([{ path: "/2/files/list_folder/continue", response: json_ok(body), capture: captured }]) do
      listing = client.list_folder(cursor: "cur-1")

      assert_equal "cur-2", listing.cursor
      assert_equal false, listing.has_more
      assert_empty listing.entries
    end

    assert_equal({ "cursor" => "cur-1" }, JSON.parse(captured.first[:body]))
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
      listing = client.search(query: "Notes", path: "")

      assert_equal :search, listing.kind
      assert_equal "Notes.txt", listing.entries.first.name
      assert_equal "id:file-9", listing.entries.first.id
    end

    assert_equal "Notes", JSON.parse(captured.first[:body])["query"]
  end

  def test_search_continues_with_a_cursor
    captured = []
    body = { "matches" => [], "cursor" => "search-2", "has_more" => false }

    stub_http([{ path: "/2/files/search/continue_v2", response: json_ok(body), capture: captured }]) do
      listing = client.search(query: "Notes", cursor: "search-1")

      assert_equal "search-2", listing.cursor
      assert_empty listing.entries
    end

    assert_equal({ "cursor" => "search-1" }, JSON.parse(captured.first[:body]))
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

  def test_download_returns_bytes_and_result_metadata
    captured = []
    result = { ".tag" => "file", "id" => "id:file-1", "name" => "Brief.pdf", "path_display" => "/Brief.pdf" }
    response = FakeResponse.new(
      body: "pdf-bytes",
      code: "200",
      headers: { "Dropbox-API-Result" => JSON.generate(result) },
      success: true
    )

    stub_http([{ path: "/2/files/download", response: response, capture: captured }]) do
      file = client.download(path: "id:file-1")

      assert_equal "pdf-bytes", file.bytes
      assert_equal "Brief.pdf", file.name
      assert_equal "id:file-1", file.id
    end

    assert_equal "content.dropboxapi.com", captured.first[:host]
    assert_equal JSON.generate({ path: "id:file-1" }), captured.first[:dropbox_arg]
  end

  def test_download_without_result_header_still_returns_bytes
    response = FakeResponse.new(body: "raw", code: "200", headers: {}, success: true)

    stub_http([{ path: "/2/files/download", response: response }]) do
      file = client.download(path: "/Brief.pdf")

      assert_equal "raw", file.bytes
      assert_equal "Brief.pdf", file.name
    end
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
    assert_equal JSON.generate({ path: "/note.txt", mode: "add" }), captured.first[:dropbox_arg]
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
    assert_equal JSON.generate(finish_arg), captured[2][:dropbox_arg]
  end

  def test_expired_access_token_raises_reconnect_required
    response = json_error(401, { "error" => { ".tag" => "expired_access_token" } })

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

  def test_path_errors_raise_api_error
    response = json_error(409, { "error" => { ".tag" => "path" } })

    stub_http([{ path: "/2/files/get_metadata", response: response }]) do
      error = assert_raises(RecordingStudioDropbox::ApiError) { client.metadata(path: "/missing") }

      assert_equal 409, error.status
      assert_equal "path", error.tag
    end
  end

  def test_empty_upload_raises_error
    error = assert_raises(RecordingStudioDropbox::Error) do
      client.upload(path: "/empty.txt", content: "")
    end

    assert_equal "Upload content is empty", error.message
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

  def test_non_json_failure_raises_api_error
    response = FakeResponse.new(body: "gateway timeout", code: "504", headers: {}, success: false)

    stub_http([{ path: "/2/files/list_folder", response: response }]) do
      error = assert_raises(RecordingStudioDropbox::ApiError) { client.list_folder }

      assert_equal 504, error.status
    end
  end

  def test_string_token_provider
    captured = []
    listing = json_ok("entries" => [], "cursor" => "c", "has_more" => false)
    stub_http([{ path: "/2/files/list_folder", response: listing, capture: captured }]) do
      RecordingStudioDropbox::Client.new(token_provider: "static-token").list_folder
    end

    assert_equal "Bearer static-token", captured.first[:authorization]
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
    FakeResponse.new(body: JSON.generate(payload), code: "200", headers: {}, success: true)
  end

  def json_error(status, payload)
    FakeResponse.new(body: JSON.generate(payload), code: status.to_s, headers: {}, success: false)
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
