# frozen_string_literal: true

module SimpleAcp
  module Server
    # Request context passed to agent handlers
    class Context
      attr_reader :run, :session, :input, :server

      def initialize(run:, session:, input:, server:)
        @run = run
        @session = session
        @input = input
        @server = server
        @cancelled = false
      end

      def agent_name
        @run.agent_name
      end

      def run_id
        @run.run_id
      end

      def session_id
        @session&.id
      end

      def cancelled?
        @cancelled
      end

      def cancel!
        @cancelled = true
      end

      # Get history from session
      def history
        @session&.history || []
      end

      # Get state from session
      def state
        @session&.state
      end

      # Update session state
      def set_state(new_state)
        @session&.set_state(new_state)
        @server.storage.save_session(@session) if @session
      end

      # Request additional input from the client
      def await_message(prompt_message)
        request = Models::MessageAwaitRequest.new(message: prompt_message)
        @run.await!(request)
        @server.storage.save_run(@run)

        # Return a result that indicates the run is awaiting
        RunYieldAwait.new(request: request)
      end

      # Log a message (for trajectory tracking)
      def log(message)
        Acp.logger&.info("[#{agent_name}] #{message}")
      end
    end

    # Yield types for agent generators

    # Standard yield - outputs a message
    class RunYield
      attr_reader :message

      def initialize(message)
        @message = message.is_a?(Models::Message) ? message : Models::Message.from_hash(message)
      end
    end

    # Await yield - pauses execution waiting for client input
    class RunYieldAwait
      attr_reader :request

      def initialize(request:)
        @request = request
      end
    end

    # Resume context when continuing an awaited run
    class ResumeContext < Context
      attr_reader :await_resume

      def initialize(run:, session:, input:, server:, await_resume:)
        super(run: run, session: session, input: input, server: server)
        @await_resume = await_resume
      end

      def resume_message
        @await_resume&.message
      end
    end
  end
end
