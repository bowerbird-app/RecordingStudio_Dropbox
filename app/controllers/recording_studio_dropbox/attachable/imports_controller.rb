# frozen_string_literal: true

require "marcel"

module RecordingStudioDropbox
  module Attachable
    class ImportsController < ApplicationController
      include ImportsSupport

      def index
        authorize_provider_upload!
        ensure_provider_available!
        render_index_page
      rescue RecordingStudioAttachable::DependencyUnavailableError => e
        dependency_unavailable_alert(e)
      rescue RecordingStudioDropbox::ReconnectRequired, RecordingStudioAttachable::ReconnectRequired,
             RecordingStudioDropbox::RequestError => e
        handle_index_error(e)
      end

      def create
        authorize_provider_upload!
        ensure_provider_available!
        respond_to_import(import_result)
      rescue RecordingStudioAttachable::DependencyUnavailableError => e
        respond_to_dependency_unavailable(e)
      rescue RecordingStudioDropbox::ReconnectRequired, RecordingStudioAttachable::ReconnectRequired,
             RecordingStudioDropbox::RequestError => e
        handle_create_error(e)
      end
    end
  end
end
