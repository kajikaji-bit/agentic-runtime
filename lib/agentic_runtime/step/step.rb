# frozen_string_literal: true

require_relative 'check_completion'

module AgenticRuntime
  module Step
    # Step は Entity として、タスク内の仕事の開始と完了を管理する。
    class Step
      class CompletionRejected < StandardError # rubocop:disable Style/Documentation
        attr_reader :task_name, :step_name, :unmet

        def initialize(task_name:, step_name:, unmet:)
          @task_name = task_name.dup.freeze
          @step_name = step_name.dup.freeze
          @unmet = unmet
          super('完了条件を満たしていません')
        end
      end

      attr_reader :name, :status

      def self.start(task_name:, definition:, directory:)
        new(task_name: task_name, definition: definition, directory: directory, status: 'started')
      end

      def self.restore(task_name:, definition:, directory:, status:)
        new(task_name: task_name, definition: definition, directory: directory, status: status)
      end

      def complete(approval_evidence: nil)
        raise ArgumentError, '進行中のステップではありません' unless @status == 'started'

        verdict = @check_completion.compare(
          required_artifacts: @definition.artifacts, artifacts: @directory.artifacts,
          required_checks: @definition.checks, checklists: @directory.checklists,
          approval_required: @definition.approval_required?, approval_evidence: approval_evidence
        )
        unless verdict.accepted?
          raise CompletionRejected.new(task_name: @task_name, step_name: @name, unmet: verdict.unmet)
        end

        @status = 'completed'
        nil
      end

      private

      def initialize(task_name:, definition:, directory:, status:)
        raise ArgumentError, 'ステップの状態が不正です' unless %w[started completed].include?(status)

        @task_name = task_name.dup.freeze
        @definition = definition
        @directory = directory
        @check_completion = CheckCompletion.new
        @name = definition.name
        @status = status.dup.freeze
      end

      private_class_method :new
    end
  end
end
