# frozen_string_literal: true

require_relative "descriptions"

module RecordingStudioDropbox
  module Api
    module Endpoints
      OPENAPI_TAGS = ["Dropbox"].freeze
      EXCLUDED_NAMES = %w[
        dropbox.download dropbox.fetch_file dropbox.upload_file dropbox.connect
        dropbox.disconnect dropbox.bootstrap dropbox.register_oauth_provider
      ].freeze

      def self.openapi(title, description)
        { title: title, summary: title, description: description, tags: OPENAPI_TAGS }
      end

      DEFINITIONS = [
        {
          name: :"dropbox.import", http_verb: :post, path: "dropbox/import", handler: Import,
          openapi: openapi("Import from Dropbox", Descriptions::IMPORT),
          input_contract: {
            reject_unknown: true,
            fields: {
              recording_id: Descriptions::IMPORT_RECORDING_ID,
              attachments: Descriptions::ATTACHMENTS
            }
          }
        },
        {
          name: :"dropbox.list", http_verb: :get, path: "dropbox/list", handler: List,
          openapi: openapi("List Dropbox files", Descriptions::LIST),
          input_contract: {
            reject_unknown: true,
            fields: {
              recording_id: Descriptions::LIST_RECORDING_ID,
              path: Descriptions::PATH,
              cursor: Descriptions::CURSOR,
              page_size: Descriptions::PAGE_SIZE
            }
          }
        },
        {
          name: :"dropbox.search", http_verb: :get, path: "dropbox/search", handler: Search,
          openapi: openapi("Search Dropbox", Descriptions::SEARCH),
          input_contract: {
            reject_unknown: true,
            fields: {
              recording_id: Descriptions::LIST_RECORDING_ID,
              query: Descriptions::QUERY,
              cursor: Descriptions::CURSOR,
              page_size: Descriptions::PAGE_SIZE
            }
          }
        }
      ].freeze
    end
  end
end
