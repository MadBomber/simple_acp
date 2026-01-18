# frozen_string_literal: true

require "base64"

module SimpleAcp
  module Models
    # Individual content unit within a Message
    class MessagePart < Base
      attribute :name
      attribute :content_type, required: true
      attribute :content
      attribute :content_encoding, default: Types::ContentEncoding::PLAIN
      attribute :content_url
      attribute :metadata

      def initialize(**kwargs)
        super
        validate!
      end

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = allocate
        instance.send(:initialize_from_hash, hash)
        instance
      end

      # Create a text message part
      def self.text(content, name: nil)
        new(
          content_type: "text/plain",
          content: content,
          name: name
        )
      end

      # Create a JSON message part
      def self.json(data, name: nil)
        new(
          content_type: "application/json",
          content: data.is_a?(String) ? data : data.to_json,
          name: name
        )
      end

      # Create an image message part from base64 data
      def self.image(data, mime_type: "image/png", name: nil)
        new(
          content_type: mime_type,
          content: data,
          content_encoding: Types::ContentEncoding::BASE64,
          name: name
        )
      end

      # Create a message part from a URL
      def self.from_url(url, content_type:, name: nil)
        new(
          content_type: content_type,
          content_url: url,
          name: name
        )
      end

      def text?
        @content_type&.start_with?("text/")
      end

      def json?
        @content_type == "application/json"
      end

      def image?
        @content_type&.start_with?("image/")
      end

      def base64_encoded?
        @content_encoding == Types::ContentEncoding::BASE64
      end

      def url_reference?
        !@content_url.nil?
      end

      # Decode content if base64 encoded
      def decoded_content
        return @content unless base64_encoded?

        Base64.decode64(@content)
      end

      # Parse JSON content
      def parsed_json
        return nil unless json?

        JSON.parse(@content)
      end

      def valid?
        return false if @content_type.nil?
        return false if @content.nil? && @content_url.nil?
        return false if @content && @content_url

        true
      end

      def to_s
        return @content if text?
        return @content_url if url_reference?

        "<#{@content_type}>"
      end

      private

      def initialize_from_hash(hash)
        @name = hash["name"] || hash[:name]
        @content_type = hash["content_type"] || hash[:content_type]
        @content = hash["content"] || hash[:content]
        @content_encoding = hash["content_encoding"] || hash[:content_encoding] || Types::ContentEncoding::PLAIN
        @content_url = hash["content_url"] || hash[:content_url]

        metadata_hash = hash["metadata"] || hash[:metadata]
        if metadata_hash
          kind = metadata_hash["kind"] || metadata_hash[:kind]
          @metadata = case kind
                      when "citation"
                        CitationMetadata.from_hash(metadata_hash)
                      when "trajectory"
                        TrajectoryMetadata.from_hash(metadata_hash)
                      end
        end

        validate!
      end

      def validate!
        if @content && @content_url
          raise SimpleAcp::ValidationError, "MessagePart cannot have both content and content_url"
        end
      end
    end
  end
end
