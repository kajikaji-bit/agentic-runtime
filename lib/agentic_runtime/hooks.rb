# frozen_string_literal: true

require 'json'
require_relative 'workspace'
require_relative 'session'
require_relative 'task/continuation'
require_relative 'asset/project_assets'
require_relative 'step/start_step'
require_relative 'step/step_directory'

module AgenticRuntime
  class Hooks
    def initialize(runtime)
      @runtime = runtime.dup.freeze
      @root = Dir.pwd.freeze
      @workspace = Workspace.new(root: @root)
      @continuation = Task::Continuation.new
      @start_step = Step::StartStep.new(workspace: @workspace, assets: Asset::ProjectAssets.new(root: @root))
      @step_directory = Step::StepDirectory
      freeze
    end

    def run(input:, stdout: $stdout)
      session = Session.from_hook_input(runtime: @runtime, input: input)
      return respond(stdout) unless session

      task = @workspace.find_by(session: session)
      return respond(stdout) unless task

      decision = @continuation.decide(progress: task.progress)
      return respond(stdout) if decision == :continue

      if decision == :done
        task.close
        @workspace.save(task)
        return respond(stdout, "タスク #{task.name} をクローズした。クローズしたことをユーザーへ伝えてターンを終了する。")
      end

      started = @start_step.start(task_name: task.name)
      directory = @step_directory.new(root: @root, task_name: started.name,
                                      step_name: started.progress.current_step_name)
      respond(stdout, directory.directive.body)
    end

    private

    def respond(stdout, body = nil)
      response = if body
                   @runtime == 'cursor' ? { followup_message: body } : { decision: 'block', reason: body }
                 else
                   @runtime == 'codex' ? { continue: true } : {}
                 end
      stdout.puts(JSON.generate(response))
      0
    end
  end
end
