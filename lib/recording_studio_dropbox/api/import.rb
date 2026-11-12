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
          attachments: file_ids,
          actor: Access.actor_for(context),
          impersonator: impersonator
        )
        raise RecordingStudioApi::InvalidActionInputError, result.error unless result.success?

        { attachments: Array(result.value).map { |imported| imported_as_json(imported) } }
      end

      private

      attr_reader :context

      def file_ids
        Array(context.params[:attachments]).filter_map { |item| file_id(item) }
      end

      def file_id(item)
        return item.presence if item.is_a?(String)
        return unless item.is_a?(Hash)

        item[:id].presence || item["id"].presence
      end

      def impersonator
        context.authorized_by
      end

      def imported_as_json(recording)
        attachment = recording.recordable
        {
          id: recording.id,
          name: attachment&.name,
          kind: attachment&.attachment_kind
        }
      end
    end
  end
end
