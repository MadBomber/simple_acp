# frozen_string_literal: true

require "base64"

module SimpleAcp
  module Models
    # Individual content unit within a Message.
    #
    # Message parts can contain text, JSON, images, or URL references.
    # Each part has a content type (MIME type) and either inline content
    # or a URL reference.
    #
    # @example Text part
    #   part = MessagePart.text("Hello, world!")
    #
    # @example JSON part
    #   part = MessagePart.json({ key: "value" })
    #
    # @example Image from base64
    #   part = MessagePart.image(base64_data, mime_type: "image/png")
    #
    # @example URL reference
    #   part = MessagePart.from_url("https://example.com/image.png", content_type: "image/png")
    class MessagePart < Base
      # @!attribute [r] name
      #   @return [String, nil] optional name for the part
      attribute :name

      # @!attribute [r] content_type
      #   @return [String] MIME type (e.g., "text/plain", "application/json")
      attribute :content_type, required: true

      # @!attribute [r] content
      #   @return [String, nil] inline content (mutually exclusive with content_url)
      attribute :content

      # @!attribute [r] content_encoding
      #   @return [String] "plain" or "base64"
      attribute :content_encoding, default: Types::ContentEncoding::PLAIN

      # @!attribute [r] content_url
      #   @return [String, nil] URL reference (mutually exclusive with content)
      attribute :content_url

      # @!attribute [r] metadata
      #   @return [CitationMetadata, TrajectoryMetadata, nil] optional metadata
      attribute :metadata

      def initialize(**kwargs)
        super
        validate!
      end

      # Create from a hash (JSON deserialization).
      #
      # @param hash [Hash, nil] part data
      # @return [MessagePart, nil] the part or nil
      def self.from_hash(hash)
        return nil if hash.nil?

        instance = allocate
        instance.send(:initialize_from_hash, hash)
        instance
      end

      # Create a plain text message part.
      #
      # @param content [String] the text content
      # @param name [String, nil] optional name
      # @return [MessagePart] the text part
      def self.text(content, name: nil)
        new(
          content_type: "text/plain",
          content: content,
          name: name
        )
      end

      # Create a JSON message part.
      #
      # @param data [Hash, Array, String] JSON data (will be serialized if not string)
      # @param name [String, nil] optional name
      # @return [MessagePart] the JSON part
      def self.json(data, name: nil)
        new(
          content_type: "application/json",
          content: data.is_a?(String) ? data : data.to_json,
          name: name
        )
      end

      # Create an image message part from base64 data.
      #
      # @param data [String] base64-encoded image data
      # @param mime_type [String] image MIME type (default: "image/png")
      # @param name [String, nil] optional name
      # @return [MessagePart] the image part
      def self.image(data, mime_type: "image/png", name: nil)
        new(
          content_type: mime_type,
          content: data,
          content_encoding: Types::ContentEncoding::BASE64,
          name: name
        )
      end

      # Create a message part referencing a URL.
      #
      # @param url [String] the URL to reference
      # @param content_type [String] the content type at the URL
      # @param name [String, nil] optional name
      # @return [MessagePart] the URL reference part
      def self.from_url(url, content_type:, name: nil)
        new(
          content_type: content_type,
          content_url: url,
          name: name
        )
      end

      # Check if this is a text content part.
      #
      # @return [Boolean] true if content_type starts with "text/"
      def text?
        @content_type&.start_with?("text/")
      end

      # Check if this is a JSON content part.
      #
      # @return [Boolean] true if content_type is "application/json"
      def json?
        @content_type == "application/json"
      end

      # Check if this is an image content part.
      #
      # @return [Boolean] true if content_type starts with "image/"
      def image?
        @content_type&.start_with?("image/")
      end

      # Check if content is base64 encoded.
      #
      # @return [Boolean] true if content_encoding is "base64"
      def base64_encoded?
        @content_encoding == Types::ContentEncoding::BASE64
      end

      # Check if this part references a URL.
      #
      # @return [Boolean] true if content_url is set
      def url_reference?
        !@content_url.nil?
      end

      # Get decoded content (decodes base64 if needed).
      #
      # @return [String] decoded content
      def decoded_content
        return @content unless base64_encoded?

        Base64.decode64(@content)
      end

      # Parse JSON content into Ruby objects.
      #
      # @return [Hash, Array, nil] parsed JSON or nil if not JSON
      def parsed_json
        return nil unless json?

        JSON.parse(@content)
      end

      # Validate the message part.
      #
      # @return [Boolean] true if content_type is set and has content or URL (not both)
      def valid?
        return false if @content_type.nil?
        return false if @content.nil? && @content_url.nil?
        return false if @content && @content_url

        true
      end

      # Convert to string representation.
      #
      # @return [String] content for text, URL for references, or "<type>" placeholder
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
