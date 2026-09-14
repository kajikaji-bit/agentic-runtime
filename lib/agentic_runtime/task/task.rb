# frozen_string_literal: true

require_relative '../event'
require_relative 'plan'
require_relative 'progress'

module AgenticRuntime
  module Task
    class Task
      attr_reader :name, :plan

      def self.create(name:, workflow:, root:, assets:)
        plan = Plan.new(task_name: name, workflow: workflow, root: root, assets: assets)
        events = [Event.new(name: 'task.created', attributes: { 'task' => name }),
                  Event.new(name: 'workflow.created', attributes: { 'catalog' => workflow.name })]
        new(name: name, plan: plan, new_record: true, events: events)
      end

      def self.restore(name:, plan:, status:)
        new(name: name, plan: plan, new_record: false, status: status, events: [])
      end

      def new_record?
        @new_record
      end

      def close
        raise ArgumentError, 'クローズ済みのタスクです' if @status == 'closed'

        @plan.current_step&.cancel
        @events.concat(@plan.steps.flat_map(&:release_events))
        @plan.steps.each(&:clear_events)
        @events << Event.new(name: 'task.closed', attributes: { 'task' => @name })
        @status = 'closed'
        nil
      end

      def release_events
        (@events + @plan.steps.flat_map(&:release_events)).freeze
      end

      def clear_events
        @events.clear
        @plan.steps.each(&:clear_events)
        nil
      end

      def progress
        current = @plan.current_step&.name
        Progress.new(task_status: @status, current_step_name: current,
                     next_step_name: @plan.next_step&.name)
      end

      private

      def initialize(name:, plan:, new_record:, events:, status: 'created')
        raise ArgumentError, 'タスク名が必要です' unless name.is_a?(String) && /\S/.match?(name)
        raise ArgumentError, 'タスクの状態が不正です' unless %w[created closed].include?(status)

        @name = name.dup.freeze
        @plan = plan
        @new_record = new_record
        @status = status.dup.freeze
        @events = events.dup
      end

      private_class_method :new
    end
  end
end
