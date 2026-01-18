# frozen_string_literal: true

module SimpleAcp
  module Client
    # Server-Sent Events (SSE) parser
    class SSEParser
      attr_reader :events

      def initialize
        @buffer = ""
        @events = []
        @current_event = nil
        @current_data = []
      end

      def feed(chunk)
        @buffer += chunk
        parse_buffer
        flush_events
      end

      def each_event
        flush_events
        while (event = @events.shift)
          yield event
        end
      end

      private

      def parse_buffer
        while (line_end = @buffer.index("\n"))
          line = @buffer[0...line_end]
          @buffer = @buffer[(line_end + 1)..]
          line = line.chomp("\r")
          process_line(line)
        end
      end

      def process_line(line)
        if line.empty?
          # Empty line = event boundary
          emit_event
        elsif line.start_with?(":")
          # Comment, ignore
        elsif line.include?(":")
          field, value = line.split(":", 2)
          value = value[1..] if value&.start_with?(" ")
          process_field(field, value || "")
        else
          # Field with no value
          process_field(line, "")
        end
      end

      def process_field(field, value)
        case field
        when "event"
          @current_event = value
        when "data"
          @current_data << value
        when "id"
          # We don't track IDs currently
        when "retry"
          # We don't handle retry currently
        end
      end

      def emit_event
        return if @current_data.empty?

        data = @current_data.join("\n")
        @events << {
          event: @current_event || "message",
          data: data
        }

        @current_event = nil
        @current_data = []
      end

      def flush_events
        emit_event unless @current_data.empty?
      end
    end

    # SSE stream reader that yields parsed events
    class SSEStream
      include Enumerable

      def initialize(response)
        @response = response
        @parser = SSEParser.new
      end

      def each
        return enum_for(:each) unless block_given?

        @response.body.each do |chunk|
          @parser.feed(chunk)
          @parser.each_event do |raw_event|
            event = parse_acp_event(raw_event)
            yield event if event
          end
        end
      end

      private

      def parse_acp_event(raw_event)
        data = JSON.parse(raw_event[:data])
        Models::Events.from_hash(data)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
