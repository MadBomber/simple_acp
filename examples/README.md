# SimpleAcp Examples

This directory contains example programs demonstrating SimpleAcp features.

Each example is organized in its own subdirectory with both `server.rb` and `client.rb` files.

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
# Option 1: Run both with the shell script
./examples/01_basic.sh

# Option 2: Run manually in separate terminals
# Terminal 1: Start the server
ruby examples/01_basic/server.rb

# Terminal 2: Run the client
ruby examples/01_basic/client.rb
```

**Expected Output:**

Server:
```
Starting SimpleAcp Server...
Available agents:
  - echo: Echoes everything you send
  - greeter: Greets the user by name
  - counter: Counts how many times you've called it
  - gettysburg: Recites the Gettysburg Address word by word
  - assistant: A simple assistant that remembers conversation history
```

Client:
```
=== SimpleAcp Client Example ===

✓ Server is healthy

Available agents:
  - echo: Echoes everything you send
  - greeter: Greets the user by name
  - counter: Counts how many times you've called it
  - gettysburg: Recites the Gettysburg Address word by word
  - assistant: A simple assistant that remembers conversation history

--- Testing echo agent ---
Input: Hello, SimpleAcp!
Output: Hello, SimpleAcp!

--- Testing greeter agent ---
Input: Ruby Developer
Output: Hello, Ruby Developer! Welcome to SimpleAcp.

--- Testing counter agent with session ---
Call 1: You have called me 1 time(s).
Call 2: You have called me 2 time(s).
Call 3: You have called me 3 time(s).

--- Testing streaming (Gettysburg Address) ---

  Four score and seven years ago... [words stream one at a time with 0.5s delay]
  ...government of the people, by the people, for the people, shall not perish from the earth.

[Streaming complete]

--- Testing assistant with history ---
User: Hi!
Agent: Hello! This is our first conversation. How can I help you?

User: Tell me more
Agent: I see we've had 2 previous messages. What else can I help with?

User: Thanks!
Agent: I see we've had 4 previous messages. What else can I help with?

=== All tests completed ===
```
