# frozen_string_literal: true

module RecordingStudioDropbox
  module Api
    class Search
      def self.call(context)
        Errors.wrap { new(context).call }
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = Access.recording_for!(context)
        page = Access.client_for(context, recording: recording).search(
          query: context.params[:query],
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
