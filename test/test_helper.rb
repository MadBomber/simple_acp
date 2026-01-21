# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "bundler/setup"
require "simple_acp"
require "minitest/autorun"
require "minitest/reporters"
require "rack/test"
# No mocks - tests use real objects and integrations

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# Helper module for creating test servers
module TestHelpers
  def create_test_server
    server = SimpleAcp::Server::Base.new

    server.agent("echo", description: "Echoes input messages") do |context|
      Enumerator.new do |yielder|
        context.input.each do |message|
          yielder << SimpleAcp::Server::RunYield.new(
            SimpleAcp::Models::Message.agent(message.text_content)
          )
        end
      end
    end

    server.agent("greeter", description: "Greets the user") do |context|
      name = context.input.first&.text_content || "World"
      SimpleAcp::Models::Message.agent("Hello, #{name}!")
    end

    server
  end

  def user_message(content)
    SimpleAcp::Models::Message.user(content)
  end

  def agent_message(content)
    SimpleAcp::Models::Message.agent(content)
  end
end

# Base test class with helpers
class SimpleAcpTestCase < Minitest::Test
  include TestHelpers
end
