# Server::Base

The main server class for hosting ACP agents.

## Class: SimpleAcp::Server::Base

### Constructor

```ruby
SimpleAcp::Server::Base.new(storage: nil)
```

**Parameters:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `storage` | `Storage::Base` | `Storage::Memory.new` | Storage backend |

**Example:**

```ruby
# Default memory storage
server = SimpleAcp::Server::Base.new

# With Redis storage
server = SimpleAcp::Server::Base.new(
  storage: SimpleAcp::Storage::Redis.new(url: ENV['REDIS_URL'])
)
```

---

### Instance Methods

#### #agent

Register an agent using a block.

```ruby
server.agent(name, description: nil, **options, &block)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `name` | `String` | Unique agent name |
| `description` | `String` | Human-readable description |
| `input_content_types` | `Array<String>` | Accepted MIME types |
| `output_content_types` | `Array<String>` | Produced MIME types |
| `metadata` | `Hash` | Custom metadata |
| `&block` | `Block` | Handler block receiving Context |

**Returns:** `Agent`

**Example:**

```ruby
server.agent("echo", description: "Echoes input") do |context|
  SimpleAcp::Models::Message.agent(context.input.first&.text_content)
end
```

---

#### #register

Register an agent with a callable object.

```ruby
server.register(name, handler, description: nil, **options)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `name` | `String` | Unique agent name |
| `handler` | `#call` | Object responding to `call(context)` |
| `description` | `String` | Human-readable description |
| `**options` | `Hash` | Same options as `#agent` |

**Returns:** `Agent`

**Example:**

```ruby
class MyAgent
  def call(context)
    SimpleAcp::Models::Message.agent("Hello!")
  end
end

server.register("my-agent", MyAgent.new, description: "My agent")
```

---

#### #unregister

Remove a registered agent.

```ruby
server.unregister(name)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `name` | `String` | Agent name to remove |

**Returns:** `Agent` or `nil`

---

#### #agents

Get all registered agents.

```ruby
server.agents
```

**Returns:** `Hash<String, Agent>`

---

#### #run_sync

Execute an agent synchronously.

```ruby
server.run_sync(agent_name:, input:, session_id: nil)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `agent_name` | `String` | Agent to execute |
| `input` | `Array<Message>` | Input messages |
| `session_id` | `String` | Optional session ID |

**Returns:** `Models::Run`

**Example:**

```ruby
run = server.run_sync(
  agent_name: "echo",
  input: [SimpleAcp::Models::Message.user("Hello")]
)
puts run.output.first.text_content
```

---

#### #run_async

Start an agent execution without waiting.

```ruby
server.run_async(agent_name:, input:, session_id: nil)
```

**Parameters:** Same as `#run_sync`

**Returns:** `Models::Run` (status will be `in_progress`)

---

#### #run_stream

Execute an agent with streaming events.

```ruby
server.run_stream(agent_name:, input:, session_id: nil, &block)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `agent_name` | `String` | Agent to execute |
| `input` | `Array<Message>` | Input messages |
| `session_id` | `String` | Optional session ID |
| `&block` | `Block` | Event handler |

**Returns:** `Models::Run`

**Example:**

```ruby
server.run_stream(
  agent_name: "chat",
  input: messages
) do |event|
  case event
  when SimpleAcp::Models::MessagePartEvent
    print event.part.content
  end
end
```

---

#### #resume_sync

Resume an awaiting run synchronously.

```ruby
server.resume_sync(run_id:, await_resume:)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `run_id` | `String` | Run to resume |
| `await_resume` | `AwaitResume` | Resume payload |

**Returns:** `Models::Run`

---

#### #resume_stream

Resume an awaiting run with streaming.

```ruby
server.resume_stream(run_id:, await_resume:, &block)
```

**Parameters:** Same as `#resume_sync` plus event block

**Returns:** `Models::Run`

---

#### #cancel_run

Cancel an in-progress run.

```ruby
server.cancel_run(run_id)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `run_id` | `String` | Run to cancel |

**Returns:** `Models::Run`

---

#### #to_app

Get the Rack application.

```ruby
server.to_app
```

**Returns:** `Rack::Builder`

**Example:**

```ruby
# In config.ru
run server.to_app
```

---

#### #run

Start the HTTP server.

```ruby
server.run(port: 8000, host: '0.0.0.0', **options)
```

**Parameters:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `port` | `Integer` | `8000` | Listen port |
| `host` | `String` | `'0.0.0.0'` | Bind address |

**Example:**

```ruby
server.run(port: 3000)
```

---

## Class: SimpleAcp::Server::Context

Execution context passed to agent handlers.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `input` | `Array<Message>` | Input messages |
| `session` | `Session` | Current session or nil |
| `session_id` | `String` | Session ID or nil |
| `history` | `Array<Message>` | Session history |
| `state` | `Any` | Session state |
| `run_id` | `String` | Current run ID |
| `agent_name` | `String` | Current agent name |

### Methods

#### #set_state

Update session state.

```ruby
context.set_state(new_state)
```

#### #await_message

Request additional input (for streaming handlers).

```ruby
result = context.await_message(prompt_message)
```

#### #resume_message

Get the message from a resume operation.

```ruby
message = context.resume_message
```

---

## Class: SimpleAcp::Server::RunYield

Wrapper for yielded messages in streaming handlers.

### Constructor

```ruby
SimpleAcp::Server::RunYield.new(messages)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `messages` | `Message` or `Array<Message>` | Messages to yield |

---

## Class: SimpleAcp::Server::RunYieldAwait

Signal to await client input.

### Constructor

```ruby
SimpleAcp::Server::RunYieldAwait.new(await_request)
```

---

## See Also

- [Creating Agents](../server/creating-agents.md)
- [Streaming Responses](../server/streaming.md)
- [HTTP Endpoints](../server/http-endpoints.md)
