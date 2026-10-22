# frozen_string_literal: true

module RecordingStudioDropbox
  class Entry
    attr_reader :id, :name, :path, :tag, :size, :rev, :client_modified

    def self.from_api(hash)
      metadata = unwrap(hash)
      new(
        id: metadata["id"],
        name: metadata["name"],
        path: metadata["path_display"] || metadata["path_lower"],
        tag: metadata[".tag"],
        size: metadata["size"],
        rev: metadata["rev"],
        client_modified: metadata["client_modified"]
      )
    end

    def initialize(**attributes)
      @id = attributes[:id]
      @name = attributes[:name]
      @path = attributes[:path]
      @tag = attributes[:tag]
      @size = attributes[:size]
      @rev = attributes[:rev]
      @client_modified = attributes[:client_modified]
    end

    def folder?
      tag == "folder"
    end

    def file?
      tag == "file"
    end

    def self.unwrap(hash)
      return {} unless hash.is_a?(Hash)

      inner = hash["metadata"]
      return unwrap(inner) if inner.is_a?(Hash)

      hash
    end
    private_class_method :unwrap
  end
end
