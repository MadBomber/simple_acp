# SimpleAcp

<table>
  <tr>
    <td width="40%">
      <img src="docs/assets/images/simple_acp.jpg" alt="SimpleAcp - Robots communicating in binary" width="100%">
    </td>
    <td width="60%" valign="top">
      <strong>A Ruby implementation of the Agent Communication Protocol (ACP)</strong>
      <br><br>
      SimpleAcp provides an open protocol for communication between AI agents, applications, and humans. Build agent servers that host multiple agents, connect with HTTP clients, and stream responses in real-time via Server-Sent Events.
      <br><br>
      <table>
        <tr>
          <td>:robot: Full ACP Protocol</td>
          <td>:arrows_counterclockwise: Sync/Async/Stream</td>
        </tr>
        <tr>
          <td>:speech_balloon: Session Management</td>
          <td>:framed_picture: Multimodal Messages</td>
        </tr>
        <tr>
          <td>:floppy_disk: Pluggable Storage</td>
          <td>:zap: SSE Streaming</td>
        </tr>
      </table>
    </td>
  </tr>
</table>

<p align="center">
  <a href="https://madbomber.github.io/simple_acp/getting-started/installation/">Install</a> •
  <a href="https://madbomber.github.io/simple_acp/getting-started/quick-start/">Quick Start</a> •
  <a href="https://madbomber.github.io/simple_acp/">Documentation</a> •
  <a href="https://github.com/i-am-bee/acp">ACP Specification</a>
</p>

---

## Features

- **Full ACP Protocol Support**: Implements the ACP specification including agents, runs, sessions, and events
- **Multiple Run Modes**: Synchronous, asynchronous, and streaming execution
- **Session Management**: Maintain state and conversation history across interactions
- **Multimodal Messages**: Support for text, JSON, images, and URL references
- **Pluggable Storage**: In-memory, Redis, and PostgreSQL backends
- **SSE Streaming**: Server-Sent Events for real-time response streaming

## Documentation

For comprehensive guides, tutorials, and API reference, visit the **[SimpleAcp Documentation](https://madbomber.github.io/simple_acp/)**.

The documentation covers:

- [Installation & Quick Start](https://madbomber.github.io/simple_acp/getting-started/installation/)
- [Core Concepts](https://madbomber.github.io/simple_acp/core-concepts/) (Messages, Agents, Runs, Sessions, Events)
- [Server Guide](https://madbomber.github.io/simple_acp/server/) (Creating Agents, Streaming, Multi-Turn Conversations)
- [Client Guide](https://madbomber.github.io/simple_acp/client/) (Sync/Async, Streaming, Session Management)
- [Storage Backends](https://madbomber.github.io/simple_acp/storage/) (Memory, Redis, PostgreSQL, Custom)
- [API Reference](https://madbomber.github.io/simple_acp/api/)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'simple_acp'
```

Or install it directly:

```bash
gem install simple_acp
```

## Quick Start

### Creating an Agent Server

```ruby
require 'simple_acp'

server = SimpleAcp::Server::Base.new

# Register an agent using block syntax
server.agent("echo", description: "Echoes everything") do |context|
  Enumerator.new do |yielder|
    context.input.each do |message|
      yielder << SimpleAcp::Server::RunYield.new(
        SimpleAcp::Models::Message.agent(message.text_content)
      )
    end
  end
end

# Register a simple greeting agent
server.agent("greeter", description: "Greets the user") do |context|
  name = context.input.first&.text_content || "World"
  SimpleAcp::Models::Message.agent("Hello, #{name}!")
end

# Start the server
server.run(port: 8000)
```

### Using the Client

```ruby
require 'simple_acp'

client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")

# List available agents
agents = client.agents
puts agents.agents.map(&:name)

# Run an agent synchronously
run = client.run_sync(
  agent: "echo",
  input: [SimpleAcp::Models::Message.user("Hello, SimpleAcp!")]
)

puts run.output.first.text_content
# => "Hello, SimpleAcp!"

# Run with streaming
client.run_stream(agent: "echo", input: "Streaming test") do |event|
  case event
  when SimpleAcp::Models::MessagePartEvent
    print event.part.content
  when SimpleAcp::Models::RunCompletedEvent
    puts "\nDone!"
  end
end
```

## API Reference

### Server

The `SimpleAcp::Server::Base` class hosts agents and handles incoming requests.

```ruby
server = SimpleAcp::Server::Base.new(storage: SimpleAcp::Storage::Memory.new)

# Register agents
server.agent("name", description: "...", input_content_types: ["text/plain"]) do |context|
  # context.input - array of input messages
  # context.session - current session (if any)
  # context.history - conversation history
  # context.state - session state
  # context.set_state(data) - update session state
  # context.await_message(prompt) - request client input

  # Return messages or yield them for streaming
  SimpleAcp::Models::Message.agent("Response")
end

# Run programmatically
run = server.run_sync(agent_name: "name", input: messages)

# Or start HTTP server
server.run(port: 8000)
```

### Client

The `SimpleAcp::Client::Base` class communicates with ACP servers.

```ruby
client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")

# Discovery
client.ping                    # Health check
client.agents                  # List agents
client.agent("name")           # Get agent manifest

# Execution
client.run_sync(agent: "name", input: messages)
client.run_async(agent: "name", input: messages)
client.run_stream(agent: "name", input: messages) { |event| ... }

# Run management
client.run_status(run_id)
client.run_events(run_id)
client.run_cancel(run_id)

# Resume awaited runs
client.run_resume_sync(run_id: id, await_resume: resume_payload)
client.run_resume_stream(run_id: id, await_resume: resume_payload) { |e| ... }

# Session management
client.use_session(session_id)
client.clear_session
```

### Models

#### Message

```ruby
# Create messages
SimpleAcp::Models::Message.user("Hello")
SimpleAcp::Models::Message.agent("Response")

# With multiple parts
SimpleAcp::Models::Message.user(
  SimpleAcp::Models::MessagePart.text("Some text"),
  SimpleAcp::Models::MessagePart.json({ key: "value" })
)

# Access content
message.role           # "user" or "agent"
message.parts          # Array of MessagePart
message.text_content   # Combined text from all parts
```

#### MessagePart

```ruby
# Factory methods
SimpleAcp::Models::MessagePart.text("Hello")
SimpleAcp::Models::MessagePart.json({ key: "value" })
SimpleAcp::Models::MessagePart.image(base64_data, mime_type: "image/png")
SimpleAcp::Models::MessagePart.from_url("https://...", content_type: "image/jpeg")

# Properties
part.content_type      # MIME type
part.content           # Inline content
part.content_url       # URL reference
part.content_encoding  # "plain" or "base64"
part.text?             # Is text content?
part.json?             # Is JSON content?
part.image?            # Is image content?
```

#### Run

```ruby
run.run_id         # UUID
run.agent_name     # Agent that executed
run.status         # Current status
run.output         # Output messages
run.error          # Error if failed
run.session_id     # Associated session

# Status checks
run.terminal?      # Is in final state?
run.completed?
run.failed?
run.cancelled?
run.awaiting?
```

### Storage Backends

#### Memory (Default)

```ruby
storage = SimpleAcp::Storage::Memory.new
server = SimpleAcp::Server::Base.new(storage: storage)
```

#### Redis

```ruby
require 'simple_acp/storage/redis'

storage = SimpleAcp::Storage::Redis.new(
  url: "redis://localhost:6379",
  ttl: 86400  # 24 hours
)
server = SimpleAcp::Server::Base.new(storage: storage)
```

#### PostgreSQL

```ruby
require 'simple_acp/storage/postgresql'

storage = SimpleAcp::Storage::PostgreSQL.new(
  url: "postgres://localhost/simple_acp_production"
)
server = SimpleAcp::Server::Base.new(storage: storage)
```

## Advanced Usage

### Stateful Agents with Sessions

```ruby
server.agent("counter") do |context|
  count = (context.state || 0) + 1
  context.set_state(count)
  SimpleAcp::Models::Message.agent("Count: #{count}")
end

# Client maintains session across requests
client.use_session("my-session")
client.run_sync(agent: "counter", input: "increment")  # Count: 1
client.run_sync(agent: "counter", input: "increment")  # Count: 2
```

### Awaiting Client Input

```ruby
server.agent("questioner") do |context|
  Enumerator.new do |yielder|
    # Ask a question
    result = context.await_message(
      SimpleAcp::Models::Message.agent("What is your name?")
    )
    yielder << result

    # When resumed, result will contain the client's response
    # This part runs after run_resume is called
    name = context.resume_message&.text_content
    yielder << SimpleAcp::Server::RunYield.new(
      SimpleAcp::Models::Message.agent("Hello, #{name}!")
    )
  end
end

# Client side
run = client.run_sync(agent: "questioner", input: "start")
# run.awaiting? => true

run = client.run_resume_sync(
  run_id: run.run_id,
  await_resume: SimpleAcp::Models::MessageAwaitResume.new(
    message: SimpleAcp::Models::Message.user("Alice")
  )
)
# run.output includes "Hello, Alice!"
```

## HTTP API Endpoints

When running as an HTTP server, these endpoints are available:

- `GET /ping` - Health check
- `GET /agents` - List agents
- `GET /agents/:name` - Get agent manifest
- `POST /runs` - Create a run
- `GET /runs/:id` - Get run status
- `POST /runs/:id` - Resume awaited run
- `POST /runs/:id/cancel` - Cancel run
- `GET /runs/:id/events` - Get run events
- `GET /session/:id` - Get session info

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rake test

# Run a specific test
bundle exec ruby -Ilib:test test/simple_acp/models/message_test.rb
```

## License

Apache License 2.0 - See LICENSE file for details.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
