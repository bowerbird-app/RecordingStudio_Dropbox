# frozen_string_literal: true

module RecordingStudioDropbox
  class Configuration
    attr_reader :hooks

    def initialize
      @hooks = RecordingStudio::Hooks.new
    end
  end
end
