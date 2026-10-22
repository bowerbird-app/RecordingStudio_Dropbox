# frozen_string_literal: true

module RecordingStudioDropbox
  class Page
    attr_reader :entries, :next_cursor

    def initialize(entries:, next_cursor:)
      @entries = entries
      @next_cursor = next_cursor
    end

    def more?
      !next_cursor.nil?
    end
  end
end
