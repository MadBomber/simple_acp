# frozen_string_literal: true

module SimpleAcp
  module Models
    # Fundamental communication structure in ACP
    class Message < Base
      attribute :role, required: true
      attribute :parts, default: -> { [] }
      attribute :created_at
      attribute :completed_at

      def initialize(**kwargs)
        super
        @parts ||= []
        @created_at ||= Time.now
      end

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = allocate
        instance.send(:initialize_from_hash, hash)
        instance
      end

      # Create a user message
      def self.user(*contents)
        parts = contents.map do |content|
          case content
          when MessagePart
            content
          when String
            MessagePart.text(content)
          when Hash
            MessagePart.from_hash(content)
          else
            MessagePart.json(content)
          end
        end

        new(role: Types::Role::USER, parts: parts)
      end

      # Create an agent message
      def self.agent(*contents)
        parts = contents.map do |content|
          case content
          when MessagePart
            content
          when String
            MessagePart.text(content)
          when Hash
            MessagePart.from_hash(content)
          else
            MessagePart.json(content)
          end
        end

        new(role: Types::Role::AGENT, parts: parts)
      end

      def user?
        @role == Types::Role::USER
      end

      def agent?
        @role == Types::Role::AGENT || @role.to_s.start_with?("agent/")
      end

      def agent_name
        return nil unless agent?

        if @role.to_s.start_with?("agent/")
          @role.to_s.sub("agent/", "")
        end
      end

      def add_part(part)
        @parts << (part.is_a?(MessagePart) ? part : MessagePart.from_hash(part))
        self
      end

      def complete!
        @completed_at = Time.now
        self
      end

      def completed?
        !@completed_at.nil?
      end

      # Combine messages
      def +(other)
        combined = self.class.new(role: @role, parts: @parts.dup)
        other.parts.each { |p| combined.add_part(p) }
        combined
      end

      # Get text content from all parts
      def text_content
        @parts.select(&:text?).map(&:content).join("\n")
      end

      # Compress message by combining adjacent text parts
      def compress
        return self if @parts.length <= 1

        compressed_parts = []
        current_text = nil

        @parts.each do |part|
          if part.text? && !part.base64_encoded?
            if current_text
              current_text = MessagePart.text("#{current_text.content}\n#{part.content}")
            else
              current_text = part.dup
            end
          else
            compressed_parts << current_text if current_text
            current_text = nil
            compressed_parts << part
          end
        end

        compressed_parts << current_text if current_text

        self.class.new(role: @role, parts: compressed_parts, created_at: @created_at)
      end

      def valid?
        return false unless Types::Role.valid?(@role)
        return false if @parts.empty?
        return false unless @parts.all?(&:valid?)

        true
      end

      def to_s
        @parts.map(&:to_s).join("\n")
      end

      private

      def initialize_from_hash(hash)
        @role = hash["role"] || hash[:role]
        @created_at = parse_time(hash["created_at"] || hash[:created_at])
        @completed_at = parse_time(hash["completed_at"] || hash[:completed_at])

        parts_data = hash["parts"] || hash[:parts] || []
        @parts = parts_data.map { |p| MessagePart.from_hash(p) }
      end

      def parse_time(value)
        return nil if value.nil?
        return value if value.is_a?(Time)

        Time.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
