# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'create_task'
require_relative '../catalog'
require_relative '../asset/project_assets'
require_relative '../workspace'
require_relative '../session'

module AgenticRuntime
  module Task
    # CLI 固有の入力を受け取り、タスクを作る仕事の結果を返す。
    class TaskCommands
      def initialize(root:, stdout:)
        @create_task = CreateTask.new(workspace: Workspace.new(root: root), catalog: Catalog.new(root: root),
                                      assets: Asset::ProjectAssets.new(root: root))
        @stdout = stdout
        freeze
      end

      def create(arguments)
        name, goal, workflow = parameters(arguments)
        task = @create_task.create(
          name: name, goal: goal, workflow_name: workflow, session: Session.from_environment_variables
        )
        progress = task.progress
        @stdout.puts(JSON.generate(task: task.name, task_status: progress.task_status,
                                   current_step: progress.next_step_name))
        nil
      rescue OptionParser::ParseError => e
        raise ArgumentError, e.message
      end

      private

      def parameters(arguments)
        name, *values = arguments
        options = OptionParser.new.getopts(values, '', 'goal:', 'workflow:')
        unless name && options['goal'] && options['workflow'] && values.empty?
          raise ArgumentError, 'タスク名と目的、ワークフローを指定してください'
        end

        [name, options.fetch('goal'), options.fetch('workflow')]
      end
    end
  end
end
