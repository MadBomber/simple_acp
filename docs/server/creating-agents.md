# Creating Agents

This guide covers patterns and best practices for building effective agents.

## Basic Agent Registration

### Block Syntax

The simplest way to create an agent:

```ruby
server.agent("echo", description: "Echoes input") do |context|
  text = context.input.first&.text_content
  SimpleAcp::Models::Message.agent("Echo: #{text}")
end
```

### Class-Based Agents

For complex logic, use a class:

```ruby
class TranslationAgent
  def initialize(api_key)
    @translator = TranslationService.new(api_key)
  end

  def call(context)
    text = context.input.first&.text_content
    target_lang = context.state&.dig("language") || "en"

    translated = @translator.translate(text, to: target_lang)
    SimpleAcp::Models::Message.agent(translated)
  end
end

server.register(
  "translate",
  TranslationAgent.new(ENV['TRANSLATION_API_KEY']),
  description: "Translates text"
)
```

### Agent Options

```ruby
server.agent(
  "analyzer",
  description: "Analyzes JSON data",
  input_content_types: ["application/json"],
  output_content_types: ["application/json", "text/plain"],
  metadata: {
    version: "2.0",
    capabilities: ["sentiment", "entities", "keywords"]
  }
) do |context|
  # Handler
end
```

## The Context Object

Every agent receives a `Context` with:

```ruby
server.agent("inspector") do |context|
  # Input messages
  context.input         # => Array<Message>

  # Session data
  context.session       # => Session or nil
  context.session_id    # => String or nil
  context.history       # => Array<Message>
  context.state         # => Any JSON-serializable data

  # Run metadata
  context.run_id        # => String (UUID)
  context.agent_name    # => String

  # State management
  context.set_state(new_state)  # Updates session state

  # Await pattern
  context.await_message(prompt_message)  # Request input
  context.resume_message                  # Get resume input
end
```

## Return Values

### Single Message

```ruby
server.agent("simple") do |context|
  SimpleAcp::Models::Message.agent("Single response")
end
```

### Multiple Messages

```ruby
server.agent("multi") do |context|
  [
    SimpleAcp::Models::Message.agent("First"),
    SimpleAcp::Models::Message.agent("Second"),
    SimpleAcp::Models::Message.agent("Third")
  ]
end
```

### Streaming with Enumerator

```ruby
server.agent("stream") do |context|
  Enumerator.new do |yielder|
    10.times do |i|
      yielder << SimpleAcp::Server::RunYield.new(
        SimpleAcp::Models::Message.agent("Item #{i + 1}")
      )
      sleep 0.1
    end
  end
end
```

## Common Patterns

### Input Validation

```ruby
server.agent("validated") do |context|
  input = context.input.first&.text_content

  if input.nil? || input.empty?
    return SimpleAcp::Models::Message.agent("Error: Input required")
  end

  if input.length > 1000
    return SimpleAcp::Models::Message.agent("Error: Input too long")
  end

  # Process valid input
  process(input)
end
```

### JSON Processing

```ruby
server.agent("json-processor") do |context|
  json_part = context.input.first&.parts&.find(&:json?)

  unless json_part
    return SimpleAcp::Models::Message.agent("Error: JSON input required")
  end

  data = JSON.parse(json_part.content)

  result = transform(data)

  SimpleAcp::Models::Message.agent(
    SimpleAcp::Models::MessagePart.json(result)
  )
end
```

### Multi-Part Responses

```ruby
server.agent("analysis") do |context|
  text = context.input.first&.text_content

  SimpleAcp::Models::Message.agent(
    SimpleAcp::Models::MessagePart.text("Analysis complete:"),
    SimpleAcp::Models::MessagePart.json({
      word_count: text.split.length,
      char_count: text.length,
      sentiment: analyze_sentiment(text)
    })
  )
end
```

### Chaining Agents

```ruby
server.agent("pipeline") do |context|
  # Process through multiple stages
  text = context.input.first&.text_content

  # Stage 1: Clean
  cleaned = clean_text(text)

  # Stage 2: Transform
  transformed = transform(cleaned)

  # Stage 3: Format
  formatted = format_output(transformed)

  SimpleAcp::Models::Message.agent(formatted)
end
```

### Error Handling

```ruby
server.agent("robust") do |context|
  begin
    result = external_api_call(context.input)
    SimpleAcp::Models::Message.agent(result)
  rescue Timeout::Error
    SimpleAcp::Models::Message.agent(
      "Service timeout. Please try again."
    )
  rescue RateLimitError
    SimpleAcp::Models::Message.agent(
      "Rate limit exceeded. Please wait before retrying."
    )
  rescue => e
    logger.error("Agent error: #{e.message}")
    SimpleAcp::Models::Message.agent(
      "An error occurred processing your request."
    )
  end
end
```

### Conditional Logic

```ruby
server.agent("router") do |context|
  command = context.input.first&.text_content&.downcase

  case command
  when /^help/
    SimpleAcp::Models::Message.agent(help_text)
  when /^status/
    SimpleAcp::Models::Message.agent(status_report)
  when /^search (.+)/
    SimpleAcp::Models::Message.agent(search($1))
  else
    SimpleAcp::Models::Message.agent("Unknown command. Type 'help' for options.")
  end
end
```

## Advanced Patterns

### Stateful Agents

```ruby
server.agent("wizard") do |context|
  state = context.state || { step: 1, data: {} }

  case state[:step]
  when 1
    context.set_state(state.merge(step: 2))
    SimpleAcp::Models::Message.agent("What is your name?")
  when 2
    state[:data][:name] = context.input.first&.text_content
    context.set_state(state.merge(step: 3))
    SimpleAcp::Models::Message.agent("What is your email?")
  when 3
    state[:data][:email] = context.input.first&.text_content
    context.set_state(state.merge(step: :complete))
    SimpleAcp::Models::Message.agent(
      "Complete! Name: #{state[:data][:name]}, Email: #{state[:data][:email]}"
    )
  end
end
```

### Background Processing

```ruby
server.agent("async-processor") do |context|
  job_id = BackgroundJob.enqueue(context.input)

  SimpleAcp::Models::Message.agent(
    "Processing started. Job ID: #{job_id}"
  )
end
```

### External API Integration

```ruby
class WeatherAgent
  def initialize
    @api = WeatherAPI.new(ENV['WEATHER_API_KEY'])
  end

  def call(context)
    location = context.input.first&.text_content

    weather = @api.current(location)

    SimpleAcp::Models::Message.agent(
      SimpleAcp::Models::MessagePart.text(
        "Weather in #{location}: #{weather[:conditions]}, #{weather[:temp]}°F"
      ),
      SimpleAcp::Models::MessagePart.json(weather)
    )
  rescue WeatherAPI::LocationNotFound
    SimpleAcp::Models::Message.agent("Location not found: #{location}")
  end
end
```

## Testing Agents

```ruby
require 'minitest/autorun'

class EchoAgentTest < Minitest::Test
  def setup
    @server = SimpleAcp::Server::Base.new

    @server.agent("echo") do |context|
      text = context.input.first&.text_content
      SimpleAcp::Models::Message.agent("Echo: #{text}")
    end
  end

  def test_echoes_input
    run = @server.run_sync(
      agent_name: "echo",
      input: [SimpleAcp::Models::Message.user("Hello")]
    )

    assert_equal "completed", run.status
    assert_equal "Echo: Hello", run.output.first.text_content
  end

  def test_handles_empty_input
    run = @server.run_sync(
      agent_name: "echo",
      input: [SimpleAcp::Models::Message.user("")]
    )

    assert_equal "completed", run.status
    assert_equal "Echo: ", run.output.first.text_content
  end
end
```

## Best Practices

1. **Keep agents focused** - One agent, one responsibility
2. **Validate inputs** - Check for required data early
3. **Handle errors gracefully** - Return helpful error messages
4. **Use descriptive names** - Clear agent and parameter names
5. **Document behavior** - Use description and metadata
6. **Test thoroughly** - Unit test agent logic

## Next Steps

- Learn about [Streaming Responses](streaming.md)
- Explore [Multi-Turn Conversations](multi-turn.md)
- Review [HTTP Endpoints](http-endpoints.md)
