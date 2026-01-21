#!/usr/bin/env ruby
# frozen_string_literal: true

# Rich Messages Example - Client
#
# Demonstrates:
# - Receiving JSON content in message parts
# - Receiving base64 encoded data (images)
# - Receiving URL references
# - Multi-part messages with different content types
#
# First start the server: ruby examples/04_rich_messages/server.rb
# Then run this client: ruby examples/04_rich_messages/client.rb

require_relative "../../lib/simple_acp"
require "json"
require "base64"

client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")

puts "=== Rich Messages Demo ==="
puts

# Verify server is running
unless client.ping
  puts "Server is not responding"
  exit 1
end
puts "Server is healthy"
puts

# --- Demo 1: JSON Data ---
puts "--- Demo 1: JSON Content ---"
puts

puts "Querying for 'users' data..."
run = client.run_sync(agent: "json-data", input: "users")

run.output.each do |message|
  message.parts.each do |part|
    case part.content_type
    when "application/json"
      puts "JSON Part:"
      data = JSON.parse(part.content)
      puts "  Query: #{data['query']}"
      puts "  Count: #{data['count']}"
      puts "  Results:"
      data["results"]&.each do |user|
        puts "    - #{user['name']} (#{user['role']})"
      end
    when "text/plain"
      puts "Text Part: #{part.content}"
    end
  end
end
puts

puts "Querying for 'stats' data..."
run = client.run_sync(agent: "json-data", input: "stats")

run.output.each do |message|
  message.parts.each do |part|
    if part.content_type == "application/json"
      data = JSON.parse(part.content)
      puts "Stats (#{data['timestamp']}):"
      data["metrics"]&.each do |key, value|
        puts "  #{key}: #{value}"
      end
    end
  end
end
puts

# --- Demo 2: Image/Binary Data ---
puts "--- Demo 2: Base64 Encoded Image ---"
puts

%w[red green blue].each do |color|
  puts "Generating #{color} circle..."
  run = client.run_sync(agent: "image-generator", input: color)

  run.output.each do |message|
    message.parts.each do |part|
      case part.content_type
      when "image/svg+xml"
        # Decode and show first line of SVG
        svg = Base64.decode64(part.content)
        puts "  SVG data received (#{part.content.length} bytes base64)"
        puts "  First line: #{svg.lines.first.strip}"
      when "text/plain"
        puts "  #{part.content}"
      end
    end
  end
end
puts

# --- Demo 3: URL References ---
puts "--- Demo 3: URL References ---"
puts

%w[ruby python javascript].each do |topic|
  puts "Getting links for '#{topic}'..."
  run = client.run_sync(agent: "link-provider", input: topic)

  run.output.each do |message|
    message.parts.each do |part|
      if part.metadata && part.metadata["url"]
        puts "  #{part.metadata['title']}"
        puts "    URL: #{part.metadata['url']}"
      elsif part.content&.include?("Found")
        puts "  #{part.content}"
      end
    end
  end
  puts
end

# --- Demo 4: Multi-Format Response ---
puts "--- Demo 4: Multi-Format Response ---"
puts

puts "Requesting greeting in multiple formats..."
run = client.run_sync(agent: "multi-format", input: "Developer")

run.output.each do |message|
  puts "Message has #{message.parts.length} parts:"
  message.parts.each_with_index do |part, i|
    puts
    puts "  Part #{i + 1} (#{part.content_type}):"
    case part.content_type
    when "application/json"
      data = JSON.parse(part.content)
      puts "    #{data.inspect}"
    when "text/html"
      # Show HTML without rendering
      puts "    #{part.content.gsub("\n", " ").strip}"
    else
      puts "    #{part.content}"
    end
  end
end
puts

# --- Demo 5: Content Type Inspection ---
puts "--- Demo 5: Agent Content Type Capabilities ---"
puts

puts "Listing agents and their content types:"
agents_response = client.agents
agents_response.agents.each do |agent|
  puts
  puts "#{agent.name}:"
  puts "  Description: #{agent.description}"
  puts "  Input types: #{agent.input_content_types&.join(', ') || 'any'}"
  puts "  Output types: #{agent.output_content_types&.join(', ') || 'any'}"
end
puts

puts "=== Rich Messages Demo Complete ==="
