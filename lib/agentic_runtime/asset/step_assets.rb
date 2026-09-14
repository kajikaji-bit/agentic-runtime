# frozen_string_literal: true

module AgenticRuntime
  module Asset
    class StepAssets # rubocop:disable Style/Documentation
      attr_reader :checklists

      def initialize(checklists:)
        @checklists = checklists.dup.freeze
        freeze
      end
    end
  end
end
