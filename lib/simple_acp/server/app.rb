# frozen_string_literal: true

require "roda"
require "json"

module SimpleAcp
  module Server
    # Roda application implementing ACP HTTP endpoints.
    #
    # Provides REST endpoints for agent discovery, run management,
    # and session handling. Supports sync, async, and streaming modes.
    #
    # == Endpoints
    #
    # - GET /ping - Health check
    # - GET /agents - List agents
    # - GET /agents/:name - Get agent manifest
    # - POST /runs - Create a run
    # - GET /runs/:id - Get run status
    # - POST /runs/:id - Resume awaited run
    # - POST /runs/:id/cancel - Cancel run
    # - GET /runs/:id/events - Get run events
    # - GET /session/:id - Get session info
    class App < Roda
      plugin :json
      plugin :json_parser
      plugin :all_verbs
      plugin :halt

      # Configure the Roda app with a server instance.
      #
      # @param server [Server::Base] the server to handle requests
      # @return [void]
      def self.configure(server)
        @server = server
      end

      # Get the configured server instance.
      #
      # @return [Server::Base] the server
      def self.server
        @server
      end

      route do |r|
        response["Content-Type"] = "application/json"

        # Health check
        r.get "ping" do
          { status: "ok" }
        end

        # List agents
        r.get "agents" do
          limit = (r.params["limit"] || 10).to_i.clamp(1, 1000)
          offset = (r.params["offset"] || 0).to_i

          agents = self.class.server.agents.values
          total = agents.length
          agents = agents.drop(offset).take(limit)

          {
            agents: agents.map { |a| a.manifest.to_h },
            total: total,
            limit: limit,
            offset: offset
          }
        end

        # Get specific agent
        r.get "agents", String do |name|
          agent = self.class.server.agents[name]
          unless agent
            response.status = 404
            r.halt({ error: Models::Error.not_found("Agent '#{name}' not found").to_h })
          end
          agent.manifest.to_h
        end

        # Runs endpoints
        r.on "runs" do
          # Create a new run (only matches POST /runs with no path segment)
          r.is do
            r.post do
            body = r.params
            request = Models::RunCreateRequest.from_hash(body)

            unless request&.valid?
              response.status = 400
              r.halt({ error: Models::Error.invalid_input("Invalid run request").to_h })
            end

            mode = request.mode || Models::Types::RunMode::SYNC

            begin
              case mode
              when Models::Types::RunMode::SYNC
                run = self.class.server.run_sync(
                  agent_name: request.agent_name,
                  input: request.input,
                  session_id: request.session_id,
                  session: request.session
                )
                run.to_h
              when Models::Types::RunMode::ASYNC
                run = self.class.server.run_async(
                  agent_name: request.agent_name,
                  input: request.input,
                  session_id: request.session_id,
                  session: request.session
                )
                run.to_h
              when Models::Types::RunMode::STREAM
                headers = {
                  "Content-Type" => "text/event-stream",
                  "Cache-Control" => "no-cache",
                  "Connection" => "keep-alive",
                  "X-Accel-Buffering" => "no"
                }

                server_instance = self.class.server
                req = request

                body = proc do |stream|
                  begin
                    server_instance.run_stream(
                      agent_name: req.agent_name,
                      input: req.input,
                      session_id: req.session_id,
                      session: req.session
                    ) do |event|
                      stream.write(event.sse_format)
                    end
                  rescue => error
                    SimpleAcp.logger&.error("Stream error: #{error.message}")
                  ensure
                    stream.close rescue nil
                  end
                end

                r.halt [200, headers, body]
              else
                response.status = 400
                r.halt({ error: Models::Error.invalid_input("Invalid mode: #{mode}").to_h })
              end
            rescue SimpleAcp::NotFoundError => e
              response.status = 404
              r.halt({ error: Models::Error.not_found(e.message).to_h })
            rescue StandardError => e
              response.status = 500
              r.halt({ error: Models::Error.server_error(e.message).to_h })
            end
            end
          end

          r.on String do |run_id|
            # Cancel a run (must come before r.is to match /cancel path)
            r.post "cancel" do
              begin
                run = self.class.server.cancel_run(run_id)
                run.to_h
              rescue SimpleAcp::NotFoundError => e
                response.status = 404
                r.halt({ error: Models::Error.not_found(e.message).to_h })
              end
            end

            # Get run events (must come before r.is to match /events path)
            r.get "events" do
              limit = (r.params["limit"] || 100).to_i.clamp(1, 1000)
              offset = (r.params["offset"] || 0).to_i

              events = self.class.server.storage.get_events(run_id, limit: limit, offset: offset)
              { events: events.map(&:to_h) }
            end

            # Get run status or resume run (matches exactly /runs/:id)
            r.is do
              r.get do
                run = self.class.server.storage.get_run(run_id)
                unless run
                  response.status = 404
                  r.halt({ error: Models::Error.not_found("Run '#{run_id}' not found").to_h })
                end
                run.to_h
              end

              # Resume a paused run
              r.post do
              body = r.params
              request = Models::RunResumeRequest.from_hash(body.merge("run_id" => run_id))

              unless request&.valid?
                response.status = 400
                r.halt({ error: Models::Error.invalid_input("Invalid resume request").to_h })
              end

              mode = request.mode

              begin
                case mode
                when Models::Types::RunMode::SYNC
                  run = self.class.server.resume_sync(
                    run_id: run_id,
                    await_resume: request.await_resume
                  )
                  run.to_h
                when Models::Types::RunMode::STREAM
                  headers = {
                    "Content-Type" => "text/event-stream",
                    "Cache-Control" => "no-cache",
                    "Connection" => "keep-alive",
                    "X-Accel-Buffering" => "no"
                  }

                  server_instance = self.class.server
                  req = request
                  rid = run_id

                  body = proc do |stream|
                    begin
                      server_instance.resume_stream(
                        run_id: rid,
                        await_resume: req.await_resume
                      ) do |event|
                        stream.write(event.sse_format)
                      end
                    rescue => error
                      SimpleAcp.logger&.error("Resume stream error: #{error.message}")
                    ensure
                      stream.close rescue nil
                    end
                  end

                  r.halt [200, headers, body]
                else
                  response.status = 400
                  r.halt({ error: Models::Error.invalid_input("Invalid mode: #{mode}").to_h })
                end
              rescue SimpleAcp::NotFoundError => e
                response.status = 404
                r.halt({ error: Models::Error.not_found(e.message).to_h })
              rescue StandardError => e
                response.status = 500
                r.halt({ error: Models::Error.server_error(e.message).to_h })
              end
              end
            end
          end
        end

        # Session endpoint
        r.get "session", String do |session_id|
          session = self.class.server.storage.get_session(session_id)
          unless session
            response.status = 404
            r.halt({ error: Models::Error.not_found("Session '#{session_id}' not found").to_h })
          end
          Models::SessionResponse.from_session(session).to_h
        end
      end
    end
  end
end
