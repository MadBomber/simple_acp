# frozen_string_literal: true

require "json"
require "time"
require "securerandom"
require "concurrent"

require_relative "simple_acp/version"

# Models
require_relative "simple_acp/models/errors"
require_relative "simple_acp/models/types"
require_relative "simple_acp/models/base"
require_relative "simple_acp/models/metadata"
require_relative "simple_acp/models/message_part"
require_relative "simple_acp/models/message"
require_relative "simple_acp/models/run"
require_relative "simple_acp/models/agent_manifest"
require_relative "simple_acp/models/session"
require_relative "simple_acp/models/events"
require_relative "simple_acp/models/await"

# Storage
require_relative "simple_acp/storage/base"
require_relative "simple_acp/storage/memory"

# Server
require_relative "simple_acp/server/context"
require_relative "simple_acp/server/agent"
require_relative "simple_acp/server/app"
require_relative "simple_acp/server/base"

# Client
require_relative "simple_acp/client/sse"
require_relative "simple_acp/client/base"

# Ruby implementation of the Agent Communication Protocol (ACP).
# Provides server and client implementations for AI agent communication
# with support for synchronous, asynchronous, and streaming execution modes.
#
# @example Creating a server
#   server = SimpleAcp::Server::Base.new
#   server.agent("echo", description: "Echoes input") do |context|
#     SimpleAcp::Models::Message.agent(context.input.first.text_content)
#   end
#   server.run(port: 8000)
#
# @example Using the client
#   client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")
#   run = client.run_sync(agent: "echo", input: "Hello!")
#   puts run.output.first.text_content
#
# @see https://github.com/i-am-bee/acp Agent Communication Protocol specification
module SimpleAcp
  # Base error class for all SimpleAcp exceptions
  class Error < StandardError; end

  # Raised when there is a configuration problem
  class ConfigurationError < Error; end

  # Raised when input validation fails
  class ValidationError < Error; end

  # Raised when a requested resource is not found
  class NotFoundError < Error; end

  # Raised when a run fails during execution
  class RunError < Error; end

  class << self
    # @return [Logger, nil] optional logger for debugging
    attr_accessor :logger

    # Configure the SimpleAcp module
    #
    # @yield [self] yields self for configuration
    # @return [void]
    #
    # @example
    #   SimpleAcp.configure do |config|
    #     config.logger = Logger.new(STDOUT)
    #   end
    def configure
      yield self if block_given?
    end
  end
end

# Convenience top-level aliases (outside the SimpleAcp module to avoid constant conflicts)
SimpleAcpServer = SimpleAcp::Server::Base
SimpleAcpClient = SimpleAcp::Client::Base
