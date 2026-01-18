#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic SimpleAcp Server Example
#
# Run with: ruby examples/basic_server.rb
# Then connect with: ruby examples/basic_client.rb

require_relative "../lib/simple_acp"

server = SimpleAcp::Server::Base.new

# Simple echo agent
server.agent("echo", description: "Echoes everything you send") do |context|
  Enumerator.new do |yielder|
    context.input.each do |message|
      yielder << SimpleAcp::Server::RunYield.new(
        SimpleAcp::Models::Message.agent(message.text_content)
      )
    end
  end
end

# Greeting agent
server.agent("greeter", description: "Greets the user by name") do |context|
  name = context.input.first&.text_content&.strip
  name = "World" if name.nil? || name.empty?

  SimpleAcp::Models::Message.agent("Hello, #{name}! Welcome to SimpleAcp.")
end

# Stateful counter agent
server.agent("counter", description: "Counts how many times you've called it") do |context|
  count = (context.state || 0) + 1
  context.set_state(count)

  SimpleAcp::Models::Message.agent("You have called me #{count} time(s).")
end

# Multi-turn conversation agent
server.agent("assistant",
  description: "A simple assistant that remembers conversation history",
  input_content_types: ["text/plain", "application/json"],
  output_content_types: ["text/plain"]
) do |context|
  # Access conversation history
  history_count = context.history.length

  response = if history_count.zero?
    "Hello! This is our first conversation. How can I help you?"
  else
    "I see we've had #{history_count} previous messages. What else can I help with?"
  end

  SimpleAcp::Models::Message.agent(response)
end

puts "Starting SimpleAcp Server..."
puts "Available agents:"
server.agents.each do |name, agent|
  puts "  - #{name}: #{agent.description}"
end
puts

server.run(port: 8000)
