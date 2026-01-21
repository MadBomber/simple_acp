#!/usr/bin/env ruby
# frozen_string_literal: true

# Async Execution Example - Client
#
# Demonstrates:
# - Async (non-blocking) execution with run_async
# - Polling run status with run_status
# - Waiting for completion with wait_for_run
# - Running multiple tasks concurrently
#
# First start the server: ruby examples/02_async_execution/server.rb
# Then run this client: ruby examples/02_async_execution/client.rb

require_relative "../../lib/simple_acp"

client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")

puts "=== Async Execution Demo ==="
puts

# Verify server is running
unless client.ping
  puts "Server is not responding"
  exit 1
end
puts "Server is healthy"
puts

# --- Demo 1: Async execution with manual polling ---
puts "--- Demo 1: Async Execution with Manual Polling ---"
puts

puts "Starting slow-worker asynchronously..."
run = client.run_async(agent: "slow-worker", input: "data analysis")
puts "Run started with ID: #{run.run_id}"
puts "Initial status: #{run.status}"
puts

puts "Polling for status..."
loop do
  status = client.run_status(run.run_id)
  puts "  Status: #{status.status}"

  break if status.terminal?

  sleep(0.5)
end

puts
puts "Run completed! Final output:"
final_run = client.run_status(run.run_id)
final_run.output.each do |message|
  puts "  #{message.text_content}"
end
puts

# --- Demo 2: Using wait_for_run for simpler polling ---
puts "--- Demo 2: Using wait_for_run ---"
puts

puts "Starting another slow-worker..."
run = client.run_async(agent: "slow-worker", input: "report generation")
puts "Run ID: #{run.run_id}"
puts

puts "Waiting for completion (timeout: 10s)..."
completed_run = client.wait_for_run(run.run_id, timeout: 10)

if completed_run.status == "completed"
  puts "Success! Output:"
  completed_run.output.each do |message|
    puts "  #{message.text_content}"
  end
else
  puts "Run ended with status: #{completed_run.status}"
end
puts

# --- Demo 3: Running multiple tasks concurrently ---
puts "--- Demo 3: Concurrent Async Execution ---"
puts

puts "Starting 3 tasks concurrently..."
runs = []
%w[task_alpha task_beta task_gamma].each do |task_name|
  run = client.run_async(agent: "slow-worker", input: task_name)
  runs << run
  puts "  Started: #{task_name} (#{run.run_id[0..7]}...)"
end
puts

puts "Waiting for all tasks to complete..."
start_time = Time.now

runs.each do |run|
  completed = client.wait_for_run(run.run_id, timeout: 15)
  task_name = completed.output.last&.text_content || "unknown"
  puts "  Completed: #{task_name}"
end

elapsed = (Time.now - start_time).round(2)
puts
puts "All 3 tasks completed in #{elapsed}s (ran concurrently, not 9s sequentially)"
puts

puts "=== Async Execution Demo Complete ==="
