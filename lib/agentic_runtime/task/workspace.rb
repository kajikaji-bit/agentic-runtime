# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require_relative '../event'
require_relative '../workspace_log'
require_relative 'task'
require_relative '../asset/workflow'
require_relative 'plan'
require_relative '../step/step'
require_relative '../step/step_directory'
require_relative '../asset/project_assets'

module AgenticRuntime
  module Task
    class Workspace
      def initialize(root:)
        @root = File.expand_path(root).freeze
        @assets = Asset::ProjectAssets.new(root: @root)
        freeze
      end

      def find(name)
        raise ArgumentError, 'タスク名が必要です' unless name.is_a?(String) && /\S/.match?(name)

        path = File.join(@root, 'workspace', name)
        raise ArgumentError, "タスクがありません: #{name}" unless Dir.exist?(path)

        workflow = Asset::Workflow.parse(File.read(File.join(path, 'workflow.yaml')))
        definitions = workflow.steps.to_h { |definition| [definition.name, definition] }

        events = WorkspaceLog.new(root: @root, task_name: name).events
        statuses = events.each_with_object({}) do |event, found|
          next unless %w[step.started step.completed step.cancelled].include?(event.name)

          found[event.attributes.fetch('step')] = event.name.delete_prefix('step.')
        end

        steps = statuses.map do |step_name, status|
          definition = definitions[step_name]
          raise ArgumentError, "保存したステップが定義にありません: #{step_name}" unless definition

          directory = Step::StepDirectory.new(root: @root, task_name: name, step_name: step_name)
          Step::Step.restore(task_name: name, definition: definition, directory: directory, assets: @assets,
                             status: status)
        end

        plan = Plan.new(task_name: name, workflow: workflow, root: @root, assets: @assets, steps: steps)
        status = events.any? { |event| event.name == 'task.closed' } ? 'closed' : 'created'
        Task.restore(name: name, plan: plan, status: status)
      end

      def save(task, step_assets: nil)
        path = File.join(@root, 'workspace', task.name)
        raise ArgumentError, "同じ名前のタスクがあります: #{task.name}" if task.new_record? && Dir.exist?(path)

        events = task.release_events

        if task.new_record?
          FileUtils.mkdir_p(File.dirname(path))
          Dir.mkdir(path)
          File.write(File.join(path, 'task.md'), "# #{task.name}\n")
          File.write(File.join(path, 'workflow.yaml'), task.plan.workflow.source)
          events = [Event.new(name: 'workspace.created', attributes: { 'task' => task.name }), *events]
        end

        if step_assets && step_assets.checklists.any?
          step = task.plan.current_step
          raise ArgumentError, '開始したステップがありません' unless step

          step_path = File.join(path, step.name)
          staged = Dir.mktmpdir(".#{step.name}-", path)
          checks = File.join(staged, 'checks')
          FileUtils.mkdir_p(checks)
          step_assets.checklists.each do |checklist|
            File.write(File.join(checks, "#{checklist.name}.md"), checklist.body)
          end
        end

        WorkspaceLog.new(root: @root, task_name: task.name).append(events)
        task.clear_events

        if staged
          FileUtils.rm_rf(step_path)
          File.rename(staged, step_path)
        end

        progress = task.progress
        File.write(File.join(path, 'current_step'), "#{progress.current_step_name}\n")
        File.write(File.join(path, 'state'), "#{progress.task_status}\n")
        nil
      ensure
        FileUtils.rm_rf(staged) if staged
      end
    end
  end
end
