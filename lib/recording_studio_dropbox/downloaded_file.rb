# frozen_string_literal: true

module RecordingStudioDropbox
  class DownloadedFile
    attr_reader :bytes, :entry

    def initialize(bytes:, entry:)
      @bytes = bytes
      @entry = entry
    end

    def name
      entry.name
    end

    def id
      entry.id
    end
  end
end
