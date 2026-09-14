# frozen_string_literal: true

require 'fileutils'
require 'json'
require_relative 'task/task'
require_relative 'workflow'
require_relative 'plan'
require_relative 'step/step'
require_relative 'step/step_directory'
require_relative 'session'

module AgenticRuntime
  class Workspace
    def initialize(root:)
      @root = File.expand_path(root).freeze
      @step_directory = Step::StepDirectory
      freeze
    end

    def find(name)
      path = task_path(name)
      workflow = Workflow.parse(File.read(File.join(path, 'workflow.yaml')))
      goal = File.read(File.join(path, 'task.md'))[/^## Goal\n\n(.*?)\n\n## Completion Criteria/m, 1]
      steps = restored_steps(name, workflow)
      plan = Plan.new(task_name: name, workflow: workflow, workspace: self, steps: steps)
      Task::Task.restore(name: name, goal: goal, plan: plan, status: File.read(File.join(path, 'state')).strip)
    end

    def step_directory(task_name:, step_name:)
      @step_directory.new(root: @root, task_name: task_name, step_name: step_name)
    end

    def find_by(session:)
      paths = Dir.glob(File.join(@root, 'workspace', '*', 'session')).sort
      path = paths.find do |file|
        runtime, id = File.read(file).split
        Session.from(runtime: runtime, id: id) == session &&
          File.read(File.join(File.dirname(file), 'state')).strip == 'created'
      end
      find(File.basename(File.dirname(path))) if path
    end

    def save(task, step_assets: nil)
      return create(task) if task.new_record?

      place_checklists(task, step_assets.checklists) if step_assets
      write(task, progress_files(task))
    end

    def save_assignment(assignment)
      session = assignment.session
      File.write(File.join(task_path(assignment.task_name), 'session'), "#{session.runtime} #{session.id}\n")
      nil
    end

    private

    def create(task)
      path = task_path(task.name)
      FileUtils.mkdir_p(File.dirname(path))
      Dir.mkdir(path)
      write(task, task_files(task))
    end

    def write(task, files)
      path = task_path(task.name)
      files.each { |file, body| File.write(File.join(path, file), body) }
      nil
    end

    def place_checklists(task, checklists)
      return if checklists.empty?

      checks = placement(task)
      FileUtils.mkdir_p(checks)
      checklists.each { |checklist| File.write(File.join(checks, "#{checklist.name}.md"), checklist.body) }
    end

    def placement(task)
      step = task.plan.current_step
      raise ArgumentError, '開始したステップがありません' unless step

      checks = File.join(task_path(task.name), step.name, 'checks')
      raise ArgumentError, "チェックリストが配置済みです: #{checks}" if File.exist?(checks)

      checks
    end

    def restored_steps(name, workflow)
      definitions = workflow.steps.to_h { |definition| [definition.name, definition] }
      stored_steps(task_path(name)).map do |attributes|
        step_name = attributes.fetch('name')
        definition = definitions[step_name]
        raise ArgumentError, "保存したステップが定義にありません: #{step_name}" unless definition

        Step::Step.restore(task_name: name, definition: definition,
                           directory: step_directory(task_name: name, step_name: step_name),
                           status: attributes.fetch('status'))
      end
    end

    def task_path(name)
      raise ArgumentError, 'タスク名が不正です' unless /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/.match?(name.to_s)

      File.join(@root, 'workspace', name)
    end

    # 開始だけを保存していた版も読み取る。取得時には保存先を書き換えない。
    def stored_steps(path)
      steps_path = File.join(path, 'steps.json')
      return JSON.parse(File.read(steps_path)) if File.file?(steps_path)

      name = File.read(File.join(path, 'current_step')).strip
      name.empty? ? [] : [{ 'name' => name, 'status' => 'started' }]
    end

    def task_files(task)
      {
        'task.md' => "# #{task.name}\n\n## Goal\n\n#{task.goal}\n\n## Completion Criteria\n",
        'workflow.yaml' => task.plan.workflow.source
      }.merge(progress_files(task))
    end

    def progress_files(task)
      progress = task.progress
      steps = task.plan.steps.map { |step| { name: step.name, status: step.status } }
      {
        'steps.json' => JSON.generate(steps),
        'current_step' => "#{progress.current_step_name}\n",
        'state' => "#{progress.task_status}\n"
      }
    end
  end
end
