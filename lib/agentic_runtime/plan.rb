# frozen_string_literal: true

require_relative 'step/step'

module AgenticRuntime
  # Plan は Entity として、進行中の仕事を残して次へ進むことを防ぐ。
  class Plan
    attr_reader :workflow

    def initialize(task_name:, workflow:, workspace:, steps: [])
      @task_name = task_name.dup.freeze
      @workflow = workflow
      @workspace = workspace
      @steps = steps.dup
    end

    def current_step
      @steps.find { |step| step.status == 'started' }
    end

    def next_step
      return nil if current_step

      completed_names = @steps.map(&:name)
      @workflow.steps.reject { |definition| completed_names.include?(definition.name) }.first
    end

    def steps
      @steps.dup.freeze
    end

    def advance
      raise ArgumentError, '進行中のステップがあります' if current_step

      following = next_step
      raise ArgumentError, '次のステップがありません' unless following

      directory = @workspace.step_directory(task_name: @task_name, step_name: following.name)
      @steps << Step::Step.start(task_name: @task_name, definition: following, directory: directory)
      nil
    end
  end
end
