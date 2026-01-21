#!/usr/bin/env ruby
# frozen_string_literal: true

# Run Management Example - Client
#
# Demonstrates:
# - Cancelling a running task with run_cancel
# - Retrieving run event history with run_events
# - Pagination of events
#
# First start the server: ruby examples/03_run_management/server.rb
# Then run this client: ruby examples/03_run_management/client.rb

require_relative "../../lib/simple_acp"

client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")

puts "=== Run Management Demo ==="
puts

# Verify server is running
unless client.ping
  puts "Server is not responding"
  exit 1
end
puts "Server is healthy"
puts

# --- Demo 1: Cancelling a running task ---
puts "--- Demo 1: Run Cancellation ---"
puts

puts "Starting a long-running cancellable task..."
run = client.run_async(agent: "cancellable-task", input: "data processing job")
puts "Run ID: #{run.run_id}"
puts

puts "Letting it run for 1.5 seconds..."
sleep(1.5)

status = client.run_status(run.run_id)
puts "Current status: #{status.status}"
puts

puts "Cancelling the run..."
cancelled_run = client.run_cancel(run.run_id)
puts "Cancel requested. Status: #{cancelled_run.status}"
puts

# Wait a moment for cancellation to complete
sleep(0.5)

final_status = client.run_status(run.run_id)
puts "Final status: #{final_status.status}"
puts "Output messages:"
final_status.output.each do |message|
  puts "  #{message.text_content}"
end
puts

# --- Demo 2: Let a task complete normally for comparison ---
puts "--- Demo 2: Normal Completion (for comparison) ---"
puts

puts "Starting a shorter task (will complete normally)..."
run = client.run_sync(agent: "cancellable-task", input: "quick task")
puts "Status: #{run.status}"
puts "Final message: #{run.output.last&.text_content}"
puts

# --- Demo 3: Event History ---
puts "--- Demo 3: Event History with run_events ---"
puts

puts "Generating events..."
run = client.run_sync(agent: "event-generator", input: "8")
puts "Run completed with #{run.output.length} output messages"
puts

puts "Retrieving all events for this run..."
events = client.run_events(run.run_id)
puts "Total events retrieved: #{events.length}"
puts
puts "Event types:"
event_counts = events.group_by { |e| e.class.name.split("::").last }
event_counts.each do |type, evts|
  puts "  #{type}: #{evts.length}"
end
puts

puts "First 5 events:"
events.first(5).each_with_index do |event, i|
  event_type = event.class.name.split("::").last
  puts "  #{i + 1}. #{event_type}"
end
puts

# --- Demo 4: Event Pagination ---
puts "--- Demo 4: Event Pagination ---"
puts

puts "Retrieving events with pagination (limit: 5, offset: 0)..."
page1 = client.run_events(run.run_id, limit: 5, offset: 0)
puts "Page 1: #{page1.length} events"

puts "Retrieving events with pagination (limit: 5, offset: 5)..."
page2 = client.run_events(run.run_id, limit: 5, offset: 5)
puts "Page 2: #{page2.length} events"

puts "Retrieving events with pagination (limit: 5, offset: 10)..."
page3 = client.run_events(run.run_id, limit: 5, offset: 10)
puts "Page 3: #{page3.length} events"
puts

puts "=== Run Management Demo Complete ==="
