#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic SimpleAcp Client Example
#
# First start the server: ruby examples/basic_server.rb
# Then run this client: ruby examples/basic_client.rb

require_relative "../lib/simple_acp"

client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")

puts "=== SimpleAcp Client Example ==="
puts

# Check server health
if client.ping
  puts "✓ Server is healthy"
else
  puts "✗ Server is not responding"
  exit 1
end
puts

# List available agents
puts "Available agents:"
agents = client.agents
agents.agents.each do |agent|
  puts "  - #{agent.name}: #{agent.description}"
end
puts

# Test echo agent
puts "--- Testing echo agent ---"
run = client.run_sync(agent: "echo", input: "Hello, SimpleAcp!")
puts "Input: Hello, SimpleAcp!"
puts "Output: #{run.output.first.text_content}"
puts

# Test greeter agent
puts "--- Testing greeter agent ---"
run = client.run_sync(agent: "greeter", input: "Ruby Developer")
puts "Input: Ruby Developer"
puts "Output: #{run.output.first.text_content}"
puts

# Test counter agent with session
puts "--- Testing counter agent with session ---"
session_id = SecureRandom.uuid
client.use_session(session_id)

3.times do |i|
  run = client.run_sync(agent: "counter", input: "increment")
  puts "Call #{i + 1}: #{run.output.first.text_content}"
end
client.clear_session
puts

# Test streaming
puts "--- Testing streaming ---"
print "Streaming response: "
client.run_stream(agent: "echo", input: "Streaming works!") do |event|
  case event
  when SimpleAcp::Models::MessagePartEvent
    print event.part.content
  when SimpleAcp::Models::RunCompletedEvent
    puts " [DONE]"
  end
end
puts

# Test assistant with history
puts "--- Testing assistant with history ---"
session_id = SecureRandom.uuid
client.use_session(session_id)

["Hi!", "Tell me more", "Thanks!"].each do |msg|
  run = client.run_sync(agent: "assistant", input: msg)
  puts "User: #{msg}"
  puts "Agent: #{run.output.first.text_content}"
  puts
end

puts "=== All tests completed ==="
