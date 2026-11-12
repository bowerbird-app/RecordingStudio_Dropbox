# frozen_string_literal: true

module RecordingStudioDropbox
  module Api
    module Endpoints
      OPENAPI_TAGS = ["Dropbox"].freeze
      EXCLUDED_NAMES = %w[
        dropbox.download dropbox.fetch_file dropbox.upload_file dropbox.connect
        dropbox.disconnect dropbox.bootstrap dropbox.register_oauth_provider
      ].freeze
      RECORDING_ID = {
        type: :string, required: true, allow_blank: false,
        description: "Recording whose workspace Dropbox this call uses."
      }.freeze
      CURSOR = {
        type: :string, required: false, allow_blank: true,
        description: "Next page from a previous next_cursor."
      }.freeze
      PAGE_SIZE = {
        type: :integer, required: false,
        description: "How many entries to return. Defaults to the gem page_size."
      }.freeze

      def self.openapi(name, description)
        { title: "Dropbox - #{name}", summary: "Dropbox - #{name}", description: description, tags: OPENAPI_TAGS }
      end

      DEFINITIONS = [
        {
          name: :"dropbox.import", http_verb: :post, path: "dropbox/import", handler: Import,
          openapi: openapi(
            "Import",
            "Copy selected Dropbox files onto a recording. Same access as the Dropbox picker."
          ),
          input_contract: {
            reject_unknown: true,
            fields: {
              recording_id: RECORDING_ID,
              attachments: {
                type: :array, required: true, description: "Files to import. Each item needs a Dropbox id."
              }
            }
          }
        },
        {
          name: :"dropbox.list", http_verb: :get, path: "dropbox/list", handler: List,
          openapi: openapi("List", "List files and folders in the workspace Dropbox. Same listing the picker uses."),
          input_contract: {
            reject_unknown: true,
            fields: {
              recording_id: RECORDING_ID,
              path: {
                type: :string, required: false, allow_blank: true,
                description: "Folder path. Blank lists the root."
              },
              cursor: CURSOR, page_size: PAGE_SIZE
            }
          }
        },
        {
          name: :"dropbox.search", http_verb: :get, path: "dropbox/search", handler: Search,
          openapi: openapi("Search", "Search files in the workspace Dropbox. Same search the picker uses."),
          input_contract: {
            reject_unknown: true,
            fields: {
              recording_id: RECORDING_ID,
              query: { type: :string, required: true, allow_blank: false, description: "Text to search for." },
              cursor: CURSOR, page_size: PAGE_SIZE
            }
          }
        }
      ].freeze
    end
  end
end
