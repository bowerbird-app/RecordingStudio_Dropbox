# frozen_string_literal: true

module RecordingStudioDropbox
  module Api
    module Page
      module_function

      def as_json(page)
        {
          entries: Array(page.entries).map { |entry| entry_as_json(entry) },
          next_cursor: page.next_cursor
        }
      end

      def entry_as_json(entry)
        {
          id: entry.id,
          name: entry.name,
          path: entry.path,
          folder: entry.folder?,
          size: entry.size
        }
      end
    end
  end
end
