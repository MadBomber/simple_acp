# Client::Base

HTTP client for communicating with ACP servers.

## Class: SimpleAcp::Client::Base

### Constructor

```ruby
SimpleAcp::Client::Base.new(base_url:, timeout: 30, headers: {})
```

**Parameters:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `base_url` | `String` | required | Server URL |
| `timeout` | `Integer` | `30` | Request timeout in seconds |
| `headers` | `Hash` | `{}` | Custom headers |

**Example:**

```ruby
client = SimpleAcp::Client::Base.new(
  base_url: "http://localhost:8000",
  timeout: 60,
  headers: { "Authorization" => "Bearer token" }
)
```

---

### Discovery Methods

#### #ping

Check server health.

```ruby
client.ping
```

**Returns:** `Boolean`

**Example:**

```ruby
if client.ping
  puts "Server is healthy"
end
```

---

#### #agents

List all available agents.

```ruby
client.agents
```

**Returns:** `Models::Types::AgentList`

**Example:**

```ruby
response = client.agents
response.agents.each do |agent|
  puts "#{agent.name}: #{agent.description}"
end
```

---

#### #agent

Get a specific agent's manifest.

```ruby
client.agent(name)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `name` | `String` | Agent name |

**Returns:** `Models::AgentManifest`

**Raises:** `SimpleAcp::Error` if not found

---

### Execution Methods

#### #run_sync

Execute an agent and wait for completion.

```ruby
client.run_sync(agent:, input:)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `agent` | `String` | Agent name |
| `input` | `Array<Message>` or `String` | Input messages |

**Returns:** `Models::Run`

**Example:**

```ruby
run = client.run_sync(
  agent: "echo",
  input: [SimpleAcp::Models::Message.user("Hello")]
)

# String input is auto-converted
run = client.run_sync(agent: "echo", input: "Hello")
```

---

#### #run_async

Start an agent execution without waiting.

```ruby
client.run_async(agent:, input:)
```

**Parameters:** Same as `#run_sync`

**Returns:** `Models::Run` (status will be `in_progress` or `created`)

---

#### #run_stream

Execute an agent with streaming events.

```ruby
client.run_stream(agent:, input:, &block)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `agent` | `String` | Agent name |
| `input` | `Array<Message>` or `String` | Input messages |
| `&block` | `Block` | Event handler |

**Returns:** `Models::Run`

**Example:**

```ruby
client.run_stream(agent: "chat", input: "Hello") do |event|
  case event
  when SimpleAcp::Models::RunStartedEvent
    puts "Started!"
  when SimpleAcp::Models::MessagePartEvent
    print event.part.content
  when SimpleAcp::Models::RunCompletedEvent
    puts "\nDone!"
  end
end
```

---

### Run Management

#### #run_status

Get current status of a run.

```ruby
client.run_status(run_id)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `run_id` | `String` | Run ID |

**Returns:** `Models::Run`

---

#### #run_events

Get events for a run.

```ruby
client.run_events(run_id, limit: 100, offset: 0)
```

**Parameters:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `run_id` | `String` | required | Run ID |
| `limit` | `Integer` | `100` | Max events |
| `offset` | `Integer` | `0` | Skip count |

**Returns:** `Array<Event>`

---

#### #run_cancel

Cancel an in-progress run.

```ruby
client.run_cancel(run_id)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `run_id` | `String` | Run ID |

**Returns:** `Models::Run`

---

### Resume Methods

#### #run_resume_sync

Resume an awaiting run synchronously.

```ruby
client.run_resume_sync(run_id:, await_resume:)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `run_id` | `String` | Run to resume |
| `await_resume` | `AwaitResume` | Resume payload |

**Returns:** `Models::Run`

**Example:**

```ruby
run = client.run_resume_sync(
  run_id: run.run_id,
  await_resume: SimpleAcp::Models::MessageAwaitResume.new(
    message: SimpleAcp::Models::Message.user("My answer")
  )
)
```

---

#### #run_resume_stream

Resume an awaiting run with streaming.

```ruby
client.run_resume_stream(run_id:, await_resume:, &block)
```

**Parameters:** Same as `#run_resume_sync` plus event block

**Returns:** `Models::Run`

---

### Session Management

#### #use_session

Set the session for subsequent requests.

```ruby
client.use_session(session_id)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `session_id` | `String` | Session ID to use |

**Returns:** `self`

**Example:**

```ruby
client.use_session("conversation-123")
client.run_sync(agent: "chat", input: "Hello")
client.run_sync(agent: "chat", input: "Continue...")
```

---

#### #clear_session

Clear the current session.

```ruby
client.clear_session
```

**Returns:** `self`

---

#### #session_id

Get the current session ID.

```ruby
client.session_id
```

**Returns:** `String` or `nil`

---

#### #session

Get session information.

```ruby
client.session(session_id)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `session_id` | `String` | Session ID |

**Returns:** `Models::Session`

---

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `base_url` | `String` | Server URL |
| `timeout` | `Integer` | Request timeout |
| `session_id` | `String` | Current session |

---

## Error Handling

```ruby
begin
  run = client.run_sync(agent: "unknown", input: "test")
rescue SimpleAcp::Error => e
  puts "ACP Error: #{e.message}"
rescue Faraday::TimeoutError
  puts "Request timed out"
rescue Faraday::ConnectionFailed
  puts "Connection failed"
end
```

---

## See Also

- [Client Guide](../client/index.md)
- [Sync & Async](../client/sync-async.md)
- [Streaming](../client/streaming.md)
- [Sessions](../client/sessions.md)
