# frozen_string_literal: true

module RecordingStudioDropbox
  Page = Data.define(:entries, :next_cursor) do
    def more?
      !(next_cursor.nil? || next_cursor.empty?)
    end
  end
end
