# frozen_string_literal: true

require_relative "lib/simple_acp/version"

Gem::Specification.new do |spec|
  spec.name = "simple_acp"
  spec.version = SimpleAcp::VERSION
  spec.authors = ["Dewayne VanHoozer"]
  spec.email = ["dvanhoozer@gmail.com"]

  spec.summary = "Simple Agent Communication Protocol (ACP) implementation for Ruby"
  spec.description = "A simple Ruby implementation of the Agent Communication Protocol (ACP) - " \
                     "an open protocol for communication between AI agents, applications, and humans. " \
                     "Supports multimodal messages, real-time streaming, agent discovery, and stateful sessions."
  spec.homepage = "https://github.com/madbomber/simple_acp"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # HTTP Server - Falcon with Async ecosystem
  spec.add_dependency "roda", "~> 3.0"
  spec.add_dependency "falcon", "~> 0.47"
  spec.add_dependency "async", "~> 2.0"
  spec.add_dependency "async-http", "~> 0.66"

  # HTTP Client
  spec.add_dependency "faraday", "~> 2.0"

  # Concurrency & Thread Safety
  spec.add_dependency "concurrent-ruby", "~> 1.2"

  # JSON Schema validation
  spec.add_dependency "json_schemer", "~> 2.0"

  # Base64 encoding (required in Ruby 3.4+)
  spec.add_dependency "base64"
  spec.add_dependency "uri"

  # Optional storage backends (as development dependencies for testing)
  spec.add_development_dependency "redis", "~> 5.0"
  spec.add_development_dependency "pg", "~> 1.5"
  spec.add_development_dependency "sequel", "~> 5.0"

  # Development & Testing
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "debug_me"
  spec.add_development_dependency "aigcm"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-reporters", "~> 1.6"
  spec.add_development_dependency "rack-test", "~> 2.0"
  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
end
