# frozen_string_literal: true

module AgenticRuntime
  # Assignment は Entity として、タスクの担当する会話を保持する。
  class Assignment
    attr_reader :task_name, :session

    def self.assign(task:, session:)
      raise ArgumentError, 'クローズしたタスクには割り当てられません' unless task.progress.task_status == 'created'

      new(task_name: task.name, session: session)
    end

    private

    def initialize(task_name:, session:)
      @task_name = task_name.dup.freeze
      @session = session
    end

    private_class_method :new
  end
end
