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
        assign_listing_path
        page = dropbox_listing_page
        @files = listed_files(page)
        @next_page_url = next_page_url_for(page)
      end

      def assign_listing_path
        @path = params[:path].to_s
        @query = params[:query].to_s.strip
        @current_path = @path.presence || "/"
        @parent_url = parent_folder_url
      end

      def dropbox_listing_page
        cursor = params[:page_token]
        page_size = dropbox_configuration.page_size
        if @query.present?
          dropbox_client.search(query: @query, cursor: cursor, page_size: page_size)
        else
          dropbox_client.list(path: @path, cursor: cursor, page_size: page_size)
        end
      end

      def listed_files(page)
        Array(page.entries).filter_map { |file| listed_file(file) }
      end

      def listed_file(file)
        return listed_folder(file) if file.respond_to?(:folder?) && file.folder?
        return if file.respond_to?(:file?) && !file.file?

        {
          "id" => file.id,
          "name" => file.name,
          "kind" => :file,
          "content_type" => Marcel::MimeType.for(name: file.name.to_s)
        }
      end

      def listed_folder(file)
        locator = file.path.presence || file.id
        {
          "id" => file.id,
          "name" => file.name,
          "kind" => :folder,
          "open_url" => recording_imports_path(@recording, **upload_flow_params, path: locator)
        }
      end

      def parent_folder_url
        return if @path.blank? || @path == "/"

        recording_imports_path(@recording, **upload_flow_params, path: parent_folder_path)
      end

      def parent_folder_path
        parent = File.dirname(@path)
        return if parent.blank? || parent == "." || parent == "/"

        parent
      end

      def next_page_url_for(page)
        return if page.next_cursor.blank?

        recording_imports_path(
          @recording,
          query: @query.presence,
          page_token: page.next_cursor,
          path: @path.presence,
          **upload_flow_params
        )
      end

      def render_disconnected(reconnect: dropbox_reconnect?)
        assign_listing_path
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
