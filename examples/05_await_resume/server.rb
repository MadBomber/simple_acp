#!/usr/bin/env ruby
# frozen_string_literal: true

# Await/Resume Example - Server
#
# Demonstrates the await/resume pattern for interactive multi-step flows.
# The agent can pause execution and request input from the client.
#
# Run with: ruby examples/05_await_resume/server.rb
# Then connect with: ruby examples/05_await_resume/client.rb

require_relative "../../lib/simple_acp"

server = SimpleAcp::Server::Base.new

# Simple single-question agent
server.agent("greeter",
  description: "Asks for your name and greets you"
) do |context|
  if context.resume_message
    # Resume: we have the client's response
    name = context.resume_message.text_content
    SimpleAcp::Models::Message.agent("Hello, #{name}! Nice to meet you!")
  else
    # Initial call: ask for input
    context.await_message(
      SimpleAcp::Models::Message.agent("What is your name?")
    )
  end
end

# Multi-step wizard using state to track progress
server.agent("survey",
  description: "A multi-step survey that collects information"
) do |context|
  # Use state to track current step and collected data
  survey_state = context.state || { step: 0, answers: {} }
  step = survey_state[:step]

  case step
  when 0
    # Step 1: Ask for name
    context.set_state({ step: 1, answers: {} })
    context.await_message(
      SimpleAcp::Models::Message.agent("Welcome to the survey! Question 1: What is your name?")
    )

  when 1
    # Step 2: Got name, ask for favorite color
    answers = survey_state[:answers].merge("name" => context.resume_message&.text_content)
    context.set_state({ step: 2, answers: answers })
    context.await_message(
      SimpleAcp::Models::Message.agent("Thanks #{answers['name']}! Question 2: What is your favorite color?")
    )

  when 2
    # Step 3: Got color, ask for favorite number
    answers = survey_state[:answers].merge("color" => context.resume_message&.text_content)
    context.set_state({ step: 3, answers: answers })
    context.await_message(
      SimpleAcp::Models::Message.agent("Great choice! Question 3: What is your favorite number?")
    )

  when 3
    # Final step: Got all answers, return summary
    answers = survey_state[:answers].merge("number" => context.resume_message&.text_content)
    context.set_state({ step: 0, answers: {} })  # Reset for next survey

    summary = <<~SUMMARY
      Survey complete! Here are your answers:
      - Name: #{answers['name']}
      - Favorite color: #{answers['color']}
      - Favorite number: #{answers['number']}
      Thank you for participating!
    SUMMARY

    SimpleAcp::Models::Message.agent(summary)
  end
end

# Confirmation agent - asks for yes/no confirmation
server.agent("confirmer",
  description: "Performs an action after confirmation"
) do |context|
  action = context.input.first&.text_content || "do something"
  state = context.state || { confirmed: nil }

  if state[:confirmed].nil?
    # First call: ask for confirmation
    context.set_state({ action: action, confirmed: false })
    context.await_message(
      SimpleAcp::Models::Message.agent("Are you sure you want to '#{action}'? (yes/no)")
    )
  else
    # Resume: check confirmation
    response = context.resume_message&.text_content&.downcase&.strip
    context.set_state(nil)  # Clear state

    if %w[yes y sure ok].include?(response)
      SimpleAcp::Models::Message.agent("Action '#{state[:action]}' confirmed and executed!")
    else
      SimpleAcp::Models::Message.agent("Action '#{state[:action]}' cancelled.")
    end
  end
end

puts "Starting Await/Resume Demo Server..."
puts "Available agents:"
server.agents.each do |name, agent|
  puts "  - #{name}: #{agent.description}"
end
puts

server.run(port: 8000)
