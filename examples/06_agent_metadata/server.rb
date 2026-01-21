#!/usr/bin/env ruby
# frozen_string_literal: true

# Agent Metadata Example - Server
#
# Demonstrates rich agent metadata including:
# - Author and contributor information
# - Links to documentation and source code
# - Capabilities and domains
# - Dependencies
# - Content type negotiation
#
# Run with: ruby examples/06_agent_metadata/server.rb
# Then connect with: ruby examples/06_agent_metadata/client.rb

require_relative "../../lib/simple_acp"

server = SimpleAcp::Server::Base.new

# Agent with full metadata
metadata = SimpleAcp::Models::Metadata.new(
  documentation: "A comprehensive text analysis agent that can summarize, analyze sentiment, and extract keywords from text.",
  license: "MIT",
  programming_language: "ruby",
  natural_languages: ["en", "es", "fr"],
  framework: "SimpleAcp",
  created_at: "2024-01-15T10:00:00Z",
  updated_at: "2024-06-20T14:30:00Z",
  author: SimpleAcp::Models::Author.new(
    name: "Alice Developer",
    email: "alice@example.com",
    url: "https://github.com/alicedev"
  ),
  contributors: [
    SimpleAcp::Models::Contributor.new(
      name: "Bob Contributor",
      email: "bob@example.com"
    ),
    SimpleAcp::Models::Contributor.new(
      name: "Charlie Helper",
      url: "https://github.com/charliehelper"
    )
  ],
  capabilities: [
    SimpleAcp::Models::Capability.new(
      name: "summarize",
      description: "Summarize long text into key points"
    ),
    SimpleAcp::Models::Capability.new(
      name: "sentiment",
      description: "Analyze the sentiment (positive/negative/neutral)"
    ),
    SimpleAcp::Models::Capability.new(
      name: "keywords",
      description: "Extract important keywords and phrases"
    )
  ],
  domains: ["nlp", "text-analysis", "ai"],
  tags: ["text", "analysis", "nlp", "summarization", "sentiment"],
  links: [
    SimpleAcp::Models::Link.new(
      type: "documentation",
      url: "https://example.com/docs/text-analyzer"
    ),
    SimpleAcp::Models::Link.new(
      type: "source-code",
      url: "https://github.com/example/text-analyzer"
    ),
    SimpleAcp::Models::Link.new(
      type: "homepage",
      url: "https://example.com/text-analyzer"
    )
  ],
  dependencies: [
    SimpleAcp::Models::Dependency.new(type: "agent", name: "tokenizer"),
    SimpleAcp::Models::Dependency.new(type: "model", name: "gpt-4")
  ],
  recommended_models: ["gpt-4", "claude-3", "llama-2"]
)

server.agent("text-analyzer",
  description: "Analyzes text for sentiment, keywords, and provides summaries",
  input_content_types: ["text/plain", "text/markdown", "application/json"],
  output_content_types: ["application/json", "text/plain"],
  metadata: metadata
) do |context|
  text = context.input.first&.text_content || ""
  operation = "full"

  # Parse operation from JSON if provided
  if context.input.first&.parts&.first&.content_type == "application/json"
    begin
      data = JSON.parse(context.input.first.parts.first.content)
      text = data["text"] || text
      operation = data["operation"] || "full"
    rescue JSON::ParserError
      # Use text as-is
    end
  end

  # Simulate text analysis
  words = text.split(/\s+/)
  word_count = words.length

  # Simple keyword extraction (just take unique words > 4 chars)
  keywords = words.map(&:downcase).uniq.select { |w| w.length > 4 }.first(5)

  # Simple sentiment (just check for positive/negative words)
  positive_words = %w[good great excellent amazing wonderful happy love best fantastic]
  negative_words = %w[bad terrible awful horrible sad hate worst disappointing]

  positive_count = words.count { |w| positive_words.include?(w.downcase) }
  negative_count = words.count { |w| negative_words.include?(w.downcase) }

  sentiment = if positive_count > negative_count
    "positive"
  elsif negative_count > positive_count
    "negative"
  else
    "neutral"
  end

  result = {
    text_length: text.length,
    word_count: word_count,
    keywords: keywords,
    sentiment: sentiment,
    summary: words.first(20).join(" ") + (words.length > 20 ? "..." : "")
  }

  SimpleAcp::Models::Message.new(
    role: "agent",
    parts: [
      SimpleAcp::Models::MessagePart.json(result),
      SimpleAcp::Models::MessagePart.text(
        "Analysis complete: #{word_count} words, sentiment: #{sentiment}"
      )
    ]
  )
end

# Minimal agent for comparison
server.agent("simple-echo",
  description: "A simple echo agent with minimal metadata"
) do |context|
  input = context.input.first&.text_content || ""
  SimpleAcp::Models::Message.agent("Echo: #{input}")
end

# Agent with specific content types
server.agent("json-processor",
  description: "Processes JSON input and returns JSON output",
  input_content_types: ["application/json"],
  output_content_types: ["application/json"],
  metadata: SimpleAcp::Models::Metadata.new(
    documentation: "A JSON processor that transforms input data",
    domains: ["data-processing"],
    tags: ["json", "transform"]
  )
) do |context|
  begin
    input_data = JSON.parse(context.input.first&.text_content || "{}")
    output = {
      received: input_data,
      processed_at: Time.now.iso8601,
      keys: input_data.keys
    }
    SimpleAcp::Models::Message.new(
      role: "agent",
      parts: [SimpleAcp::Models::MessagePart.json(output)]
    )
  rescue JSON::ParserError => e
    SimpleAcp::Models::Message.new(
      role: "agent",
      parts: [SimpleAcp::Models::MessagePart.json({ error: e.message })]
    )
  end
end

puts "Starting Agent Metadata Demo Server..."
puts "Available agents:"
server.agents.each do |name, agent|
  puts "  - #{name}: #{agent.description}"
  puts "    Input types: #{agent.manifest.input_content_types.join(', ')}"
  puts "    Output types: #{agent.manifest.output_content_types.join(', ')}"
  if agent.manifest.metadata
    puts "    Has metadata: author, capabilities, links, etc."
  end
end
puts

server.run(port: 8000)
