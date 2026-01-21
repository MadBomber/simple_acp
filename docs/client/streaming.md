# Streaming

Streaming enables real-time delivery of agent responses via Server-Sent Events (SSE), providing immediate feedback and better user experience.

## Basic Streaming

```ruby
client.run_stream(
  agent: "chat",
  input: [SimpleAcp::Models::Message.user("Tell me a story")]
) do |event|
  case event
  when SimpleAcp::Models::MessagePartEvent
    print event.part.content
    $stdout.flush
  when SimpleAcp::Models::RunCompletedEvent
    puts "\n--- Complete ---"
  end
end
```

## Event Types

Handle different event types for full control:

```ruby
client.run_stream(agent: "processor", input: [...]) do |event|
  case event
  when SimpleAcp::Models::RunStartedEvent
    puts "Run started: #{event.run_id}"

  when SimpleAcp::Models::MessageCreatedEvent
    puts "New message from: #{event.message.role}"

  when SimpleAcp::Models::MessagePartEvent
    # Content chunk - stream to output
    print event.part.content

  when SimpleAcp::Models::MessageCompletedEvent
    puts "\n[Message complete]"

  when SimpleAcp::Models::RunCompletedEvent
    puts "Run completed!"
    puts "Output messages: #{event.run.output.length}"

  when SimpleAcp::Models::RunFailedEvent
    puts "Run failed: #{event.error.message}"

  when SimpleAcp::Models::RunAwaitingEvent
    puts "Run awaiting input..."
    puts event.await_request.message.text_content
  end
end
```

## Collecting Output

### Accumulate All Content

```ruby
output = ""

client.run_stream(agent: "chat", input: [...]) do |event|
  case event
  when SimpleAcp::Models::MessagePartEvent
    output << event.part.content
  end
end

puts "Full response: #{output}"
```

### Collect Messages

```ruby
messages = []

client.run_stream(agent: "multi", input: [...]) do |event|
  case event
  when SimpleAcp::Models::MessageCompletedEvent
    messages << event.message
  end
end

puts "Received #{messages.length} messages"
```

## Progress Tracking

### Simple Progress

```ruby
parts_received = 0

client.run_stream(agent: "processor", input: [...]) do |event|
  case event
  when SimpleAcp::Models::MessagePartEvent
    parts_received += 1
    print "\rReceived: #{parts_received} parts"
  when SimpleAcp::Models::RunCompletedEvent
    puts "\nDone!"
  end
end
```

### Detailed Progress

```ruby
def stream_with_progress(client, agent:, input:)
  state = { started_at: nil, parts: 0, messages: 0 }

  client.run_stream(agent: agent, input: input) do |event|
    case event
    when SimpleAcp::Models::RunStartedEvent
      state[:started_at] = Time.now
      puts "Processing..."

    when SimpleAcp::Models::MessagePartEvent
      state[:parts] += 1
      print "."
      $stdout.flush

    when SimpleAcp::Models::MessageCompletedEvent
      state[:messages] += 1

    when SimpleAcp::Models::RunCompletedEvent
      elapsed = Time.now - state[:started_at]
      puts "\nComplete in #{elapsed.round(2)}s"
      puts "#{state[:messages]} messages, #{state[:parts]} parts"
    end
  end
end
```

## Error Handling

### Basic Error Handling

```ruby
begin
  client.run_stream(agent: "risky", input: [...]) do |event|
    case event
    when SimpleAcp::Models::RunFailedEvent
      puts "Agent error: #{event.error.message}"
    when SimpleAcp::Models::MessagePartEvent
      print event.part.content
    end
  end
rescue Faraday::TimeoutError
  puts "Stream timed out"
rescue Faraday::ConnectionFailed
  puts "Connection lost"
end
```

### Graceful Recovery

```ruby
def stream_with_retry(client, agent:, input:, max_retries: 3)
  retries = 0

  begin
    client.run_stream(agent: agent, input: input) do |event|
      yield event
    end
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
    retries += 1
    if retries <= max_retries
      puts "Connection issue, retrying (#{retries}/#{max_retries})..."
      sleep 2 ** retries  # Exponential backoff
      retry
    else
      raise e
    end
  end
end

# Usage
stream_with_retry(client, agent: "chat", input: [...]) do |event|
  # Handle events
end
```

## Streaming with Sessions

```ruby
client.use_session("conversation-123")

# Stream with session context
client.run_stream(agent: "chat", input: [Message.user("Hello")]) do |event|
  # Handle events...
end

# Subsequent streams maintain history
client.run_stream(agent: "chat", input: [Message.user("Continue")]) do |event|
  # Has access to previous conversation
end
```

## Resume Streaming

For awaiting runs, resume with streaming:

```ruby
run = client.run_sync(agent: "questioner", input: [...])

if run.awaiting?
  puts run.await_request.message.text_content

  # Resume with streaming
  client.run_resume_stream(
    run_id: run.run_id,
    await_resume: SimpleAcp::Models::MessageAwaitResume.new(
      message: SimpleAcp::Models::Message.user("My answer")
    )
  ) do |event|
    case event
    when SimpleAcp::Models::MessagePartEvent
      print event.part.content
    end
  end
end
```

## UI Integration

### Terminal UI

```ruby
require 'io/console'

def chat_interface(client, agent)
  puts "Chat with #{agent} (type 'quit' to exit)"
  puts "-" * 40

  client.use_session("chat-#{SecureRandom.uuid}")

  loop do
    print "\nYou: "
    input = gets.chomp
    break if input.downcase == 'quit'

    print "Agent: "
    client.run_stream(
      agent: agent,
      input: [SimpleAcp::Models::Message.user(input)]
    ) do |event|
      case event
      when SimpleAcp::Models::MessagePartEvent
        print event.part.content
        $stdout.flush
      end
    end
    puts
  end
end

chat_interface(client, "chat")
```

### Web Application

```ruby
# Sinatra example
get '/stream' do
  content_type 'text/event-stream'

  stream(:keep_open) do |out|
    client.run_stream(
      agent: params[:agent],
      input: [SimpleAcp::Models::Message.user(params[:input])]
    ) do |event|
      case event
      when SimpleAcp::Models::MessagePartEvent
        out << "data: #{event.part.content.to_json}\n\n"
      when SimpleAcp::Models::RunCompletedEvent
        out << "event: done\ndata: {}\n\n"
      end
    end
  end
end
```

## Performance Tips

### Buffer Output

```ruby
buffer = []

client.run_stream(agent: "fast", input: [...]) do |event|
  case event
  when SimpleAcp::Models::MessagePartEvent
    buffer << event.part.content

    # Flush periodically
    if buffer.length >= 10
      print buffer.join
      buffer.clear
    end
  when SimpleAcp::Models::RunCompletedEvent
    print buffer.join unless buffer.empty?
  end
end
```

### Async Processing

```ruby
require 'concurrent'

def stream_async(client, agent:, input:)
  future = Concurrent::Future.execute do
    result = []
    client.run_stream(agent: agent, input: input) do |event|
      result << event
    end
    result
  end

  future
end

# Start streaming in background
future = stream_async(client, agent: "processor", input: [...])

# Do other work...

# Get results when ready
events = future.value
```

## Best Practices

1. **Flush output** - Call `$stdout.flush` for real-time display
2. **Handle all events** - Don't ignore error events
3. **Use timeouts** - Configure appropriate connection timeouts
4. **Buffer intelligently** - Balance responsiveness with efficiency
5. **Clean up** - Handle connection errors gracefully

## Next Steps

- Learn about [Session Management](sessions.md)
- Explore [Events](../core-concepts/events.md) in depth
- See [Server Streaming](../server/streaming.md) for server-side details
