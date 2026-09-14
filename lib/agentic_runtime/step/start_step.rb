# frozen_string_literal: true

module AgenticRuntime
  module Step
    class StartStep # rubocop:disable Style/Documentation
      def initialize(workspace:, assets:)
        @workspace = workspace
        @assets = assets
        freeze
      end

      def start(task_name:)
        task = @workspace.find(task_name)
        raise ArgumentError, 'クローズ済みのタスクです' if task.progress.task_status == 'closed'

        following = task.plan.next_step
        raise ArgumentError, '開始できるステップがありません' unless following

        step_assets = @assets.for_step(definition: following)
        task.plan.advance
        @workspace.save(task, step_assets: step_assets)
        task
      end
    end
  end
end
