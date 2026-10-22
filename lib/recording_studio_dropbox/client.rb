# frozen_string_literal: true

require "json"
require "stringio"

module RecordingStudioDropbox
  class Client
    SIMPLE_UPLOAD_MAX_BYTES = 8 * 1024 * 1024
    SCOPES = %w[files.metadata.read files.content.read files.content.write].freeze

    def initialize(token_provider:)
      @transport = Transport.new(token_provider: token_provider)
    end

    def list_folder(path: "", cursor: nil)
      if cursor
        listing_from_folder(@transport.post_json("/2/files/list_folder/continue", { cursor: cursor }))
      else
        listing_from_folder(@transport.post_json("/2/files/list_folder", { path: normalize_folder_path(path) }))
      end
    end

    def search(query:, path: "", cursor: nil)
      if cursor
        listing_from_search(@transport.post_json("/2/files/search/continue_v2", { cursor: cursor }))
      else
        listing_from_search(
          @transport.post_json(
            "/2/files/search_v2",
            { query: query, options: { path: normalize_folder_path(path) } }
          )
        )
      end
    end

    def metadata(path:)
      Entry.from_api(@transport.post_json("/2/files/get_metadata", { path: normalize_entry_path(path) }))
    end

    def download(path:)
      normalized = normalize_entry_path(path)
      response = @transport.post_content("/2/files/download", arg: { path: normalized })
      DownloadedFile.new(bytes: response.body.to_s, entry: entry_from_download(response, normalized))
    end

    def upload(path:, content:, chunk_size: SIMPLE_UPLOAD_MAX_BYTES)
      Upload.new(transport: @transport).call(
        path: normalize_entry_path(path),
        io: content_io(content),
        chunk_size: chunk_size
      )
    end

    private

    def listing_from_folder(body)
      Listing.new(
        entries: Array(body["entries"]).map { |entry| Entry.from_api(entry) },
        cursor: body["cursor"],
        has_more: body["has_more"] == true,
        kind: :folder
      )
    end

    def listing_from_search(body)
      entries = Array(body["matches"]).map { |match| Entry.from_api(match) }
      Listing.new(
        entries: entries,
        cursor: body["cursor"],
        has_more: body["has_more"] == true,
        kind: :search
      )
    end

    def entry_from_download(response, path)
      result = response["Dropbox-API-Result"]
      return Entry.from_api(parse_json(result)) if result

      Entry.from_api("id" => nil, "name" => File.basename(path), "path_display" => path, ".tag" => "file")
    end

    def content_io(content)
      return StringIO.new(content.b) if content.is_a?(String)

      content.binmode if content.respond_to?(:binmode)
      content
    end

    def normalize_folder_path(path)
      raw = path.to_s
      return "" if raw.empty? || raw == "/"

      raw.start_with?("/") ? raw : "/#{raw}"
    end

    def normalize_entry_path(path)
      raw = path.to_s.strip
      raise Error, "Dropbox path is required" if raw.empty?

      return raw if raw.start_with?("id:") || raw.start_with?("/")

      "/#{raw}"
    end

    def parse_json(raw)
      text = raw.to_s
      return {} if text.strip.empty?

      JSON.parse(text)
    rescue JSON::ParserError
      {}
    end
  end
end
