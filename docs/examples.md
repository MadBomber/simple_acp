# Examples

!!! warning "CAUTION"
    This project is under active development. The API and documentation may not necessarily reflect the current codebase.

This section provides detailed documentation for the example programs demonstrating SimpleAcp features. Each example is organized in its own subdirectory with both `server.rb` and `client.rb` files.

## Quick Start

Use the unified `run_demo.sh` script to run any demo:

```bash
# From the project root
./examples/run_demo.sh 1      # Run demo 1 (01_basic)
./examples/run_demo.sh 4      # Run demo 4 (04_rich_messages)

# Or from the examples directory
cd examples
./run_demo.sh 1
```

### Available Commands

| Command | Description |
|---------|-------------|
| `./run_demo.sh <1-6>` | Run a specific demo by number |
| `./run_demo.sh --list` | List all available demos |
| `./run_demo.sh --all` | Run all demos sequentially |
| `./run_demo.sh --help` | Show usage information |

---

## 01_basic - Core Functionality

**Location:** [`examples/01_basic/`](https://github.com/MadBomber/simple_acp/tree/main/examples/01_basic)

This example demonstrates the fundamental features of SimpleAcp including agent registration, synchronous execution, streaming responses, and session-based state management.

### Server Agents

| Agent | Description | Key Features |
|-------|-------------|--------------|
| `echo` | Echoes input messages back | Streaming with Enumerator, multiple message parts |
| `greeter` | Greets the user by name | Simple single-response pattern |
| `counter` | Counts invocations | Session state persistence with `context.state` and `context.set_state` |
| `gettysburg` | Recites the Gettysburg Address word by word | Streaming with timed delays, fiber-aware sleep |
| `assistant` | Remembers conversation history | Multi-turn conversations, `context.history` access |

### Demonstrated Capabilities

**Agent Registration:**
```ruby
server = SimpleAcp::Server::Base.new

server.agent("greeter", description: "Greets the user by name") do |context|
  name = context.input.first&.text_content&.strip
  name = "World" if name.nil? || name.empty?
  SimpleAcp::Models::Message.agent("Hello, #{name}! Welcome to SimpleAcp.")
end
```

**Streaming Responses with Enumerator:**
```ruby
server.agent("echo", description: "Echoes everything you send") do |context|
  Enumerator.new do |yielder|
    context.input.each do |message|
      yielder << SimpleAcp::Server::RunYield.new(
        SimpleAcp::Models::Message.agent(message.text_content)
      )
    end
  end
end
```

**Session State Management:**
```ruby
server.agent("counter", description: "Counts how many times you've called it") do |context|
  count = (context.state || 0) + 1
  context.set_state(count)
  SimpleAcp::Models::Message.agent("You have called me #{count} time(s).")
end
```

### Client Operations

- Health check with `client.ping`
- Listing available agents with `client.agents`
- Synchronous runs with `client.run_sync`
- Streaming responses with `client.run_stream`
- Session management with `client.use_session` and `client.clear_session`

```ruby
client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")

# Synchronous execution
run = client.run_sync(agent: "greeter", input: "Ruby Developer")
puts run.output.first.text_content
# => "Hello, Ruby Developer! Welcome to SimpleAcp."

# Streaming execution
client.run_stream(agent: "gettysburg", input: "recite") do |event|
  case event
  when SimpleAcp::Models::MessagePartEvent
    print event.part.content
  when SimpleAcp::Models::RunCompletedEvent
    puts "\n[Streaming complete]"
  end
end
```

---

## 02_async_execution - Non-Blocking Execution

**Location:** [`examples/02_async_execution/`](https://github.com/MadBomber/simple_acp/tree/main/examples/02_async_execution)

This example demonstrates asynchronous (non-blocking) execution patterns for handling long-running tasks without blocking the client.

### Server Agents

| Agent | Description | Key Features |
|-------|-------------|--------------|
| `slow-worker` | Simulates a 3-second task | Progress updates, streaming with timed iterations |
| `quick-status` | Returns status immediately | Instant response for comparison |

### Demonstrated Capabilities

**Async Execution with Manual Polling:**
```ruby
# Start task asynchronously
run = client.run_async(agent: "slow-worker", input: "data analysis")
puts "Run started with ID: #{run.run_id}"

# Poll for status
loop do
  status = client.run_status(run.run_id)
  puts "Status: #{status.status}"
  break if status.terminal?
  sleep(0.5)
end
```

**Simplified Waiting with `wait_for_run`:**
```ruby
run = client.run_async(agent: "slow-worker", input: "report generation")
completed_run = client.wait_for_run(run.run_id, timeout: 10)

if completed_run.status == "completed"
  puts "Success!"
  completed_run.output.each { |msg| puts msg.text_content }
end
```

**Concurrent Task Execution:**
```ruby
# Start multiple tasks concurrently
runs = %w[task_alpha task_beta task_gamma].map do |task_name|
  client.run_async(agent: "slow-worker", input: task_name)
end

# Wait for all to complete
runs.each do |run|
  completed = client.wait_for_run(run.run_id, timeout: 15)
  puts "Completed: #{completed.output.last&.text_content}"
end
# All 3 tasks complete in ~3s (concurrent), not 9s (sequential)
```

### Key API Methods

| Method | Description |
|--------|-------------|
| `run_async` | Starts a run without blocking, returns immediately with run_id |
| `run_status` | Retrieves current status of a run by ID |
| `wait_for_run` | Blocks until run completes or timeout expires |
| `terminal?` | Checks if run status is terminal (completed, failed, cancelled) |

---

## 03_run_management - Lifecycle Control

**Location:** [`examples/03_run_management/`](https://github.com/MadBomber/simple_acp/tree/main/examples/03_run_management)

This example demonstrates run lifecycle management including cancellation and event history retrieval.

### Server Agents

| Agent | Description | Key Features |
|-------|-------------|--------------|
| `cancellable-task` | A long-running task (10 iterations) | Cancellation checking with `context.cancelled?` |
| `event-generator` | Generates multiple events | Event history tracking, configurable event count |

### Demonstrated Capabilities

**Run Cancellation:**
```ruby
# Server-side: Check for cancellation
server.agent("cancellable-task", description: "A cancellable task") do |context|
  Enumerator.new do |yielder|
    10.times do |i|
      if context.cancelled?
        yielder << SimpleAcp::Server::RunYield.new(
          SimpleAcp::Models::Message.agent("Task cancelled at iteration #{i + 1}")
        )
        break
      end
      # ... perform work ...
    end
  end
end

# Client-side: Cancel a running task
run = client.run_async(agent: "cancellable-task", input: "data processing")
sleep(1.5)  # Let it run for a bit
cancelled_run = client.run_cancel(run.run_id)
puts "Status: #{cancelled_run.status}"  # => "cancelled"
```

**Event History Retrieval:**
```ruby
run = client.run_sync(agent: "event-generator", input: "8")

# Get all events
events = client.run_events(run.run_id)
puts "Total events: #{events.length}"

# Group by event type
event_counts = events.group_by { |e| e.class.name.split("::").last }
event_counts.each { |type, evts| puts "#{type}: #{evts.length}" }
```

**Event Pagination:**
```ruby
# Page through events
page1 = client.run_events(run.run_id, limit: 5, offset: 0)
page2 = client.run_events(run.run_id, limit: 5, offset: 5)
page3 = client.run_events(run.run_id, limit: 5, offset: 10)
```

### Run States

| Status | Description |
|--------|-------------|
| `created` | Run has been created but not started |
| `in_progress` | Run is currently executing |
| `completed` | Run finished successfully |
| `failed` | Run encountered an error |
| `cancelled` | Run was cancelled by client |
| `awaiting` | Run is paused waiting for client input |

---

## 04_rich_messages - Content Types

**Location:** [`examples/04_rich_messages/`](https://github.com/MadBomber/simple_acp/tree/main/examples/04_rich_messages)

This example demonstrates different message part types and content negotiation for multimodal agent responses.

### Server Agents

| Agent | Description | Output Types |
|-------|-------------|--------------|
| `json-data` | Returns structured JSON data | `application/json`, `text/plain` |
| `image-generator` | Generates SVG images as base64 | `image/svg+xml`, `text/plain` |
| `link-provider` | Returns URL references with metadata | `text/uri-list`, `text/plain` |
| `multi-format` | Returns data in multiple formats | `application/json`, `text/plain`, `text/html` |

### Demonstrated Capabilities

**JSON Message Parts:**
```ruby
server.agent("json-data",
  description: "Returns structured JSON data",
  output_content_types: ["application/json", "text/plain"]
) do |context|
  data = {
    query: "users",
    count: 3,
    results: [
      { id: 1, name: "Alice", role: "admin" },
      { id: 2, name: "Bob", role: "user" }
    ]
  }

  SimpleAcp::Models::Message.new(
    role: "agent",
    parts: [
      SimpleAcp::Models::MessagePart.json(data),
      SimpleAcp::Models::MessagePart.text("Query returned #{data[:count]} results")
    ]
  )
end
```

**Base64 Encoded Binary Data:**
```ruby
server.agent("image-generator",
  description: "Generates a simple SVG image",
  output_content_types: ["image/svg+xml", "text/plain"]
) do |context|
  color = context.input.first&.text_content || "blue"

  svg = <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
      <rect width="100" height="100" fill="transparent"/>
      <circle cx="50" cy="50" r="40" fill="#{color}" opacity="0.8"/>
    </svg>
  SVG

  encoded = Base64.strict_encode64(svg)

  SimpleAcp::Models::Message.new(
    role: "agent",
    parts: [
      SimpleAcp::Models::MessagePart.new(
        kind: "data",
        content: encoded,
        content_type: "image/svg+xml"
      )
    ]
  )
end
```

**URL References with Metadata:**
```ruby
# Message part with metadata
SimpleAcp::Models::MessagePart.new(
  kind: "text",
  content: "Ruby Official Site: https://www.ruby-lang.org/",
  content_type: "text/plain",
  metadata: { url: "https://www.ruby-lang.org/", title: "Ruby Official Site" }
)
```

**Client-Side Content Type Handling:**
```ruby
run = client.run_sync(agent: "json-data", input: "users")

run.output.each do |message|
  message.parts.each do |part|
    case part.content_type
    when "application/json"
      data = JSON.parse(part.content)
      puts "Query: #{data['query']}, Count: #{data['count']}"
    when "text/plain"
      puts part.content
    when "image/svg+xml"
      svg = Base64.decode64(part.content)
      puts "SVG received: #{svg.length} bytes"
    end
  end
end
```

### Message Part Types

| Kind | Content Type | Usage |
|------|--------------|-------|
| `text` | `text/plain` | Plain text content |
| `text` | `text/html` | HTML formatted content |
| `text` | `text/markdown` | Markdown content |
| `data` | `application/json` | Structured JSON data |
| `data` | `image/*` | Base64 encoded images |
| `text` | `text/uri-list` | URL references |

---

## 05_await_resume - Interactive Flows

**Location:** [`examples/05_await_resume/`](https://github.com/MadBomber/simple_acp/tree/main/examples/05_await_resume)

This example demonstrates the await/resume pattern for building interactive multi-step agent flows that pause execution to request input from the client.

### Server Agents

| Agent | Description | Key Features |
|-------|-------------|--------------|
| `greeter` | Asks for your name, then greets you | Single await/resume cycle |
| `survey` | A multi-step survey | Multiple awaits with state tracking |
| `confirmer` | Asks for confirmation before action | Yes/no confirmation pattern |

### Demonstrated Capabilities

**Simple Await/Resume:**
```ruby
server.agent("greeter", description: "Asks for your name and greets you") do |context|
  if context.resume_message
    # Resume: we have the client's response
    name = context.resume_message.text_content
    SimpleAcp::Models::Message.agent("Hello, #{name}! Nice to meet you!")
  else
    # Initial call: ask for input
    context.await_message(
      SimpleAcp::Models::Message.agent("What is your name?")
    )
  end
end
```

**Multi-Step Wizard with State:**
```ruby
server.agent("survey", description: "A multi-step survey") do |context|
  survey_state = context.state || { step: 0, answers: {} }
  step = survey_state[:step]

  case step
  when 0
    context.set_state({ step: 1, answers: {} })
    context.await_message(
      SimpleAcp::Models::Message.agent("Question 1: What is your name?")
    )
  when 1
    answers = survey_state[:answers].merge("name" => context.resume_message&.text_content)
    context.set_state({ step: 2, answers: answers })
    context.await_message(
      SimpleAcp::Models::Message.agent("Question 2: What is your favorite color?")
    )
  when 2
    # Final step: return summary
    answers = survey_state[:answers].merge("color" => context.resume_message&.text_content)
    SimpleAcp::Models::Message.agent("Survey complete! Answers: #{answers}")
  end
end
```

**Confirmation Pattern:**
```ruby
server.agent("confirmer", description: "Performs action after confirmation") do |context|
  action = context.input.first&.text_content
  state = context.state || { confirmed: nil }

  if state[:confirmed].nil?
    context.set_state({ action: action, confirmed: false })
    context.await_message(
      SimpleAcp::Models::Message.agent("Are you sure you want to '#{action}'? (yes/no)")
    )
  else
    response = context.resume_message&.text_content&.downcase&.strip
    if %w[yes y sure ok].include?(response)
      SimpleAcp::Models::Message.agent("Action '#{state[:action]}' confirmed and executed!")
    else
      SimpleAcp::Models::Message.agent("Action '#{state[:action]}' cancelled.")
    end
  end
end
```

**Client-Side Await Handling:**
```ruby
# Detect awaiting status and resume
run = client.run_sync(agent: "greeter", input: "start")

if run.status == "awaiting"
  puts "Agent asks: #{run.await_request&.message&.text_content}"

  resume = SimpleAcp::Models::MessageAwaitResume.new(
    message: SimpleAcp::Models::Message.user("Alice")
  )

  completed_run = client.run_resume_sync(run_id: run.run_id, await_resume: resume)
  puts "Agent says: #{completed_run.output.last&.text_content}"
end
```

**Streaming Resume:**
```ruby
client.run_resume_stream(run_id: run.run_id, await_resume: resume) do |event|
  case event
  when SimpleAcp::Models::RunInProgressEvent
    print "[in_progress] "
  when SimpleAcp::Models::RunCompletedEvent
    puts "Final: #{event.run.output.last&.text_content}"
  end
end
```

### Key API Methods

| Method | Description |
|--------|-------------|
| `context.await_message` | Pauses execution and requests client input |
| `context.resume_message` | Access the client's response when resuming |
| `run.await_request` | Get the await request details from a paused run |
| `run_resume_sync` | Resume a paused run synchronously |
| `run_resume_stream` | Resume a paused run with streaming response |

---

## 06_agent_metadata - Rich Metadata

**Location:** [`examples/06_agent_metadata/`](https://github.com/MadBomber/simple_acp/tree/main/examples/06_agent_metadata)

This example demonstrates rich agent metadata including author information, capabilities, documentation, and content type negotiation.

### Server Agents

| Agent | Description | Metadata Level |
|-------|-------------|----------------|
| `text-analyzer` | Analyzes text for sentiment, keywords, summaries | Full metadata (author, capabilities, links, dependencies) |
| `simple-echo` | A simple echo agent | Minimal metadata |
| `json-processor` | Processes JSON input/output | Partial metadata (domains, tags) |

### Demonstrated Capabilities

**Full Agent Metadata:**
```ruby
metadata = SimpleAcp::Models::Metadata.new(
  documentation: "A comprehensive text analysis agent...",
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
    SimpleAcp::Models::Contributor.new(name: "Bob Contributor", email: "bob@example.com"),
    SimpleAcp::Models::Contributor.new(name: "Charlie Helper", url: "https://github.com/charliehelper")
  ],

  capabilities: [
    SimpleAcp::Models::Capability.new(name: "summarize", description: "Summarize long text"),
    SimpleAcp::Models::Capability.new(name: "sentiment", description: "Analyze sentiment"),
    SimpleAcp::Models::Capability.new(name: "keywords", description: "Extract keywords")
  ],

  domains: ["nlp", "text-analysis", "ai"],
  tags: ["text", "analysis", "nlp", "summarization"],

  links: [
    SimpleAcp::Models::Link.new(type: "documentation", url: "https://example.com/docs"),
    SimpleAcp::Models::Link.new(type: "source-code", url: "https://github.com/example/repo"),
    SimpleAcp::Models::Link.new(type: "homepage", url: "https://example.com")
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
  # Agent implementation...
end
```

**Client-Side Metadata Inspection:**
```ruby
agent = client.agent("text-analyzer")

puts "Agent: #{agent.name}"
puts "Description: #{agent.description}"

if agent.metadata
  meta = agent.metadata

  puts "Author: #{meta.author.name} (#{meta.author.email})"

  meta.capabilities.each do |cap|
    puts "Capability: #{cap.name} - #{cap.description}"
  end

  meta.links.each do |link|
    puts "Link: #{link.type} -> #{link.url}"
  end

  puts "Domains: #{meta.domains.join(', ')}"
  puts "Tags: #{meta.tags.join(', ')}"
end
```

**Content Type Negotiation:**
```ruby
agent = client.agent("text-analyzer")

# Check if agent accepts specific content types
agent.accepts_content_type?("text/plain")     # => true
agent.accepts_content_type?("text/markdown")  # => true
agent.accepts_content_type?("image/png")      # => false

# Check if agent produces specific content types
agent.produces_content_type?("application/json")  # => true
agent.produces_content_type?("text/html")         # => false
```

### Metadata Fields

| Field | Type | Description |
|-------|------|-------------|
| `documentation` | String | Detailed documentation text |
| `license` | String | License identifier (e.g., "MIT") |
| `programming_language` | String | Implementation language |
| `natural_languages` | Array | Supported human languages |
| `framework` | String | Framework used |
| `author` | Author | Primary author information |
| `contributors` | Array | List of contributors |
| `capabilities` | Array | Agent capabilities with descriptions |
| `domains` | Array | Domain categories |
| `tags` | Array | Searchable tags |
| `links` | Array | Related URLs |
| `dependencies` | Array | Required dependencies |
| `recommended_models` | Array | Suggested AI models |
| `created_at` | String | Creation timestamp |
| `updated_at` | String | Last update timestamp |

---

## Feature Coverage

| Feature | Example |
|---------|---------|
| Basic agent registration | 01_basic |
| Streaming responses | 01_basic |
| Session state | 01_basic |
| Conversation history | 01_basic |
| Async execution | 02_async_execution |
| Polling (`run_status`, `wait_for_run`) | 02_async_execution |
| Concurrent runs | 02_async_execution |
| Run cancellation | 03_run_management |
| Event history | 03_run_management |
| JSON message parts | 04_rich_messages |
| Binary/base64 data | 04_rich_messages |
| URL references | 04_rich_messages |
| Content type negotiation | 04_rich_messages, 06_agent_metadata |
| Await/resume pattern | 05_await_resume |
| Multi-step flows | 05_await_resume |
| Agent metadata | 06_agent_metadata |
| Author/contributor info | 06_agent_metadata |
| Capabilities and dependencies | 06_agent_metadata |

---

## Running Examples Manually

If you prefer to run server and client manually in separate terminals:

```bash
# Terminal 1: Start server
ruby examples/01_basic/server.rb

# Terminal 2: Run client
ruby examples/01_basic/client.rb
```

The `run_demo.sh` script handles starting the server, waiting for it to be ready, running the client, and cleanup automatically.
