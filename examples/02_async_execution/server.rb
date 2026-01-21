#!/usr/bin/env ruby
# frozen_string_literal: true

# Async Execution Example - Server
#
# Demonstrates async (non-blocking) execution with polling.
#
# Run with: ruby examples/02_async_execution/server.rb
# Then connect with: ruby examples/02_async_execution/client.rb

require_relative "../../lib/simple_acp"

server = SimpleAcp::Server::Base.new

# Slow worker agent - simulates a long-running task
server.agent("slow-worker", description: "Simulates a long-running task (3 seconds)") do |context|
  task_name = context.input.first&.text_content || "default task"

  # Simulate work with progress updates
  Enumerator.new do |yielder|
    yielder << SimpleAcp::Server::RunYield.new(
      SimpleAcp::Models::Message.agent("Starting task: #{task_name}")
    )

    # Simulate 3 seconds of work
    3.times do |i|
      if defined?(Async::Task) && Async::Task.current?
        Async::Task.current.sleep(1)
      else
        sleep(1)
      end

      yielder << SimpleAcp::Server::RunYield.new(
        SimpleAcp::Models::Message.agent("Progress: #{(i + 1) * 33}%")
      )
    end

    yielder << SimpleAcp::Server::RunYield.new(
      SimpleAcp::Models::Message.agent("Task '#{task_name}' completed!")
    )
  end
end

# Quick status agent - returns immediately
server.agent("quick-status", description: "Returns status immediately") do |context|
  SimpleAcp::Models::Message.agent("Status: All systems operational at #{Time.now}")
end

puts "Starting Async Execution Demo Server..."
puts "Available agents:"
server.agents.each do |name, agent|
  puts "  - #{name}: #{agent.description}"
end
puts

server.run(port: 8000)
