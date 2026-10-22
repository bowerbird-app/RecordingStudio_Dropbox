# frozen_string_literal: true

require "stringio"

module RecordingStudioDropbox
  class Client
    SIMPLE_UPLOAD_MAX_BYTES = 8 * 1024 * 1024
    SCOPES = %w[files.metadata.read files.content.read files.content.write].freeze
    PREFIX_PATHS = %w[id: ns: rev:].freeze

    def initialize(token_provider:)
      @transport = Transport.new(token_provider: token_provider)
    end

    def list(path: "", cursor: nil, page_size: nil)
      if cursor
        page_from_folder(@transport.post_json("/2/files/list_folder/continue", { cursor: cursor }))
      else
        payload = { path: normalize_folder_path(path) }
        payload[:limit] = page_size unless page_size.nil?
        page_from_folder(@transport.post_json("/2/files/list_folder", payload))
      end
    end

    def search(query:, cursor: nil, page_size: nil)
      if cursor
        page_from_search(@transport.post_json("/2/files/search/continue_v2", { cursor: cursor }))
      else
        payload = { query: query }
        payload[:options] = { max_results: page_size } unless page_size.nil?
        page_from_search(@transport.post_json("/2/files/search_v2", payload))
      end
    end

    def fetch_file(path:)
      Entry.from_api(@transport.post_json("/2/files/get_metadata", { path: normalize_entry_path(path) }))
    end

    def download(path:)
      normalized = normalize_entry_path(path)
      response = @transport.post_content("/2/files/download", arg: { path: normalized })
      DownloadedFile.new(
        body: response.body.to_s,
        filename: filename_from(download_result(response), normalized),
        content_type: nil
      )
    end

    def upload_file(path:, io:, chunk_size: SIMPLE_UPLOAD_MAX_BYTES)
      Upload.new(transport: @transport).call(
        path: normalize_entry_path(path),
        io: binary_io(io),
        chunk_size: chunk_size
      )
    end

    private

    def page_from_folder(body)
      Page.new(
        entries: Array(body["entries"]).map { |entry| Entry.from_api(entry) },
        next_cursor: cursor_when_more(body)
      )
    end

    def page_from_search(body)
      Page.new(
        entries: Array(body["matches"]).map { |match| Entry.from_api(match) },
        next_cursor: cursor_when_more(body)
      )
    end

    def cursor_when_more(body)
      body["has_more"] == true ? body["cursor"] : nil
    end

    def download_result(response)
      header = response["Dropbox-API-Result"].to_s
      return {} if header.strip.empty?

      Transport.parse_json(header)
    end

    def filename_from(result, path)
      name = result["name"].to_s
      return name unless name.empty?

      File.basename(path)
    end

    def binary_io(io)
      return StringIO.new(io.b) if io.instance_of?(String)
      if io.respond_to?(:read)
        io.binmode if io.respond_to?(:binmode)
        return io
      end

      raise ArgumentError, "upload io must be a String or respond to read"
    end

    def normalize_folder_path(path)
      raw = path.to_s.strip
      return "" if raw.empty? || raw == "/"
      return raw if prefixed_path?(raw) || raw.start_with?("/")

      "/#{raw}"
    end

    def normalize_entry_path(path)
      raw = path.to_s.strip
      raise Error, "Dropbox path is blank" if raw.empty?
      return raw if prefixed_path?(raw) || raw.start_with?("/")

      "/#{raw}"
    end

    def prefixed_path?(raw)
      PREFIX_PATHS.any? { |prefix| raw.start_with?(prefix) }
    end
  end
end
