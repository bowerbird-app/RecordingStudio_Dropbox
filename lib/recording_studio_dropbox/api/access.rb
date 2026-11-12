# frozen_string_literal: true

module RecordingStudioDropbox
  module Api
    module Access
      DENIED_MESSAGE = "API access grant is not authorized for this capability"

      module_function

      def authorized?(context, recording:)
        actor = actor_for(context)
        return false if actor.blank? || recording.blank?
        return false unless defined?(RecordingStudioAttachable::Authorization)

        RecordingStudioAttachable::Authorization.allowed?(
          action: :upload,
          actor: actor,
          recording: recording
        )
      end

      def api_authorize
        method(:authorized?)
      end

      def authorize!(context, recording:)
        return if authorized?(context, recording: recording)

        raise RecordingStudioApi::AuthorizationError, DENIED_MESSAGE
      end

      def recording_for!(context)
        recording_id = context.params[:recording_id].to_s.presence
        raise RecordingStudioApi::InvalidActionInputError, "recording_id is required" if recording_id.blank?

        recording = RecordingStudio::Recording.find_by(id: recording_id)
        raise RecordingStudioApi::NotFoundError, "Recording was not found" if recording.blank?

        authorize!(context, recording: recording)
        recording
      end

      def actor_for(context)
        context&.access_grant&.actor
      end

      def client_for(context, recording:)
        RecordingStudioDropbox::Attachable::Registration.client(
          root: RecordingStudioDropbox::Attachable::Registration.root_for(recording),
          actor: actor_for(context)
        )
      end
    end
  end
end
