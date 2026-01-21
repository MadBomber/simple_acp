#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic SimpleAcp Server Example
#
# Run with: ruby examples/01_basic/server.rb
# Then connect with: ruby examples/01_basic/client.rb

require_relative "../../lib/simple_acp"

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

# Streaming demonstration agent - recites the Gettysburg Address word by word
server.agent("gettysburg", description: "Recites the Gettysburg Address word by word") do |context|
  address = <<~TEXT
    Four score and seven years ago our fathers brought forth on this continent, a new nation, conceived in Liberty, and dedicated to the proposition that all men are created equal.
    Now we are engaged in a great civil war, testing whether that nation, or any nation so conceived and so dedicated, can long endure.
    We are met on a great battle-field of that war.
    We have come to dedicate a portion of that field, as a final resting place for those who here gave their lives that that nation might live.
    It is altogether fitting and proper that we should do this.
    But, in a larger sense, we can not dedicate — we can not consecrate — we can not hallow — this ground.
    The brave men, living and dead, who struggled here, have consecrated it, far above our poor power to add or detract.
    The world will little note, nor long remember what we say here, but it can never forget what they did here.
    It is for us the living, rather, to be dedicated here to the unfinished work which they who fought here have thus far so nobly advanced.
    It is rather for us to be here dedicated to the great task remaining before us — that from these honored dead we take increased devotion to that cause for which they gave the last full measure of devotion — that we here highly resolve that these dead shall not have died in vain — that this nation, under God, shall have a new birth of freedom — and that government of the people, by the people, for the people, shall not perish from the earth.
  TEXT

  words = address.split

  Enumerator.new do |yielder|
    words.each do |word|
      # Use fiber-aware sleep for Async/Falcon compatibility
      if defined?(Async::Task) && Async::Task.current?
        Async::Task.current.sleep(0.3)
      else
        sleep(0.3)
      end
      yielder << SimpleAcp::Server::RunYield.new(
        SimpleAcp::Models::Message.agent(word + " ")
      )
    end
  end
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

########################################################
## main line
#
puts "Starting SimpleAcp Server..."
puts "Available agents:"
server.agents.each do |name, agent|
  puts "  - #{name}: #{agent.description}"
end
puts

server.run(port: 8000)
