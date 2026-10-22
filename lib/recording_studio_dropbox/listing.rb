# frozen_string_literal: true

module RecordingStudioDropbox
  class Listing
    attr_reader :entries, :cursor, :has_more, :kind

    def initialize(entries:, cursor:, has_more:, kind:)
      @entries = entries
      @cursor = cursor
      @has_more = has_more
      @kind = kind
    end
  end
end
