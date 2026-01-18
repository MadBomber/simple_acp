# frozen_string_literal: true

module SimpleAcp
  module Models
    # Single agent execution
    class Run < Base
      attribute :run_id, required: true
      attribute :agent_name, required: true
      attribute :session_id
      attribute :status, default: Types::RunStatus::CREATED
      attribute :await_request
      attribute :output, default: -> { [] }
      attribute :error
      attribute :created_at
      attribute :finished_at

      def initialize(**kwargs)
        super
        @run_id ||= Types.generate_uuid
        @output ||= []
        @created_at ||= Time.now
      end

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = allocate
        instance.send(:initialize_from_hash, hash)
        instance
      end

      def terminal?
        Types::RunStatus.terminal?(@status)
      end

      def in_progress?
        @status == Types::RunStatus::IN_PROGRESS
      end

      def awaiting?
        @status == Types::RunStatus::AWAITING
      end

      def completed?
        @status == Types::RunStatus::COMPLETED
      end

      def failed?
        @status == Types::RunStatus::FAILED
      end

      def cancelled?
        @status == Types::RunStatus::CANCELLED
      end

      def cancelling?
        @status == Types::RunStatus::CANCELLING
      end

      def start!
        @status = Types::RunStatus::IN_PROGRESS
        self
      end

      def await!(request)
        @status = Types::RunStatus::AWAITING
        @await_request = request
        self
      end

      def complete!(output = nil)
        @status = Types::RunStatus::COMPLETED
        @output = output if output
        @finished_at = Time.now
        self
      end

      def fail!(error)
        @status = Types::RunStatus::FAILED
        @error = error.is_a?(Error) ? error : Error.server_error(error.to_s)
        @finished_at = Time.now
        self
      end

      def cancel!
        @status = Types::RunStatus::CANCELLING
        self
      end

      def cancelled!
        @status = Types::RunStatus::CANCELLED
        @finished_at = Time.now
        self
      end

      def add_output(message)
        @output << (message.is_a?(Message) ? message : Message.from_hash(message))
        self
      end

      def raise_for_status!
        return self unless failed?

        raise SimpleAcp::RunError, @error&.message || "Run failed"
      end

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
