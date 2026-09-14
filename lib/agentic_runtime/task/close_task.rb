# frozen_string_literal: true

module AgenticRuntime
  module Task
    class CloseTask
      def initialize(workspace:)
        @workspace = workspace
        freeze
      end

      def close(task_name:)
        task = @workspace.find(task_name)
        task.close
        @workspace.save(task)
        @workspace.find(task_name)
      end
    end
  end
end
