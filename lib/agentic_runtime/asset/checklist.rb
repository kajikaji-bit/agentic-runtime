# frozen_string_literal: true

module AgenticRuntime
  module Asset
    class Checklist # rubocop:disable Style/Documentation
      NAME = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/.freeze
      EVIDENCE_HEADING = /^## エビデンス\s*$/.freeze
      ITEM = /^\s*- \[([ xX])\]/.freeze
      private_constant :NAME, :EVIDENCE_HEADING, :ITEM

      attr_reader :name, :path, :body

      def self.from_markdown(markdown, path:)
        new(path: path, body: markdown)
      end

      def checked?
        items, = @body.split(EVIDENCE_HEADING, 2)
        items.scan(ITEM).flatten.all? { |mark| mark.casecmp?('x') }
      end

      private

      def initialize(path:, body:)
        @name = File.basename(path, '.md').freeze
        raise ArgumentError, "チェックリスト名が不正です: #{@name}" unless NAME.match?(@name)

        @path = path.dup.freeze
        @body = body.dup.freeze
        freeze
      end

      private_class_method :new
    end
  end
end
