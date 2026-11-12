# frozen_string_literal: true

module RecordingStudioDropbox
  module Api
    class Import
      def self.call(context)
        Errors.wrap { new(context).call }
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = Access.recording_for!(context)
        result = RecordingStudioDropbox::Attachable::Import.remote_files(
          parent_recording: recording,
          attachments: context.params[:attachments],
          actor: Access.actor_for(context),
          impersonator: impersonator
        )
        raise RecordingStudioApi::InvalidActionInputError, result.error unless result.success?

        { attachments: Array(result.value).map { |imported| imported_as_json(imported) } }
      end

      private

      attr_reader :context

      def impersonator
        context.authorized_by if context.respond_to?(:authorized_by)
      end

      def imported_as_json(recording)
        attachment = recording.recordable
        {
          id: recording.id,
          name: attachment.respond_to?(:name) ? attachment.name : nil,
          kind: attachment.respond_to?(:attachment_kind) ? attachment.attachment_kind : nil
        }
      end
    end
  end
end
