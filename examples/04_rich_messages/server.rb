#!/usr/bin/env ruby
# frozen_string_literal: true

# Rich Messages Example - Server
#
# Demonstrates different message part types:
# - Text content
# - JSON content
# - Base64 encoded data
# - URL references
#
# Run with: ruby examples/04_rich_messages/server.rb
# Then connect with: ruby examples/04_rich_messages/client.rb

require_relative "../../lib/simple_acp"
require "json"
require "base64"

server = SimpleAcp::Server::Base.new

# Agent that returns JSON data
server.agent("json-data",
  description: "Returns structured JSON data",
  output_content_types: ["application/json", "text/plain"]
) do |context|
  query = context.input.first&.text_content || "users"

  # Simulate different data queries
  data = case query.downcase
  when "users"
    {
      query: "users",
      count: 3,
      results: [
        { id: 1, name: "Alice", role: "admin" },
        { id: 2, name: "Bob", role: "user" },
        { id: 3, name: "Charlie", role: "user" }
      ]
    }
  when "stats"
    {
      query: "stats",
      timestamp: Time.now.iso8601,
      metrics: {
        requests_today: 1234,
        active_users: 42,
        uptime_percent: 99.9
      }
    }
  else
    {
      query: query,
      error: "Unknown query type",
      available: %w[users stats]
    }
  end

  # Return message with both JSON and text parts
  message = SimpleAcp::Models::Message.new(
    role: "agent",
    parts: [
      SimpleAcp::Models::MessagePart.json(data),
      SimpleAcp::Models::MessagePart.text("Query '#{query}' returned #{data[:results]&.length || 0} results")
    ]
  )

  message
end

# Agent that returns a simple image (small SVG as base64)
server.agent("image-generator",
  description: "Generates a simple SVG image",
  output_content_types: ["image/svg+xml", "text/plain"]
) do |context|
  color = context.input.first&.text_content || "blue"

  # Create a simple SVG
  svg = <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
      <rect width="100" height="100" fill="transparent"/>
      <circle cx="50" cy="50" r="40" fill="#{color}" opacity="0.8"/>
      <text x="50" y="55" text-anchor="middle" fill="white" font-size="12">#{color}</text>
    </svg>
  SVG

  encoded = Base64.strict_encode64(svg)

  message = SimpleAcp::Models::Message.new(
    role: "agent",
    parts: [
      SimpleAcp::Models::MessagePart.new(
        kind: "data",
        content: encoded,
        content_type: "image/svg+xml"
      ),
      SimpleAcp::Models::MessagePart.text("Generated #{color} circle SVG (#{encoded.length} bytes base64)")
    ]
  )

  message
end

# Agent that returns URL references
server.agent("link-provider",
  description: "Provides relevant URLs and references",
  output_content_types: ["text/uri-list", "text/plain"]
) do |context|
  topic = context.input.first&.text_content || "ruby"

  links = case topic.downcase
  when "ruby"
    [
      { url: "https://www.ruby-lang.org/", title: "Ruby Official Site" },
      { url: "https://rubygems.org/", title: "RubyGems" },
      { url: "https://guides.rubyonrails.org/", title: "Rails Guides" }
    ]
  when "python"
    [
      { url: "https://www.python.org/", title: "Python Official Site" },
      { url: "https://pypi.org/", title: "PyPI" },
      { url: "https://docs.python.org/", title: "Python Docs" }
    ]
  else
    [
      { url: "https://www.google.com/search?q=#{topic}", title: "Search for #{topic}" }
    ]
  end

  # Create message with URL parts
  parts = links.map do |link|
    SimpleAcp::Models::MessagePart.new(
      kind: "text",
      content: "#{link[:title]}: #{link[:url]}",
      content_type: "text/plain",
      metadata: { url: link[:url], title: link[:title] }
    )
  end

  parts << SimpleAcp::Models::MessagePart.text("Found #{links.length} links for '#{topic}'")

  SimpleAcp::Models::Message.new(role: "agent", parts: parts)
end

# Agent demonstrating multi-part responses
server.agent("multi-format",
  description: "Returns data in multiple formats",
  output_content_types: ["application/json", "text/plain", "text/html"]
) do |context|
  name = context.input.first&.text_content || "World"

  # Return same greeting in multiple formats
  message = SimpleAcp::Models::Message.new(
    role: "agent",
    parts: [
      SimpleAcp::Models::MessagePart.text("Hello, #{name}!"),
      SimpleAcp::Models::MessagePart.json({ greeting: "Hello", recipient: name, timestamp: Time.now.iso8601 }),
      SimpleAcp::Models::MessagePart.new(
        kind: "text",
        content: "<h1>Hello, #{name}!</h1><p>Welcome to the multi-format demo.</p>",
        content_type: "text/html"
      )
    ]
  )

  message
end

puts "Starting Rich Messages Demo Server..."
puts "Available agents:"
server.agents.each do |name, agent|
  puts "  - #{name}: #{agent.description}"
  puts "    Input types: #{agent.manifest.input_content_types.join(', ')}"
  puts "    Output types: #{agent.manifest.output_content_types.join(', ')}"
  if agent.manifest.metadata
    puts "    Has metadata: yes"
  end
end
puts

server.run(port: 8000)
