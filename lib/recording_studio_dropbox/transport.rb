# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module RecordingStudioDropbox
  class Transport
    API_HOST = "api.dropboxapi.com"
    CONTENT_HOST = "content.dropboxapi.com"
    ALLOWED_HOSTS = [API_HOST, CONTENT_HOST].freeze
    RECONNECT_TAGS = %w[expired_access_token invalid_access_token missing_scope].freeze
    RECONNECT_ERROR_CODES = %w[invalid_token expired_token].freeze
    TLS_START_OPTIONS = {
      use_ssl: true,
      open_timeout: 10,
      read_timeout: 30,
      ssl_timeout: 10,
      write_timeout: 30
    }.freeze

    def initialize(token_provider:)
      @token_provider = TokenProvider.wrap(token_provider)
    end

    def post_json(path, payload)
      uri = URI("https://#{API_HOST}#{path}")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = bearer
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
      parse_json_response(perform(uri, request))
    end

    def post_content(path, arg:, body: nil)
      uri = URI("https://#{CONTENT_HOST}#{path}")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = bearer
      request["Dropbox-API-Arg"] = JSON.generate(arg)
      request["Content-Type"] = "application/octet-stream"
      request.body = body unless body.nil?
      response = perform(uri, request)
      raise_for_failure!(response) unless success?(response)

      response
    end

    private

    def bearer
      "Bearer #{@token_provider.access_token}"
    end

    def perform(uri, request)
      raise Error, "Refusing Dropbox request to #{uri.host}" unless ALLOWED_HOSTS.include?(uri.host)

      Net::HTTP.start(uri.host, uri.port, **TLS_START_OPTIONS) do |http|
        http.request(request)
      end
    end

    def parse_json_response(response)
      body = parse_json(response.body)
      raise_for_failure!(response, body) unless success?(response)

      body
    end

    def raise_for_failure!(response, body = nil)
      parsed = body || parse_json(response.body)
      tag = error_tag(parsed)
      status = response.code.to_i
      raise ReconnectRequired if reconnect?(status, tag, parsed)

      raise ApiError.new(api_error_message(status, tag, parsed), status: status, tag: tag)
    end

    def reconnect?(status, tag, parsed)
      return true if status == 401
      return true if RECONNECT_TAGS.include?(tag)

      error = parsed["error"]
      error.is_a?(String) && RECONNECT_ERROR_CODES.include?(error)
    end

    def error_tag(parsed)
      error = parsed["error"]
      return error[".tag"] if error.is_a?(Hash)

      nil
    end

    def api_error_message(status, tag, parsed)
      tag || parsed["error_summary"] || "Dropbox request failed (HTTP #{status})"
    end

    def success?(response)
      response.is_a?(Net::HTTPSuccess)
    end

    def parse_json(raw)
      text = raw.to_s
      return {} if text.strip.empty?

      JSON.parse(text)
    rescue JSON::ParserError
      {}
    end
  end
end
