# frozen_string_literal: true

require "async"
require "falcon"
require "falcon/server"
require "protocol/rack"
require "io/endpoint"
require "io/endpoint/address_endpoint"

module SimpleAcp
  module Server
    # Falcon-based server runner using fiber concurrency.
    #
    # Provides efficient handling of SSE streams and long-lived
    # connections through Async's fiber scheduler.
    #
    # @example Starting a server
    #   app = server.to_app
    #   FalconRunner.run(app, port: 8000)
    module FalconRunner
      # Start the server using Falcon.
      #
      # @param app [#call] the Rack application
      # @param port [Integer] port to bind to (default: 8000)
      # @param host [String] host to bind to (default: "0.0.0.0")
      # @param options [Hash] additional options
      # @option options [Integer] :count number of worker processes
      # @return [void]
      def self.run(app, port: 8000, host: "0.0.0.0", **options)
        endpoint = IO::Endpoint::AddressEndpoint.new(Addrinfo.tcp(host, port))

        puts "ACP Server (Falcon) running on http://#{host}:#{port}"

        server_task = nil

        # Handle interrupt for graceful shutdown
        trap("INT") do
          puts "\nShutting down..."
          Thread.main.raise(Interrupt)
        end

        trap("TERM") do
          puts "\nShutting down..."
          Thread.main.raise(Interrupt)
        end

        begin
          Sync do |task|
            rack_app = Protocol::Rack::Adapter.new(app)
            server = Falcon::Server.new(rack_app, endpoint, protocol: Async::HTTP::Protocol::HTTP1, scheme: "http")

            server_task = server.run
            server_task.wait
          end
        rescue Interrupt
          # Graceful shutdown
        end
      end
    end
  end
end
