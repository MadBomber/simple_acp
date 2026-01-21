# Models

Data models for ACP entities.

## Message

Represents a message in the protocol.

### Class: SimpleAcp::Models::Message

#### Factory Methods

```ruby
# Create user message
Message.user(*parts)
Message.user("text")
Message.user(MessagePart.text("text"), MessagePart.json({...}))

# Create agent message
Message.agent(*parts)
Message.agent("response")

# From hash
Message.from_hash({ "role" => "user", "parts" => [...] })
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `role` | `String` | `"user"` or `"agent"` |
| `parts` | `Array<MessagePart>` | Content parts |

#### Instance Methods

```ruby
message.text_content    # Combined text from all parts
message.to_h            # Convert to hash
message.to_json         # Convert to JSON
```

---

## MessagePart

Content within a message.

### Class: SimpleAcp::Models::MessagePart

#### Factory Methods

```ruby
# Text content
MessagePart.text("Hello")

# JSON content
MessagePart.json({ key: "value" })

# Image content (base64)
MessagePart.image(base64_data, mime_type: "image/png")

# URL reference
MessagePart.from_url("https://...", content_type: "image/jpeg")
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `content_type` | `String` | MIME type |
| `content` | `String` | Inline content |
| `content_url` | `String` | URL reference |
| `content_encoding` | `String` | `"plain"` or `"base64"` |

#### Instance Methods

```ruby
part.text?     # Is text/plain?
part.json?     # Is application/json?
part.image?    # Is image/*?
part.to_h      # Convert to hash
part.to_json   # Convert to JSON
```

---

## Run

Represents an agent execution.

### Class: SimpleAcp::Models::Run

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `run_id` | `String` | Unique identifier (UUID) |
| `agent_name` | `String` | Agent that executed |
| `session_id` | `String` | Associated session |
| `status` | `String` | Current status |
| `output` | `Array<Message>` | Output messages |
| `error` | `Error` | Error if failed |
| `await_request` | `AwaitRequest` | Await details |
| `created_at` | `Time` | Creation time |
| `finished_at` | `Time` | Completion time |

#### Status Values

- `created` - Run created, not started
- `in_progress` - Currently executing
- `completed` - Finished successfully
- `failed` - Encountered error
- `awaiting` - Waiting for input
- `cancelled` - Cancelled by request

#### Instance Methods

```ruby
run.terminal?     # Is in final state?
run.completed?    # Status is "completed"?
run.failed?       # Status is "failed"?
run.cancelled?    # Status is "cancelled"?
run.awaiting?     # Status is "awaiting"?
run.to_h          # Convert to hash
run.to_json       # Convert to JSON
```

---

## Session

Maintains state across runs.

### Class: SimpleAcp::Models::Session

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Unique identifier |
| `history` | `Array<Message>` | Conversation history |
| `state` | `Any` | Custom state data |

#### Instance Methods

```ruby
session.add_messages(messages)  # Append to history
session.to_h                    # Convert to hash
session.to_json                 # Convert to JSON
```

---

## AgentManifest

Agent metadata and capabilities.

### Class: SimpleAcp::Models::AgentManifest

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Agent name |
| `description` | `String` | Human-readable description |
| `input_content_types` | `Array<String>` | Accepted MIME types |
| `output_content_types` | `Array<String>` | Produced MIME types |
| `metadata` | `Hash` | Custom metadata |

---

## Error

Error information.

### Class: SimpleAcp::Models::Error

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `code` | `String` | Error code |
| `message` | `String` | Error message |

---

## Events

Event types for streaming.

### Event Classes

| Class | Type | Description |
|-------|------|-------------|
| `RunStartedEvent` | `run_started` | Run began |
| `MessageCreatedEvent` | `message_created` | New message |
| `MessagePartEvent` | `message_part` | Message chunk |
| `MessageCompletedEvent` | `message_completed` | Message done |
| `RunCompletedEvent` | `run_completed` | Run finished |
| `RunFailedEvent` | `run_failed` | Run errored |
| `RunAwaitingEvent` | `run_awaiting` | Awaiting input |

### Event Properties

```ruby
# All events
event.type      # Event type string

# RunStartedEvent
event.run_id    # Run ID

# MessageCreatedEvent, MessageCompletedEvent
event.message   # Message object

# MessagePartEvent
event.part      # MessagePart object

# RunCompletedEvent, RunFailedEvent, RunAwaitingEvent
event.run       # Run object

# RunFailedEvent
event.error     # Error object

# RunAwaitingEvent
event.await_request  # AwaitRequest object
```

### Parsing Events

```ruby
event = SimpleAcp::Models::Events.from_hash({
  "type" => "message_part",
  "part" => { "content_type" => "text/plain", "content" => "Hello" }
})
```

---

## Await Types

### AwaitRequest

Request for additional input.

```ruby
await_request.type     # "message"
await_request.message  # Prompt message
```

### AwaitResume

Resume payload types.

```ruby
# Message resume
resume = SimpleAcp::Models::MessageAwaitResume.new(
  message: SimpleAcp::Models::Message.user("response")
)
resume.type     # "message"
resume.message  # Message object
```

---

## Base Model

All models inherit from `SimpleAcp::Models::Base`.

### Common Methods

```ruby
model.to_h      # Convert to hash
model.to_json   # Convert to JSON string

# Class methods
Model.from_hash(hash)  # Create from hash
```

---

## See Also

- [Messages](../core-concepts/messages.md)
- [Runs](../core-concepts/runs.md)
- [Sessions](../core-concepts/sessions.md)
- [Events](../core-concepts/events.md)
