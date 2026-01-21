#!/usr/bin/env ruby
# frozen_string_literal: true

# Await/Resume Example - Client
#
# Demonstrates:
# - Detecting when a run is awaiting input
# - Resuming a run with run_resume_sync
# - Multi-step interactive flows
# - Streaming resume with run_resume_stream
#
# First start the server: ruby examples/05_await_resume/server.rb
# Then run this client: ruby examples/05_await_resume/client.rb

require_relative "../../lib/simple_acp"

client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")

puts "=== Await/Resume Demo ==="
puts

# Verify server is running
unless client.ping
  puts "Server is not responding"
  exit 1
end
puts "Server is healthy"
puts

# --- Demo 1: Simple greeter with await/resume ---
puts "--- Demo 1: Simple Greeter (Single Await) ---"
puts

puts "Starting greeter agent..."
run = client.run_sync(agent: "greeter", input: "start")

if run.status == "awaiting"
  puts "Status: #{run.status}"
  puts "Agent asks: #{run.await_request&.message&.text_content}"
  puts

  # Resume with our response
  puts "Responding with: 'Alice'"
  resume = SimpleAcp::Models::MessageAwaitResume.new(
    message: SimpleAcp::Models::Message.user("Alice")
  )

  completed_run = client.run_resume_sync(run_id: run.run_id, await_resume: resume)
  puts "Status: #{completed_run.status}"
  puts "Agent says: #{completed_run.output.last&.text_content}"
else
  puts "Unexpected status: #{run.status}"
end
puts

# --- Demo 2: Multi-step survey ---
puts "--- Demo 2: Multi-Step Survey (Multiple Awaits) ---"
puts

puts "Starting survey..."
run = client.run_sync(agent: "survey", input: "begin")

responses = ["Bob", "blue", "42"]
response_index = 0

while run.status == "awaiting"
  puts "Agent asks: #{run.await_request&.message&.text_content}"

  if response_index < responses.length
    response = responses[response_index]
    puts "Responding with: '#{response}'"
    puts

    resume = SimpleAcp::Models::MessageAwaitResume.new(
      message: SimpleAcp::Models::Message.user(response)
    )

    run = client.run_resume_sync(run_id: run.run_id, await_resume: resume)
    response_index += 1
  else
    puts "ERROR: Ran out of responses!"
    break
  end
end

if run.status == "completed"
  puts "Survey completed!"
  puts run.output.last&.text_content
else
  puts "Unexpected final status: #{run.status}"
end
puts

# --- Demo 3: Confirmation agent - Yes case ---
puts "--- Demo 3: Confirmation (Yes) ---"
puts

puts "Requesting action: 'delete all files'"
run = client.run_sync(agent: "confirmer", input: "delete all files")

if run.status == "awaiting"
  puts "Agent asks: #{run.await_request&.message&.text_content}"
  puts "Responding with: 'yes'"

  resume = SimpleAcp::Models::MessageAwaitResume.new(
    message: SimpleAcp::Models::Message.user("yes")
  )

  completed_run = client.run_resume_sync(run_id: run.run_id, await_resume: resume)
  puts "Result: #{completed_run.output.last&.text_content}"
end
puts

# --- Demo 4: Confirmation agent - No case ---
puts "--- Demo 4: Confirmation (No) ---"
puts

puts "Requesting action: 'format hard drive'"
run = client.run_sync(agent: "confirmer", input: "format hard drive")

if run.status == "awaiting"
  puts "Agent asks: #{run.await_request&.message&.text_content}"
  puts "Responding with: 'no'"

  resume = SimpleAcp::Models::MessageAwaitResume.new(
    message: SimpleAcp::Models::Message.user("no")
  )

  completed_run = client.run_resume_sync(run_id: run.run_id, await_resume: resume)
  puts "Result: #{completed_run.output.last&.text_content}"
end
puts

# --- Demo 5: Streaming resume ---
puts "--- Demo 5: Streaming Resume ---"
puts

puts "Starting greeter with streaming resume..."
run = client.run_sync(agent: "greeter", input: "start")

if run.status == "awaiting"
  puts "Agent asks: #{run.await_request&.message&.text_content}"
  puts "Resuming with streaming..."

  resume = SimpleAcp::Models::MessageAwaitResume.new(
    message: SimpleAcp::Models::Message.user("Charlie")
  )

  print "Events: "
  client.run_resume_stream(run_id: run.run_id, await_resume: resume) do |event|
    case event
    when SimpleAcp::Models::RunInProgressEvent
      print "[in_progress] "
    when SimpleAcp::Models::MessageCreatedEvent
      print "[message] "
    when SimpleAcp::Models::RunCompletedEvent
      puts "[completed]"
      puts "Final output: #{event.run.output.last&.text_content}"
    end
  end
end
puts

puts "=== Await/Resume Demo Complete ==="
