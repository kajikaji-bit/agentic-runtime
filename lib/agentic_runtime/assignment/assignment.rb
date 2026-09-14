# frozen_string_literal: true

require_relative '../event'

module AgenticRuntime
  module Assignment
    class Assignment
      attr_reader :task_name, :session

      def self.assign(task:, session:)
        raise ArgumentError, 'クローズしたタスクには割り当てられません' unless task.progress.task_status == 'created'

        attached = Event.new(name: 'session.attached', attributes: { 'runtime' => session.runtime, 'id' => session.id })
        new(task_name: task.name, session: session, events: [attached])
      end

      def self.restore(task_name:, session:)
        new(task_name: task_name, session: session, events: [])
      end

      def release_events
        @events.dup.freeze
      end

      def clear_events
        @events.clear
        nil
      end

      private

      def initialize(task_name:, session:, events:)
        @task_name = task_name.dup.freeze
        @session = session
        @events = events.dup
      end

      private_class_method :new
    end
  end
end
