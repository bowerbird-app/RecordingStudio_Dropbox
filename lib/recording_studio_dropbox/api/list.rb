# frozen_string_literal: true

module RecordingStudioDropbox
  module Api
    class List
      def self.call(context)
        Errors.wrap { new(context).call }
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = Access.recording_for!(context)
        page = Access.client_for(context, recording: recording).list(
          path: context.params[:path].to_s,
          cursor: context.params[:cursor],
          page_size: page_size
        )
        Page.as_json(page)
      end

      private

      attr_reader :context

      def page_size
        context.params[:page_size].presence || RecordingStudioDropbox.configuration.page_size
      end
    end
  end
end
