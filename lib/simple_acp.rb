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

module SimpleAcp
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ValidationError < Error; end
  class NotFoundError < Error; end
  class RunError < Error; end

  class << self
    attr_accessor :logger

    def configure
      yield self if block_given?
    end
  end

end

# Convenience top-level aliases (outside the SimpleAcp module to avoid constant conflicts)
SimpleAcpServer = SimpleAcp::Server::Base
SimpleAcpClient = SimpleAcp::Client::Base
