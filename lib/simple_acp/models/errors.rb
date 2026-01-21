# frozen_string_literal: true

module SimpleAcp
  module Models
    # Error codes as defined in the ACP specification.
    module ErrorCode
      # Internal server error
      SERVER_ERROR = "server_error"
      # Invalid input from client
      INVALID_INPUT = "invalid_input"
      # Requested resource not found
      NOT_FOUND = "not_found"
    end

    # Structured error response following the ACP specification.
    #
    # @example Creating an error
    #   error = Error.server_error("Something went wrong")
    #   error.code    # => "server_error"
    #   error.message # => "Something went wrong"
    class Error
      # @return [String] error code (server_error, invalid_input, not_found)
      attr_reader :code

      # @return [String] human-readable error message
      attr_reader :message

      # @return [Object, nil] additional error data
      attr_reader :data

      # Create a new error.
      #
      # @param code [String] error code
      # @param message [String] error message
      # @param data [Object, nil] additional data
      def initialize(code:, message:, data: nil)
        @code = code
        @message = message
        @data = data
      end

      # Convert to hash for JSON serialization.
      #
      # @return [Hash] error as hash
      def to_h
        hash = {
          code: @code,
          message: @message
        }
        hash[:data] = @data if @data
        hash
      end

      # Convert to JSON string.
      #
      # @param args [Array] arguments passed to Hash#to_json
      # @return [String] JSON representation
      def to_json(*args)
        to_h.to_json(*args)
      end

      # Create from a hash (JSON deserialization).
      #
      # @param hash [Hash] error data
      # @return [Error] the error
      def self.from_hash(hash)
        new(
          code: hash["code"] || hash[:code],
          message: hash["message"] || hash[:message],
          data: hash["data"] || hash[:data]
        )
      end

      # Create a server error.
      #
      # @param message [String] error message
      # @param data [Object, nil] additional data
      # @return [Error] the error
      def self.server_error(message, data: nil)
        new(code: ErrorCode::SERVER_ERROR, message: message, data: data)
      end

      # Create an invalid input error.
      #
      # @param message [String] error message
      # @param data [Object, nil] additional data
      # @return [Error] the error
      def self.invalid_input(message, data: nil)
        new(code: ErrorCode::INVALID_INPUT, message: message, data: data)
      end

      # Create a not found error.
      #
      # @param message [String] error message
      # @param data [Object, nil] additional data
      # @return [Error] the error
      def self.not_found(message, data: nil)
        new(code: ErrorCode::NOT_FOUND, message: message, data: data)
      end
    end
  end
end
