# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module RecordingStudioDropbox
  class Transport
    API_HOST = "api.dropboxapi.com"
    CONTENT_HOST = "content.dropboxapi.com"
    ALLOWED_HOSTS = [API_HOST, CONTENT_HOST].freeze
    RECONNECT_CODES = %w[invalid_grant expired_access_token invalid_access_token missing_scope].freeze
    TLS_START_OPTIONS = {
      use_ssl: true,
      open_timeout: 10,
      read_timeout: 30,
      ssl_timeout: 10,
      write_timeout: 30
    }.freeze

    def self.parse_json(raw)
      text = raw.to_s
      return {} if text.strip.empty?

      JSON.parse(text)
    rescue JSON::ParserError
      {}
    end

    def initialize(token_provider:)
      @access_token = AccessToken.new(token_provider)
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
      request["Dropbox-API-Arg"] = encode_api_arg(arg)
      request["Content-Type"] = "application/octet-stream"
      request.body = body unless body.nil?
      response = perform(uri, request)
      raise_for_failure!(response) unless success?(response)

      response
    end

    private

    def bearer
      "Bearer #{@access_token}"
    end

    def encode_api_arg(arg)
      JSON.generate(arg, ascii_only: true).gsub("\u007F", '\u007f')
    end

    def perform(uri, request)
      raise Error, "Refusing Dropbox request to #{uri.host}" unless ALLOWED_HOSTS.include?(uri.host)

      Net::HTTP.start(uri.host, uri.port, **TLS_START_OPTIONS) do |http|
        http.request(request)
      end
    end

    def parse_json_response(response)
      body = self.class.parse_json(response.body)
      raise_for_failure!(response, body) unless success?(response)

      body
    end

    def raise_for_failure!(response, body = nil)
      parsed = body || self.class.parse_json(response.body)
      code = error_code(parsed)
      status = response.code.to_i
      raise ReconnectRequired if reconnect?(status, code)

      raise RequestError.new(status: status, code: code)
    end

    def reconnect?(status, code)
      status == 401 || RECONNECT_CODES.include?(code)
    end

    def error_code(parsed)
      error = parsed["error"]
      return error[".tag"] if error.is_a?(Hash)
      return error if error.is_a?(String)

      nil
    end

    def success?(response)
      response.is_a?(Net::HTTPSuccess)
    end
  end
end
