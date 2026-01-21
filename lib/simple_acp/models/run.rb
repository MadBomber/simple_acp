# frozen_string_literal: true

module SimpleAcp
  module Models
    # Represents a single agent execution.
    #
    # Tracks the lifecycle of an agent run from creation through completion,
    # including status, output messages, errors, and timing.
    #
    # == Status Lifecycle
    #
    # - created -> in_progress -> completed | failed | cancelled | awaiting
    # - awaiting -> in_progress (on resume)
    # - cancelling -> cancelled
    class Run < Base
      # @!attribute [r] run_id
      #   @return [String] unique UUID for this run
      attribute :run_id, required: true

      # @!attribute [r] agent_name
      #   @return [String] name of the agent being executed
      attribute :agent_name, required: true

      # @!attribute [r] session_id
      #   @return [String, nil] optional session ID
      attribute :session_id

      # @!attribute [r] status
      #   @return [String] current status (created, in-progress, completed, failed, cancelled, awaiting)
      attribute :status, default: Types::RunStatus::CREATED

      # @!attribute [r] await_request
      #   @return [AwaitRequest, nil] request for client input (when awaiting)
      attribute :await_request

      # @!attribute [r] output
      #   @return [Array<Message>] output messages from the agent
      attribute :output, default: -> { [] }

      # @!attribute [r] error
      #   @return [Error, nil] error details if failed
      attribute :error

      # @!attribute [r] created_at
      #   @return [Time, nil] when the run was created
      attribute :created_at

      # @!attribute [r] finished_at
      #   @return [Time, nil] when the run finished (completed, failed, or cancelled)
      attribute :finished_at

      def initialize(**kwargs)
        super
        @run_id ||= Types.generate_uuid
        @output ||= []
        @created_at ||= Time.now
      end

      # Create from a hash (JSON deserialization).
      #
      # @param hash [Hash, nil] run data
      # @return [Run, nil] the run or nil
      def self.from_hash(hash)
        return nil if hash.nil?

        instance = allocate
        instance.send(:initialize_from_hash, hash)
        instance
      end

      # Check if the run is in a terminal state.
      #
      # @return [Boolean] true if completed, failed, or cancelled
      def terminal?
        Types::RunStatus.terminal?(@status)
      end

      # Check if the run is currently executing.
      #
      # @return [Boolean] true if in_progress
      def in_progress?
        @status == Types::RunStatus::IN_PROGRESS
      end

      # Check if the run is waiting for client input.
      #
      # @return [Boolean] true if awaiting
      def awaiting?
        @status == Types::RunStatus::AWAITING
      end

      # Check if the run completed successfully.
      #
      # @return [Boolean] true if completed
      def completed?
        @status == Types::RunStatus::COMPLETED
      end

      # Check if the run failed.
      #
      # @return [Boolean] true if failed
      def failed?
        @status == Types::RunStatus::FAILED
      end

      # Check if the run was cancelled.
      #
      # @return [Boolean] true if cancelled
      def cancelled?
        @status == Types::RunStatus::CANCELLED
      end

      # Check if the run is being cancelled.
      #
      # @return [Boolean] true if cancelling
      def cancelling?
        @status == Types::RunStatus::CANCELLING
      end

      # Transition to in_progress status.
      #
      # @return [self] for chaining
      def start!
        @status = Types::RunStatus::IN_PROGRESS
        self
      end

      # Transition to awaiting status.
      #
      # @param request [AwaitRequest] the request for client input
      # @return [self] for chaining
      def await!(request)
        @status = Types::RunStatus::AWAITING
        @await_request = request
        self
      end

      # Transition to completed status.
      #
      # @param output [Array<Message>, nil] optional output messages
      # @return [self] for chaining
      def complete!(output = nil)
        @status = Types::RunStatus::COMPLETED
        @output = output if output
        @finished_at = Time.now
        self
      end

      # Transition to failed status.
      #
      # @param error [Error, String] the error or error message
      # @return [self] for chaining
      def fail!(error)
        @status = Types::RunStatus::FAILED
        @error = error.is_a?(Error) ? error : Error.server_error(error.to_s)
        @finished_at = Time.now
        self
      end

      # Transition to cancelling status.
      #
      # @return [self] for chaining
      def cancel!
        @status = Types::RunStatus::CANCELLING
        self
      end

      # Transition to cancelled status.
      #
      # @return [self] for chaining
      def cancelled!
        @status = Types::RunStatus::CANCELLED
        @finished_at = Time.now
        self
      end

      # Add a message to the output.
      #
      # @param message [Message, Hash] the message to add
      # @return [self] for chaining
      def add_output(message)
        @output << (message.is_a?(Message) ? message : Message.from_hash(message))
        self
      end

      # Raise an exception if the run failed.
      #
      # @return [self] if not failed
      # @raise [RunError] if failed
      def raise_for_status!
        return self unless failed?

        raise SimpleAcp::RunError, @error&.message || "Run failed"
      end

      # Validate the run.
      #
      # @return [Boolean] true if run_id, agent_name, and status are valid
      def valid?
        return false unless Types.valid_uuid?(@run_id)
        return false unless Types.valid_agent_name?(@agent_name)
        return false unless Types::RunStatus.valid?(@status)

        true
      end

      private

      def initialize_from_hash(hash)
        @run_id = hash["run_id"] || hash[:run_id]
        @agent_name = hash["agent_name"] || hash[:agent_name]
        @session_id = hash["session_id"] || hash[:session_id]
        @status = hash["status"] || hash[:status] || Types::RunStatus::CREATED
        @created_at = parse_time(hash["created_at"] || hash[:created_at])
        @finished_at = parse_time(hash["finished_at"] || hash[:finished_at])

        output_data = hash["output"] || hash[:output] || []
        @output = output_data.map { |m| Message.from_hash(m) }

        if hash["error"] || hash[:error]
          @error = Error.from_hash(hash["error"] || hash[:error])
        end

        if hash["await_request"] || hash[:await_request]
          @await_request = AwaitRequest.from_hash(hash["await_request"] || hash[:await_request])
        end
      end

      def parse_time(value)
        return nil if value.nil?
        return value if value.is_a?(Time)

        Time.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end

    # Request body for creating a run
    class RunCreateRequest < Base
      attribute :agent_name, required: true
      attribute :input, required: true
      attribute :mode
      attribute :session_id
      attribute :session

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = super

        input_data = hash["input"] || hash[:input] || []
        instance.input = input_data.map { |m| Message.from_hash(m) }

        if hash["session"] || hash[:session]
          instance.session = Session.from_hash(hash["session"] || hash[:session])
        end

        instance
      end

      def valid?
        return false unless Types.valid_agent_name?(@agent_name)
        return false if @input.nil? || @input.empty?
        return false if @mode && !Types::RunMode.valid?(@mode)

        true
      end
    end

    # Request body for resuming a run
    class RunResumeRequest < Base
      attribute :run_id, required: true
      attribute :await_resume, required: true
      attribute :mode, required: true

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = super

        if hash["await_resume"] || hash[:await_resume]
          instance.await_resume = AwaitResume.from_hash(hash["await_resume"] || hash[:await_resume])
        end

        instance
      end

      def valid?
        return false unless Types.valid_uuid?(@run_id)
        return false if @await_resume.nil?
        return false unless Types::RunMode.valid?(@mode)

        true
      end
    end
  end
end
