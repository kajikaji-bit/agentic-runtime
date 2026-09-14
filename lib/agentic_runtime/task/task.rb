# frozen_string_literal: true

require_relative '../plan'
require_relative 'progress'

module AgenticRuntime
  module Task
    class Task
      attr_reader :name, :goal, :plan

      def self.create(name:, goal:, workflow:, workspace:)
        new(name: name, goal: goal, plan: Plan.new(task_name: name, workflow: workflow, workspace: workspace),
            new_record: true)
      end

      def self.restore(name:, goal:, plan:, status:)
        new(name: name, goal: goal, plan: plan, new_record: false, status: status)
      end

      def new_record?
        @new_record
      end

      def close
        raise ArgumentError, 'クローズ済みのタスクです' if @status == 'closed'

        @status = 'closed'
        nil
      end

      def progress
        current = @plan.current_step&.name
        Progress.new(task_status: @status, current_step_name: current,
                     next_step_name: @plan.next_step&.name)
      end

      private

      def initialize(name:, goal:, plan:, new_record:, status: 'created')
        raise ArgumentError, 'タスク名が不正です' unless name.is_a?(String) && /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/.match?(name)
        raise ArgumentError, '目的が必要です' unless goal.is_a?(String) && /\S/.match?(goal)

        raise ArgumentError, 'タスクの状態が不正です' unless %w[created closed].include?(status)

        @name = name.dup.freeze
        @goal = goal.dup.freeze
        @plan = plan
        @new_record = new_record
        @status = status.dup.freeze
      end

      private_class_method :new
    end
  end
end
