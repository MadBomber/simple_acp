# Quick Start

This guide walks you through creating your first ACP server and client.

## Creating an Agent Server

### Step 1: Create a Basic Server

```ruby
# server.rb
require 'simple_acp'

# Create the server
server = SimpleAcp::Server::Base.new

# Register a simple echo agent
server.agent("echo", description: "Echoes back your message") do |context|
  text = context.input.first&.text_content || "Nothing to echo"
  SimpleAcp::Models::Message.agent("You said: #{text}")
end

# Start the server
server.run(port: 8000)
```

Run the server:

```bash
ruby server.rb
# ACP Server (Falcon) running on http://0.0.0.0:8000
# Registered agents: echo
```

### Step 2: Test with curl

```bash
# Check server health
curl http://localhost:8000/ping
# {"status":"ok"}

# List available agents
curl http://localhost:8000/agents
# {"agents":[{"name":"echo","description":"Echoes back your message",...}]}

# Run the agent
curl -X POST http://localhost:8000/runs \
  -H "Content-Type: application/json" \
  -d '{
    "agent_name": "echo",
    "input": [{"role": "user", "parts": [{"content_type": "text/plain", "content": "Hello!"}]}]
  }'
# {"run_id":"...","status":"completed","output":[{"role":"agent","parts":[{"content":"You said: Hello!"}]}]}
```

## Using the Ruby Client

### Step 1: Create a Client

```ruby
# client.rb
require 'simple_acp'

client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")

# Check connection
puts client.ping ? "Connected!" : "Connection failed"

# List available agents
response = client.agents
puts "Available agents: #{response.agents.map(&:name).join(', ')}"
```

### Step 2: Run Agents

```ruby
# Synchronous execution
run = client.run_sync(
  agent: "echo",
  input: [SimpleAcp::Models::Message.user("Hello, SimpleAcp!")]
)

puts "Status: #{run.status}"
puts "Response: #{run.output.first.text_content}"
```

### Step 3: Use Streaming

```ruby
# Streaming execution with events
client.run_stream(agent: "echo", input: "Streaming test") do |event|
  case event
  when SimpleAcp::Models::RunStartedEvent
    puts "Run started: #{event.run_id}"
  when SimpleAcp::Models::MessagePartEvent
    print event.part.content
  when SimpleAcp::Models::RunCompletedEvent
    puts "\nCompleted!"
  end
end
```

## Adding More Agents

### A Greeting Agent

```ruby
server.agent("greeter", description: "Personalized greetings") do |context|
  name = context.input.first&.text_content || "World"
  SimpleAcp::Models::Message.agent("Hello, #{name}! Welcome to SimpleAcp.")
end
```

### A Multi-Response Agent

Agents can return multiple messages using an Enumerator:

```ruby
server.agent("countdown", description: "Counts down from a number") do |context|
  n = context.input.first&.text_content.to_i
  n = 5 if n <= 0

  Enumerator.new do |yielder|
    n.downto(1) do |i|
      yielder << SimpleAcp::Server::RunYield.new(
        SimpleAcp::Models::Message.agent("#{i}...")
      )
      sleep 0.5
    end
    yielder << SimpleAcp::Server::RunYield.new(
      SimpleAcp::Models::Message.agent("Liftoff!")
    )
  end
end
```

## Complete Example

Here's a complete example with both server and client:

=== "Server"

    ```ruby
    # examples/server.rb
    require 'simple_acp'

    server = SimpleAcp::Server::Base.new

    server.agent("echo") do |context|
      text = context.input.first&.text_content
      SimpleAcp::Models::Message.agent("Echo: #{text}")
    end

    server.agent("reverse") do |context|
      text = context.input.first&.text_content || ""
      SimpleAcp::Models::Message.agent(text.reverse)
    end

    server.agent("upcase") do |context|
      text = context.input.first&.text_content || ""
      SimpleAcp::Models::Message.agent(text.upcase)
    end

    puts "Starting server on port 8000..."
    server.run(port: 8000)
    ```

=== "Client"

    ```ruby
    # examples/client.rb
    require 'simple_acp'

    client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")

    # Test each agent
    %w[echo reverse upcase].each do |agent_name|
      run = client.run_sync(
        agent: agent_name,
        input: [SimpleAcp::Models::Message.user("Hello World")]
      )
      puts "#{agent_name}: #{run.output.first.text_content}"
    end
    ```

## Next Steps

- Learn about [Configuration](configuration.md) options
- Understand [Core Concepts](../core-concepts/index.md) like messages, runs, and sessions
- Dive into the [Server Guide](../server/index.md) for advanced agent development
