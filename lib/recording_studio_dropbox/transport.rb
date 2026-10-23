# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "timeout"
require "uri"

module RecordingStudioDropbox
  class Transport
    API_HOST = "api.dropboxapi.com"
    CONTENT_HOST = "content.dropboxapi.com"
    RECONNECT_CODES = %w[invalid_grant expired_access_token invalid_access_token missing_scope].freeze
    TLS_START_OPTIONS = {
      use_ssl: true,
      open_timeout: 10,
      read_timeout: 30,
      ssl_timeout: 10,
      write_timeout: 30
    }.freeze

    def self.parse_json(raw)
      JSON.parse(raw.to_s)
    rescue JSON::ParserError
      raise RequestError, "Dropbox returned invalid JSON"
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

    def post_content(path, arg:, body: nil, max_bytes: nil)
      uri = URI("https://#{CONTENT_HOST}#{path}")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = bearer
      request["Dropbox-API-Arg"] = encode_api_arg(arg)
      request["Content-Type"] = "application/octet-stream"
      request.body = body unless body.nil?
      response = perform(uri, request, max_bytes: max_bytes)
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

    def perform(uri, request, max_bytes: nil)
      Net::HTTP.start(uri.host, uri.port, **TLS_START_OPTIONS) do |http|
        next http.request(request) if max_bytes.nil?

        stream_request(http, request, max_bytes)
      end
    rescue SystemCallError, IOError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError, Net::ProtocolError
      raise RequestError, "Dropbox request failed"
    end

    def stream_request(http, request, max_bytes)
      streamed = nil
      http.request(request) do |response|
        streamed = read_limited_response(response, max_bytes)
      end
      streamed
    end

    def read_limited_response(response, max_bytes)
      return response.tap(&:body) unless success?(response)

      limited = LimitedBody.new(max_bytes)
      response.read_body { |chunk| limited.append(chunk) }
      response.define_singleton_method(:body) { limited.to_s }
      response
    end

    def parse_json_response(response)
      raise_for_failure!(response) unless success?(response)

      self.class.parse_json(response.body)
    end

    def raise_for_failure!(response)
      parsed = parse_error_body(response.body)
      code = error_code(parsed)
      status = response.code.to_i
      raise ReconnectRequired, "Dropbox access token is no longer valid" if reconnect?(status, code)

      raise RequestError.new(error_summary_message(parsed), status: status, code: code)
    end

    def parse_error_body(raw)
      JSON.parse(raw.to_s)
    rescue JSON::ParserError
      {}
    end

    def error_summary_message(parsed)
      summary = parsed["error_summary"].to_s
      return summary unless summary.empty?

      "Dropbox request failed"
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
