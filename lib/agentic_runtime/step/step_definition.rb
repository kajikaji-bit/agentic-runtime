# frozen_string_literal: true

require 'pathname'

module AgenticRuntime
  module Step
    # StepDefinition は Value Object として、ステップの仕事を、進行状態から独立した定義として保持する。
    class StepDefinition
      CHECK_NAME = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/.freeze
      private_constant :CHECK_NAME

      attr_reader :name, :description, :artifacts, :checks

      def initialize(name:, description:, artifacts: [], checks: [], approval: nil)
        raise ArgumentError, 'ステップ名が不正です' unless /\A[0-9]+-[a-z0-9]+(?:-[a-z0-9]+)*\z/.match?(name.to_s)
        raise ArgumentError, '仕事内容が必要です' unless description.is_a?(String) && /\S/.match?(description)
        raise ArgumentError, "承認の要否が不正です: #{approval}" unless [nil, 'required'].include?(approval)

        @name = name.dup.freeze
        @description = description.dup.freeze
        @artifacts = artifact_declarations(artifacts)
        @checks = checklist_names(checks)
        @approval_required = approval == 'required'
        freeze
      end

      def approval_required?
        @approval_required
      end

      private

      def artifact_declarations(artifacts) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
        raise ArgumentError, '成果物の宣言には配列が必要です' unless artifacts.is_a?(Array)

        artifacts.uniq.map do |file|
          raise ArgumentError, '成果物の宣言が不正です' unless file.is_a?(String) && /\S/.match?(file)

          path = Pathname.new(file)
          clean = path.cleanpath
          if path.absolute? || clean.to_s == '.' || clean.each_filename.first == '..'
            raise ArgumentError, "成果物の宣言がステップの外を指しています: #{file}"
          end

          file.dup.freeze
        end.freeze
      end

      def checklist_names(checks)
        raise ArgumentError, 'チェックリスト名には配列が必要です' unless checks.is_a?(Array)

        checks.uniq.map do |name|
          raise ArgumentError, "チェックリスト名が不正です: #{name}" unless name.is_a?(String) && CHECK_NAME.match?(name)

          name.dup.freeze
        end.freeze
      end
    end
  end
end
