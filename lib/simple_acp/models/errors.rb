# frozen_string_literal: true

module SimpleAcp
  module Models
    # Error codes as defined in the ACP specification
    module ErrorCode
      SERVER_ERROR = "server_error"
      INVALID_INPUT = "invalid_input"
      NOT_FOUND = "not_found"
    end

    # Structured error response following ACP spec
    class Error
      attr_reader :code, :message, :data

      def initialize(code:, message:, data: nil)
        @code = code
        @message = message
        @data = data
      end

      def to_h
        hash = {
          code: @code,
          message: @message
        }
        hash[:data] = @data if @data
        hash
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      def self.from_hash(hash)
        new(
          code: hash["code"] || hash[:code],
          message: hash["message"] || hash[:message],
          data: hash["data"] || hash[:data]
        )
      end

      def self.server_error(message, data: nil)
        new(code: ErrorCode::SERVER_ERROR, message: message, data: data)
      end

      def self.invalid_input(message, data: nil)
        new(code: ErrorCode::INVALID_INPUT, message: message, data: data)
      end

      def self.not_found(message, data: nil)
        new(code: ErrorCode::NOT_FOUND, message: message, data: data)
      end
    end
  end
end
