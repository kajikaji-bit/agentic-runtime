# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative '../workspace'
require_relative 'complete_step'

module AgenticRuntime
  module Step
    class StepCommands
      def initialize(root:, stdout:)
        @complete_step = CompleteStep.new(workspace: Workspace.new(root: root))
        @stdout = stdout
        freeze
      end

      def complete(arguments)
        name, step, evidence = parameters(arguments)
        task = @complete_step.complete(task_name: name, step_name: step, approval_evidence: evidence)
        progress = task.progress
        @stdout.puts(JSON.generate(
                       task: name, step: step, step_status: 'completed',
                       task_status: progress.task_status, next_step: progress.next_step_name
                     ))
        nil
      rescue OptionParser::ParseError => e
        raise ArgumentError, e.message
      end

      private

      def parameters(arguments)
        name, step, *values = arguments
        options = OptionParser.new.getopts(values, '', 'approval-evidence:')
        raise ArgumentError, 'タスク名とステップ名を指定してください' unless name && step && values.empty?

        [name, step, options['approval-evidence']]
      end
    end
  end
end
