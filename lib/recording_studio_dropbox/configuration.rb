# frozen_string_literal: true

module RecordingStudioDropbox
  class Configuration
    attr_reader :hooks

    def initialize
      @hooks = RecordingStudio::Hooks.new
    end

    def to_h
      { hooks: hooks.class.name }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |k, v|
        setter = "#{k}="
        public_send(setter, v) if respond_to?(setter)
      end
    end
  end
end
