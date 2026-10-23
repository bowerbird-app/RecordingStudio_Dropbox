# frozen_string_literal: true

require "marcel"

module RecordingStudioDropbox
  module Attachable
    module ImportsSupport
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
        client = dropbox_client
        cursor = params[:page_token]
        page_size = dropbox_configuration.page_size
        if @query.present?
          client.search(query: @query, cursor: cursor, page_size: page_size)
        else
          client.list(cursor: cursor, page_size: page_size)
        end
      end

      def listed_files(page)
        Array(page.entries).filter_map do |file|
          next if file.respond_to?(:folder?) && file.folder?

          {
            "id" => file.id,
            "name" => file.name,
            "mimeType" => Marcel::MimeType.for(name: file.name.to_s)
          }
        end
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

      def import_result
        Import.remote_files(
          parent_recording: @recording,
          attachments: Array(params[:file_ids]),
          actor: current_attachable_actor,
          impersonator: current_attachable_impersonator
        )
      end

      def respond_to_import(result)
        respond_to do |format|
          if result.success?
            format.json { render json: { redirect_path: resolved_attachment_redirect_path(@recording) }, status: :created }
            format.html { respond_to_successful_html_import(result) }
          else
            format.json { render json: { error: result.error }, status: :unprocessable_content }
            format.html do
              redirect_to recording_imports_path(@recording, **upload_flow_params), alert: result.error
            end
          end
        end
      end

      def respond_to_successful_html_import(result)
        if embedded_upload_provider_request?
          render_upload_provider_modal_event(
            type: "provider-import-complete",
            provider_key: "dropbox",
            modal_id: current_upload_provider_modal_id,
            redirect_path: resolved_attachment_redirect_path(@recording)
          )
        else
          redirect_to resolved_attachment_redirect_path(@recording),
                      notice: RecordingStudioAttachable::Copy.t(
                        "providers.imported_count",
                        count: result.value.size,
                        default: "Imported #{result.value.size} files."
                      )
        end
      end

      def respond_to_dependency_unavailable(error)
        respond_to do |format|
          format.json { render json: { error: error.message }, status: :unprocessable_content }
          format.html { dependency_unavailable_alert(error) }
        end
      end

      def handle_index_error(error)
        return render_disconnected(reconnect: true) if Integration.reconnect_required?(error)
        raise unless Integration.request_error?(error)

        @query = params[:query].to_s.strip
        @files = []
        @next_page_url = nil
        flash.now[:alert] = error.message
        render :index, status: :bad_gateway
      end

      def handle_create_error(error)
        return respond_to_reconnect_error if Integration.reconnect_required?(error)
        raise unless Integration.request_error?(error)

        respond_to do |format|
          format.json { render json: { error: error.message }, status: :unprocessable_content }
          format.html do
            redirect_to recording_imports_path(@recording, **upload_flow_params), alert: error.message
          end
        end
      end

      def respond_to_reconnect_error
        message = RecordingStudioAttachable::Copy.t(
          "providers.reconnect_to_continue",
          provider: provider_label,
          default: "Reconnect #{provider_label} to continue"
        )
        payload = provider_connect_payload(
          needs_auth: true,
          reconnect: true,
          import_url: recording_imports_path(@recording, format: :json, **attachment_redirect_params)
        )
        respond_to do |format|
          format.json { render json: payload.merge(error: message), status: :unauthorized }
          format.html { render_disconnected(reconnect: true) }
        end
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
