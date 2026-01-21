# frozen_string_literal: true

require "async"
require "async/http/endpoint"
require "falcon"
require "falcon/server"
require "falcon/adapters/rack"

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
        endpoint = Async::HTTP::Endpoint.parse(
          "http://#{host}:#{port}",
          protocol: Async::HTTP::Protocol::HTTP11
        )

        puts "ACP Server (Falcon) running on http://#{host}:#{port}"

        Async do |task|
          server = Falcon::Server.new(
            Falcon::Adapters::Rack.new(app),
            endpoint
          )

          task.async do
            server.run
          end

          # Handle interrupt for graceful shutdown
          task.async do
            trap("INT") do
              puts "\nShutting down..."
              task.stop
            end

            trap("TERM") do
              puts "\nShutting down..."
              task.stop
            end

            # Keep the main task alive
            sleep
          end
        end
      end
    end
  end
end
