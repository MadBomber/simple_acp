# Messages

Messages are the fundamental unit of communication in ACP. They carry content between users and agents.

## Message Structure

Every message has two essential properties:

- **role**: Either `"user"` or `"agent"`
- **parts**: An array of content parts

```ruby
message = SimpleAcp::Models::Message.new(
  role: "user",
  parts: [
    SimpleAcp::Models::MessagePart.text("Hello!")
  ]
)
```

## Creating Messages

### Factory Methods

The simplest way to create messages:

```ruby
# User message with text
user_msg = SimpleAcp::Models::Message.user("What's the weather?")

# Agent message with text
agent_msg = SimpleAcp::Models::Message.agent("It's sunny and 72°F")
```

### Multiple Parts

Messages can contain multiple content parts:

```ruby
message = SimpleAcp::Models::Message.user(
  SimpleAcp::Models::MessagePart.text("Here's my data:"),
  SimpleAcp::Models::MessagePart.json({ values: [1, 2, 3] })
)
```

### From Hash

Parse messages from JSON/hash data:

```ruby
message = SimpleAcp::Models::Message.from_hash({
  "role" => "user",
  "parts" => [
    { "content_type" => "text/plain", "content" => "Hello" }
  ]
})
```

## Message Parts

Each part has a content type and content payload.

### Text Content

Plain text is the most common content type:

```ruby
part = SimpleAcp::Models::MessagePart.text("Hello, world!")

part.content_type  # => "text/plain"
part.content       # => "Hello, world!"
part.text?         # => true
```

### JSON Content

Structured data as JSON:

```ruby
part = SimpleAcp::Models::MessagePart.json({
  temperature: 72,
  conditions: "sunny",
  humidity: 45
})

part.content_type  # => "application/json"
part.content       # => "{\"temperature\":72,...}"
part.json?         # => true
```

### Image Content

Base64-encoded images:

```ruby
image_data = File.read("photo.png")
part = SimpleAcp::Models::MessagePart.image(
  Base64.strict_encode64(image_data),
  mime_type: "image/png"
)

part.content_type      # => "image/png"
part.content_encoding  # => "base64"
part.image?            # => true
```

### URL References

Reference external content by URL:

```ruby
part = SimpleAcp::Models::MessagePart.from_url(
  "https://example.com/image.jpg",
  content_type: "image/jpeg"
)

part.content_url  # => "https://example.com/image.jpg"
```

## Accessing Content

### Text Content

Get combined text from all parts:

```ruby
message = SimpleAcp::Models::Message.user(
  SimpleAcp::Models::MessagePart.text("Hello "),
  SimpleAcp::Models::MessagePart.text("World!")
)

message.text_content  # => "Hello World!"
```

### Individual Parts

Access parts directly:

```ruby
message.parts.each do |part|
  puts "Type: #{part.content_type}"
  puts "Content: #{part.content}"
end
```

### Type Checking

Check content types:

```ruby
part.text?   # Is text/plain?
part.json?   # Is application/json?
part.image?  # Is image/*?
```

## Serialization

Messages can be serialized to JSON:

```ruby
message = SimpleAcp::Models::Message.user("Hello")

# To hash
hash = message.to_h
# => { role: "user", parts: [...] }

# To JSON
json = message.to_json
# => '{"role":"user","parts":[...]}'
```

## Common Patterns

### Echo Agent

```ruby
server.agent("echo") do |context|
  context.input.map do |msg|
    SimpleAcp::Models::Message.agent(msg.text_content)
  end
end
```

### Transform Content

```ruby
server.agent("uppercase") do |context|
  text = context.input.first&.text_content || ""
  SimpleAcp::Models::Message.agent(text.upcase)
end
```

### Multi-Part Response

```ruby
server.agent("analysis") do |context|
  SimpleAcp::Models::Message.agent(
    SimpleAcp::Models::MessagePart.text("Analysis complete:"),
    SimpleAcp::Models::MessagePart.json({
      word_count: 150,
      sentiment: "positive"
    })
  )
end
```

## Next Steps

- Learn about [Agents](agents.md) that process messages
- Understand [Runs](runs.md) that execute agent logic
- Explore [Events](events.md) for streaming message delivery
