# Installation

## Requirements

- Ruby 3.0 or later
- Bundler (recommended)

## Basic Installation

### Using Bundler (Recommended)

Add SimpleAcp to your `Gemfile`:

```ruby
gem 'simple_acp'
```

Then install dependencies:

```bash
bundle install
```

### Direct Installation

Install the gem directly:

```bash
gem install simple_acp
```

## Optional Dependencies

SimpleAcp has optional dependencies for different storage backends:

### Redis Storage

For distributed deployments with Redis:

```ruby
gem 'simple_acp'
gem 'redis', '~> 5.0'
```

### PostgreSQL Storage

For persistent storage with PostgreSQL:

```ruby
gem 'simple_acp'
gem 'sequel', '~> 5.0'
gem 'pg', '~> 1.5'
```

## Verifying Installation

Create a simple test file to verify the installation:

```ruby
# test_install.rb
require 'simple_acp'

server = SimpleAcp::Server::Base.new

server.agent("test") do |context|
  SimpleAcp::Models::Message.agent("SimpleAcp is working!")
end

puts "SimpleAcp version: #{SimpleAcp::VERSION}"
puts "Registered agents: #{server.agents.keys.join(', ')}"
```

Run it:

```bash
ruby test_install.rb
# SimpleAcp version: 0.1.0
# Registered agents: test
```

## Dependencies

SimpleAcp depends on these gems (automatically installed):

| Gem | Purpose |
|-----|---------|
| `roda` | HTTP routing and request handling |
| `falcon` | Fiber-based web server for efficient concurrency |
| `async` | Asynchronous I/O framework |
| `faraday` | HTTP client for agent clients |
| `concurrent-ruby` | Thread-safe data structures |

## Next Steps

Now that you have SimpleAcp installed, proceed to the [Quick Start](quick-start.md) guide to create your first agent.
