#!/usr/bin/env ruby
# frozen_string_literal: true

# Agent Metadata Example - Client
#
# Demonstrates:
# - Retrieving full agent metadata
# - Inspecting capabilities, author, links
# - Content type negotiation
# - Using the agent(name) endpoint
#
# First start the server: ruby examples/06_agent_metadata/server.rb
# Then run this client: ruby examples/06_agent_metadata/client.rb

require_relative "../../lib/simple_acp"
require "json"

client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")

puts "=== Agent Metadata Demo ==="
puts

# Verify server is running
unless client.ping
  puts "Server is not responding"
  exit 1
end
puts "Server is healthy"
puts

# --- Demo 1: List all agents with basic info ---
puts "--- Demo 1: List Agents Overview ---"
puts

agents_response = client.agents
puts "Found #{agents_response.agents.length} agents:"
puts
agents_response.agents.each do |agent|
  puts "#{agent.name}"
  puts "  Description: #{agent.description}"
  puts "  Input types: #{agent.input_content_types.join(', ')}"
  puts "  Output types: #{agent.output_content_types.join(', ')}"
  puts
end

# --- Demo 2: Get detailed agent metadata ---
puts "--- Demo 2: Detailed Agent Metadata ---"
puts

agent = client.agent("text-analyzer")

puts "Agent: #{agent.name}"
puts "Description: #{agent.description}"
puts

if agent.metadata
  meta = agent.metadata

  puts "Documentation:"
  puts "  #{meta.documentation}"
  puts

  if meta.author
    puts "Author:"
    puts "  Name: #{meta.author.name}"
    puts "  Email: #{meta.author.email}" if meta.author.email
    puts "  URL: #{meta.author.url}" if meta.author.url
    puts
  end

  if meta.contributors&.any?
    puts "Contributors:"
    meta.contributors.each do |contrib|
      puts "  - #{contrib.name}"
      puts "    Email: #{contrib.email}" if contrib.email
      puts "    URL: #{contrib.url}" if contrib.url
    end
    puts
  end

  if meta.capabilities&.any?
    puts "Capabilities:"
    meta.capabilities.each do |cap|
      puts "  - #{cap.name}: #{cap.description}"
    end
    puts
  end

  if meta.links&.any?
    puts "Links:"
    meta.links.each do |link|
      puts "  - #{link.type}: #{link.url}"
    end
    puts
  end

  if meta.dependencies&.any?
    puts "Dependencies:"
    meta.dependencies.each do |dep|
      puts "  - #{dep.type}: #{dep.name}"
    end
    puts
  end

  puts "Additional Info:"
  puts "  License: #{meta.license}" if meta.license
  puts "  Language: #{meta.programming_language}" if meta.programming_language
  puts "  Framework: #{meta.framework}" if meta.framework
  puts "  Natural languages: #{meta.natural_languages.join(', ')}" if meta.natural_languages&.any?
  puts "  Domains: #{meta.domains.join(', ')}" if meta.domains&.any?
  puts "  Tags: #{meta.tags.join(', ')}" if meta.tags&.any?
  puts "  Created: #{meta.created_at}" if meta.created_at
  puts "  Updated: #{meta.updated_at}" if meta.updated_at
  puts "  Recommended models: #{meta.recommended_models.join(', ')}" if meta.recommended_models&.any?
else
  puts "(No detailed metadata)"
end
puts

# --- Demo 3: Content Type Negotiation ---
puts "--- Demo 3: Content Type Checking ---"
puts

agent = client.agent("text-analyzer")

test_types = ["text/plain", "text/markdown", "application/json", "image/png", "text/html"]

puts "Testing input content types for #{agent.name}:"
test_types.each do |type|
  accepts = agent.accepts_content_type?(type)
  puts "  #{type}: #{accepts ? 'accepted' : 'rejected'}"
end
puts

puts "Testing output content types for #{agent.name}:"
test_types.each do |type|
  produces = agent.produces_content_type?(type)
  puts "  #{type}: #{produces ? 'produced' : 'not produced'}"
end
puts

# --- Demo 4: Compare agents with different metadata levels ---
puts "--- Demo 4: Metadata Comparison ---"
puts

%w[text-analyzer simple-echo json-processor].each do |name|
  agent = client.agent(name)
  puts "#{name}:"
  puts "  Has metadata: #{agent.metadata ? 'yes' : 'no'}"
  if agent.metadata
    puts "  Domains: #{agent.metadata.domains&.join(', ') || 'none'}"
    puts "  Tags: #{agent.metadata.tags&.join(', ') || 'none'}"
    puts "  Capabilities: #{agent.metadata.capabilities&.length || 0}"
    puts "  Links: #{agent.metadata.links&.length || 0}"
  end
  puts
end

# --- Demo 5: Using the text analyzer ---
puts "--- Demo 5: Using Text Analyzer Agent ---"
puts

sample_text = "Ruby is a wonderful programming language. It has great syntax and an amazing community. I love writing code in Ruby because it makes me happy and productive."

puts "Analyzing text:"
puts "  \"#{sample_text[0..60]}...\""
puts

run = client.run_sync(agent: "text-analyzer", input: sample_text)

run.output.each do |message|
  message.parts.each do |part|
    case part.content_type
    when "application/json"
      data = JSON.parse(part.content)
      puts "Results:"
      puts "  Word count: #{data['word_count']}"
      puts "  Sentiment: #{data['sentiment']}"
      puts "  Keywords: #{data['keywords'].join(', ')}"
      puts "  Summary: #{data['summary']}"
    when "text/plain"
      puts "  #{part.content}"
    end
  end
end
puts

puts "=== Agent Metadata Demo Complete ==="
