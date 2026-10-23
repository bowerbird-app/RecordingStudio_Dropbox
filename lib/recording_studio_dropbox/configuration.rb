# frozen_string_literal: true

module RecordingStudioDropbox
  class Configuration
    PLACEHOLDER_CLIENT_IDS = ["dummy-dropbox-client-id"].freeze
    DEFAULT_SCOPES = %w[files.metadata.read files.content.read].freeze

    attr_reader :hooks
    attr_accessor :enabled, :client_id, :page_size, :scopes

    def initialize
      @hooks = RecordingStudio::Hooks.new
      @enabled = false
      @client_id = nil
      @page_size = 25
      @scopes = DEFAULT_SCOPES.dup
    end

    def enabled?
      !!enabled
    end

    def chooser_configured?
      normalized = client_id.to_s.strip
      normalized.present? && PLACEHOLDER_CLIENT_IDS.exclude?(normalized)
    end

    def available?
      enabled? && chooser_configured?
    end
  end
end
