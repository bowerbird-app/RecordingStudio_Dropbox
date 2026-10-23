# frozen_string_literal: true

require "marcel"

module RecordingStudioDropbox
  module Attachable
    module ImportsListing
      private

      def render_index_page
        return render_disconnected unless dropbox_connected?

        load_dropbox_page
        render :index
      end

      def load_dropbox_page
        @query = params[:query].to_s.strip
        page = dropbox_listing_page
        @files = listed_files(page)
        @next_page_url = next_page_url_for(page)
      end

      def dropbox_listing_page
        cursor = params[:page_token]
        page_size = dropbox_configuration.page_size
        if @query.present?
          dropbox_client.search(query: @query, cursor: cursor, page_size: page_size)
        else
          dropbox_client.list(cursor: cursor, page_size: page_size)
        end
      end

      def listed_files(page)
        Array(page.entries).filter_map { |file| listed_file(file) }
      end

      def listed_file(file)
        return if file.respond_to?(:folder?) && file.folder?

        {
          "id" => file.id,
          "name" => file.name,
          "mimeType" => Marcel::MimeType.for(name: file.name.to_s)
        }
      end

      def next_page_url_for(page)
        return if page.next_cursor.blank?

        recording_imports_path(
          @recording,
          query: @query.presence,
          page_token: page.next_cursor,
          **upload_flow_params
        )
      end

      def render_disconnected(reconnect: dropbox_reconnect?)
        @query = params[:query].to_s.strip
        @files = []
        @next_page_url = nil
        @show_connect = true
        @reconnect = reconnect
        @oauth_connect_path = oauth_connect_path
        @oauth_return_to = oauth_return_to(popup: embedded_upload_provider_request?)
        render :index
      end
    end
  end
end
