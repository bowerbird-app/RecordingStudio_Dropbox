# frozen_string_literal: true

module RecordingStudioDropbox
  Page = Data.define(:entries, :next_cursor) do
    def more?
      !next_cursor.to_s.empty?
    end
  end
end
