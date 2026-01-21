# Sync & Async Execution

SimpleAcp supports both synchronous and asynchronous execution patterns for different use cases.

## Synchronous Execution

### Basic Usage

Wait for the run to complete:

```ruby
run = client.run_sync(
  agent: "echo",
  input: [SimpleAcp::Models::Message.user("Hello")]
)

puts run.status      # => "completed"
puts run.output      # => [Message, ...]
```

### With Session

```ruby
client.use_session("conversation-123")

run = client.run_sync(
  agent: "chat",
  input: [SimpleAcp::Models::Message.user("Hello")]
)
```

### Handling Results

```ruby
run = client.run_sync(agent: "processor", input: [...])

case run.status
when "completed"
  run.output.each do |message|
    puts message.text_content
  end
when "failed"
  puts "Error code: #{run.error.code}"
  puts "Error message: #{run.error.message}"
when "awaiting"
  puts "Agent needs more input:"
  puts run.await_request.message.text_content
  # Handle await...
end
```

### When to Use Sync

- Quick operations (< few seconds)
- Simple request-response patterns
- When you need the result immediately
- CLI tools and scripts

## Asynchronous Execution

### Basic Usage

Start a run without waiting:

```ruby
run = client.run_async(
  agent: "slow-processor",
  input: [SimpleAcp::Models::Message.user("Large dataset")]
)

puts "Run started: #{run.run_id}"
puts "Status: #{run.status}"  # => "in_progress"
```

### Polling for Completion

```ruby
run = client.run_async(agent: "processor", input: [...])

# Poll until complete
loop do
  run = client.run_status(run.run_id)

  puts "Status: #{run.status}"

  break if run.terminal?
  sleep 2
end

# Process results
puts run.output if run.completed?
puts run.error if run.failed?
```

### With Timeout

```ruby
run = client.run_async(agent: "processor", input: [...])
timeout = Time.now + 300  # 5 minutes

loop do
  run = client.run_status(run.run_id)
  break if run.terminal?

  if Time.now > timeout
    client.run_cancel(run.run_id)
    raise "Operation timed out"
  end

  sleep 2
end
```

### When to Use Async

- Long-running operations
- Background processing
- When you can poll for results
- Fire-and-forget patterns

## Comparison

| Aspect | Synchronous | Asynchronous |
|--------|-------------|--------------|
| Blocking | Yes | No |
| Response time | Waits for completion | Immediate |
| Use case | Quick operations | Long operations |
| Error handling | Inline | Via polling |

## Helper Patterns

### Sync Wrapper for Async

```ruby
def run_with_timeout(client, agent:, input:, timeout: 60)
  run = client.run_async(agent: agent, input: input)
  deadline = Time.now + timeout

  loop do
    run = client.run_status(run.run_id)
    return run if run.terminal?

    if Time.now > deadline
      client.run_cancel(run.run_id)
      raise "Timeout waiting for run"
    end

    sleep 1
  end
end
```

### Async with Callback

```ruby
def run_async_with_callback(client, agent:, input:, &block)
  Thread.new do
    run = client.run_async(agent: agent, input: input)

    loop do
      run = client.run_status(run.run_id)
      break if run.terminal?
      sleep 1
    end

    block.call(run)
  end
end

# Usage
run_async_with_callback(client, agent: "processor", input: [...]) do |run|
  puts "Completed: #{run.output}"
end

puts "Continuing while processing..."
```

### Batch Async Execution

```ruby
def run_batch(client, jobs)
  # Start all jobs
  runs = jobs.map do |job|
    client.run_async(
      agent: job[:agent],
      input: job[:input]
    )
  end

  # Wait for all to complete
  completed = []

  until runs.empty?
    runs.each do |run|
      updated = client.run_status(run.run_id)
      if updated.terminal?
        completed << updated
        runs.delete(run)
      end
    end
    sleep 1 unless runs.empty?
  end

  completed
end

# Usage
results = run_batch(client, [
  { agent: "processor", input: [...] },
  { agent: "analyzer", input: [...] },
  { agent: "formatter", input: [...] }
])
```

## Resuming Awaited Runs

Both sync and async support resuming:

### Sync Resume

```ruby
run = client.run_sync(agent: "questioner", input: [...])

if run.awaiting?
  puts run.await_request.message.text_content

  run = client.run_resume_sync(
    run_id: run.run_id,
    await_resume: SimpleAcp::Models::MessageAwaitResume.new(
      message: SimpleAcp::Models::Message.user("My answer")
    )
  )
end
```

### Async Resume

```ruby
run = client.run_async(agent: "questioner", input: [...])

# ... later

run = client.run_status(run.run_id)

if run.awaiting?
  # Resume asynchronously
  run = client.run_async(
    run_id: run.run_id,
    await_resume: SimpleAcp::Models::MessageAwaitResume.new(
      message: SimpleAcp::Models::Message.user("Answer")
    )
  )
end
```

## Error Handling

### Sync Errors

```ruby
begin
  run = client.run_sync(agent: "processor", input: [...])

  if run.failed?
    handle_error(run.error)
  end
rescue Faraday::TimeoutError
  puts "Request timed out"
rescue Faraday::ConnectionFailed
  puts "Connection failed"
end
```

### Async Errors

```ruby
run = client.run_async(agent: "processor", input: [...])

begin
  loop do
    run = client.run_status(run.run_id)
    break if run.terminal?
    sleep 1
  end
rescue => e
  # Try to cancel on error
  client.run_cancel(run.run_id) rescue nil
  raise e
end

if run.failed?
  handle_error(run.error)
end
```

## Best Practices

1. **Choose wisely** - Use sync for quick ops, async for long ones
2. **Set timeouts** - Always have a maximum wait time
3. **Handle all states** - Check for completed, failed, awaiting, cancelled
4. **Cancel on error** - Clean up in-progress runs when errors occur
5. **Poll appropriately** - Don't poll too frequently (1-2 second intervals)

## Next Steps

- Learn about [Streaming](streaming.md) for real-time updates
- Explore [Session Management](sessions.md)
- See [Events](../core-concepts/events.md) for event details
