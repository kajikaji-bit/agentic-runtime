# frozen_string_literal: true

require_relative 'task/task_commands'
require_relative 'step/step_commands'

module AgenticRuntime
  # CLI の入口を保ち、個別の入力と出力は Commands へ委ねる。
  module CLI
    ACTIONS = {
      %w[task create] => [Task::TaskCommands, :create],
      %w[step complete] => [Step::StepCommands, :complete]
    }.freeze

    def self.run(arguments, stdout:, stderr:)
      resource, action, *values = arguments
      controller, method = ACTIONS.fetch([resource, action])
      controller.new(root: Dir.pwd, stdout: stdout).public_send(method, values)
      0
    rescue Step::Step::CompletionRejected => e
      stderr.puts(JSON.generate(error: 'completion_rejected', task: e.task_name, step: e.step_name, unmet: e.unmet))
      1
    rescue ArgumentError, KeyError, SystemCallError => e
      stderr.puts("ERROR: #{e.message}")
      1
    end
  end
end
