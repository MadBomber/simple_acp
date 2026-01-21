#!/usr/bin/env ruby
# frozen_string_literal: true

# Run Management Example - Server
#
# Demonstrates run cancellation and event tracking.
#
# Run with: ruby examples/03_run_management/server.rb
# Then connect with: ruby examples/03_run_management/client.rb

require_relative "../../lib/simple_acp"

server = SimpleAcp::Server::Base.new

# Long-running cancellable agent
server.agent("cancellable-task",
  description: "A long task that can be cancelled (10 iterations)"
) do |context|
  task_name = context.input.first&.text_content || "unnamed task"

  Enumerator.new do |yielder|
    yielder << SimpleAcp::Server::RunYield.new(
      SimpleAcp::Models::Message.agent("Starting: #{task_name}")
    )

    10.times do |i|
      # Check for cancellation before each iteration
      if context.cancelled?
        yielder << SimpleAcp::Server::RunYield.new(
          SimpleAcp::Models::Message.agent("Task cancelled at iteration #{i + 1}")
        )
        break
      end

      # Simulate work
      if defined?(Async::Task) && Async::Task.current?
        Async::Task.current.sleep(0.5)
      else
        sleep(0.5)
      end

      yielder << SimpleAcp::Server::RunYield.new(
        SimpleAcp::Models::Message.agent("Iteration #{i + 1}/10 complete")
      )
    end

    unless context.cancelled?
      yielder << SimpleAcp::Server::RunYield.new(
        SimpleAcp::Models::Message.agent("Task '#{task_name}' finished successfully!")
      )
    end
  end
end

# Agent that generates many events for event history demo
server.agent("event-generator",
  description: "Generates multiple events for history tracking"
) do |context|
  count = context.input.first&.text_content&.to_i || 5
  count = [count, 20].min  # Cap at 20

  Enumerator.new do |yielder|
    count.times do |i|
      yielder << SimpleAcp::Server::RunYield.new(
        SimpleAcp::Models::Message.agent("Event #{i + 1}: Generated at #{Time.now.strftime('%H:%M:%S.%L')}")
      )

      if defined?(Async::Task) && Async::Task.current?
        Async::Task.current.sleep(0.1)
      else
        sleep(0.1)
      end
    end
  end
end

puts "Starting Run Management Demo Server..."
puts "Available agents:"
server.agents.each do |name, agent|
  puts "  - #{name}: #{agent.description}"
end
puts

server.run(port: 8000)
