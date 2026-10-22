# frozen_string_literal: true

module RecordingStudioDropbox
  class UploadedFile
    attr_reader :entry

    def initialize(entry:)
      @entry = entry
    end

    def id
      entry.id
    end

    def name
      entry.name
    end

    def path
      entry.path
    end
  end
end
