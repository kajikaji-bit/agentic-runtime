# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative '../invalid_usage'
require_relative 'create_task'
require_relative 'close_task'
require_relative '../asset/catalog'
require_relative '../asset/project_assets'
require_relative 'workspace'
require_relative '../assignment/assignees'
require_relative '../assignment/session'

module AgenticRuntime
  module Task
    class TaskCommands
      def initialize(root:, stdout:)
        workspace = Workspace.new(root: root)
        @create_task = CreateTask.new(root: root, workspace: workspace, catalog: Asset::Catalog.new(root: root),
                                      assets: Asset::ProjectAssets.new(root: root),
                                      assignees: Assignment::Assignees.new(root: root))
        @close_task = CloseTask.new(workspace: workspace)
        @stdout = stdout
        freeze
      end

      def create(arguments)
        name, workflow = parameters(arguments)
        task = @create_task.create(
          name: name, workflow_name: workflow, session: Assignment::Session.from_environment_variables
        )
        progress = task.progress
        @stdout.puts(JSON.generate(task: task.name, task_status: progress.task_status,
                                   current_step: progress.next_step_name))
        0
      end

      def close(arguments)
        name, *rest = arguments
        raise InvalidUsage, '足りない引数です: タスク名' unless name
        raise InvalidUsage, "余分な引数です: #{rest.join(' ')}" if rest.any?

        task = @close_task.close(task_name: name)
        @stdout.puts(JSON.generate(task: name, task_status: task.progress.task_status))
        0
      end

      private

      def parameters(arguments)
        name, *values = arguments
        options = OptionParser.new.getopts(values, '', 'workflow:')
        missing = []
        missing << 'タスク名' unless name
        missing << '--workflow' unless options['workflow']
        raise InvalidUsage, "足りない引数です: #{missing.join('、')}" if missing.any?
        raise InvalidUsage, "余分な引数です: #{values.join(' ')}" if values.any?

        [name, options.fetch('workflow')]
      rescue OptionParser::InvalidOption => e
        raise InvalidUsage, "知らないオプションです: #{e.args.first}"
      rescue OptionParser::MissingArgument => e
        raise InvalidUsage, "オプションの値がありません: #{e.args.first}"
      end
    end
  end
end
