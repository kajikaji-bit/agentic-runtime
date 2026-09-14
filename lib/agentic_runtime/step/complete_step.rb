# frozen_string_literal: true

module AgenticRuntime
  module Step
    # CompleteStep は Application Service として、完了する対象を確かめ、状態変更と保存を手配する。
    class CompleteStep
      def initialize(workspace:)
        @workspace = workspace
        freeze
      end

      def complete(task_name:, step_name:, approval_evidence: nil)
        task = @workspace.find(task_name)
        step = task.plan.current_step
        raise ArgumentError, '指定したステップは進行中ではありません' unless step&.name == step_name

        step.complete(approval_evidence: approval_evidence)
        @workspace.save(task)
        @workspace.find(task_name)
      end
    end
  end
end
