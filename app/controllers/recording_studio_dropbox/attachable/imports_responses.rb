# frozen_string_literal: true

module RecordingStudioDropbox
  module Attachable
    module ImportsResponses
      private

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
            format.json { render json: created_import_payload, status: :created }
            format.html { respond_to_successful_html_import(result) }
          else
            format.json { render json: { error: result.error }, status: :unprocessable_content }
            format.html { redirect_to recording_imports_path(@recording, **upload_flow_params), alert: result.error }
          end
        end
      end

      def created_import_payload
        { redirect_path: resolved_attachment_redirect_path(@recording) }
      end

      def respond_to_successful_html_import(result)
        path = resolved_attachment_redirect_path(@recording)
        return render_embedded_import(path) if embedded_upload_provider_request?

        redirect_to path, notice: imported_notice(result)
      end

      def render_embedded_import(path)
        render_upload_provider_modal_event(
          type: "provider-import-complete",
          provider_key: "dropbox",
          modal_id: current_upload_provider_modal_id,
          redirect_path: path
        )
      end

      def imported_notice(result)
        I18n.t(
          "recording_studio_dropbox.imported_count",
          count: result.value.size,
          default: "Imported #{result.value.size} files."
        )
      end

      def respond_to_dependency_unavailable(error)
        respond_to do |format|
          format.json { render json: { error: error.message }, status: :unprocessable_content }
          format.html { dependency_unavailable_alert(error) }
        end
      end

      def handle_index_error(error)
        return render_disconnected(reconnect: true) if Registration.reconnect_required?(error)
        raise unless Registration.request_error?(error)

        render_listing_error(error)
      end

      def render_listing_error(error)
        assign_listing_path
        @files = []
        @next_page_url = nil
        flash.now[:alert] = error.message
        render :index, status: :bad_gateway
      end

      def handle_create_error(error)
        return respond_to_reconnect_error if Registration.reconnect_required?(error)
        raise unless Registration.request_error?(error)

        respond_to do |format|
          format.json { render json: { error: error.message }, status: :unprocessable_content }
          format.html { redirect_to recording_imports_path(@recording, **upload_flow_params), alert: error.message }
        end
      end

      def respond_to_reconnect_error
        respond_to do |format|
          format.json { render json: reconnect_json_payload, status: :unauthorized }
          format.html { render_disconnected(reconnect: true) }
        end
      end

      def reconnect_json_payload
        message = I18n.t(
          "recording_studio_dropbox.reconnect_to_continue",
          default: "Reconnect #{provider_label} to continue"
        )
        provider_connect_payload(
          needs_auth: true,
          reconnect: true,
          import_url: recording_imports_path(@recording, format: :json, **attachment_redirect_params)
        ).merge(error: message)
      end
    end
  end
end
