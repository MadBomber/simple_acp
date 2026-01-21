# SimpleAcp Examples

> **CAUTION:** This project is under active development. The API and documentation may not necessarily reflect the current codebase.

This directory contains example programs demonstrating SimpleAcp features.

Each example is organized in its own subdirectory with both `server.rb` and `client.rb` files.

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

## Examples

### 01_basic

Basic server and client demonstrating core SimpleAcp functionality.

**Server** (`01_basic/server.rb`) - Registers five agents:

| Agent | Description |
|-------|-------------|
| `echo` | Echoes input messages back (demonstrates streaming with Enumerator) |
| `greeter` | Greets the user by name (demonstrates simple responses) |
| `counter` | Counts invocations (demonstrates session state) |
| `gettysburg` | Recites the Gettysburg Address word by word with 0.5s delay (demonstrates streaming) |
| `assistant` | Remembers conversation history (demonstrates multi-turn conversations) |

**Client** (`01_basic/client.rb`) - Demonstrates:

- Health check with `ping`
- Listing available agents
- Synchronous runs with `run_sync`
- Streaming responses with `run_stream`
- Session management for stateful interactions

**Usage:**

```bash
./examples/run_demo.sh 1
```

---

### 02_async_execution

Demonstrates asynchronous (non-blocking) execution patterns.

**Server** (`02_async_execution/server.rb`) - Registers:

| Agent | Description |
|-------|-------------|
| `slow-worker` | Simulates a 3-second task with progress updates |
| `quick-status` | Returns status immediately |

**Client** (`02_async_execution/client.rb`) - Demonstrates:

- Async execution with `run_async`
- Manual polling with `run_status`
- Waiting for completion with `wait_for_run`
- Running multiple tasks concurrently

**Usage:**

```bash
./examples/run_demo.sh 2
```

---

### 03_run_management

Demonstrates run lifecycle management including cancellation and event history.

**Server** (`03_run_management/server.rb`) - Registers:

| Agent | Description |
|-------|-------------|
| `cancellable-task` | A long-running task that checks for cancellation |
| `event-generator` | Generates multiple events for history tracking |

**Client** (`03_run_management/client.rb`) - Demonstrates:

- Cancelling a running task with `run_cancel`
- Checking `context.cancelled?` in the agent
- Retrieving event history with `run_events`
- Event pagination with limit and offset

**Usage:**

```bash
./examples/run_demo.sh 3
```

---

### 04_rich_messages

Demonstrates different message part types and content negotiation.

**Server** (`04_rich_messages/server.rb`) - Registers:

| Agent | Description |
|-------|-------------|
| `json-data` | Returns structured JSON data |
| `image-generator` | Generates SVG images as base64 |
| `link-provider` | Returns URL references with metadata |
| `multi-format` | Returns data in multiple formats (text, JSON, HTML) |

**Client** (`04_rich_messages/client.rb`) - Demonstrates:

- Receiving and parsing JSON content
- Handling base64 encoded data
- Working with URL references and metadata
- Multi-part messages with different content types
- Inspecting agent content type capabilities

**Usage:**

```bash
./examples/run_demo.sh 4
```

---

### 05_await_resume

Demonstrates the await/resume pattern for interactive multi-step flows.

**Server** (`05_await_resume/server.rb`) - Registers:

| Agent | Description |
|-------|-------------|
| `greeter` | Asks for your name, then greets you |
| `survey` | A multi-step survey collecting multiple pieces of information |
| `confirmer` | Asks for confirmation before performing an action |

**Client** (`05_await_resume/client.rb`) - Demonstrates:

- Detecting when a run is in "awaiting" status
- Resuming with `run_resume_sync`
- Multi-step interactive flows using state
- Confirmation dialogs
- Streaming resume with `run_resume_stream`

**Usage:**

```bash
./examples/run_demo.sh 5
```

---

### 06_agent_metadata

Demonstrates rich agent metadata and content type negotiation.

**Server** (`06_agent_metadata/server.rb`) - Registers:

| Agent | Description |
|-------|-------------|
| `text-analyzer` | Full-featured agent with comprehensive metadata |
| `simple-echo` | Minimal agent for comparison |
| `json-processor` | Agent with specific content type requirements |

**Client** (`06_agent_metadata/client.rb`) - Demonstrates:

- Retrieving full agent metadata with `agent(name)`
- Inspecting author, contributors, capabilities, links
- Content type negotiation (`accepts_content_type?`, `produces_content_type?`)
- Metadata fields: documentation, license, domains, tags, dependencies

**Usage:**

```bash
./examples/run_demo.sh 6
```

---

## Running Examples

### Using the Demo Runner (Recommended)

The `run_demo.sh` script handles starting the server, waiting for it to be ready, running the client, and cleanup:

```bash
# Run a specific demo by number
./examples/run_demo.sh 1

# List available demos
./examples/run_demo.sh --list

# Run all demos sequentially
./examples/run_demo.sh --all
```

The script can be executed from either the project root or from within the examples directory.

### Running Manually

You can also run server and client manually in separate terminals:

```bash
# Terminal 1: Start server
ruby examples/01_basic/server.rb

# Terminal 2: Run client
ruby examples/01_basic/client.rb
```

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
