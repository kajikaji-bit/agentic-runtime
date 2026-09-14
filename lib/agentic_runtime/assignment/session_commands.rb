# frozen_string_literal: true

require 'json'
require_relative '../invalid_usage'
require_relative '../task/workspace'
require_relative 'session'
require_relative 'attach_session'
require_relative 'assignees'

module AgenticRuntime
  module Assignment
    class SessionCommands
      def initialize(root:, stdout:)
        @attach_session = AttachSession.new(workspace: Task::Workspace.new(root: root),
                                            assignees: Assignees.new(root: root))
        @stdout = stdout
        freeze
      end

      def attach(arguments)
        name, *rest = arguments
        raise InvalidUsage, '足りない引数です: タスク名' unless name
        raise InvalidUsage, "余分な引数です: #{rest.join(' ')}" if rest.any?

        assignment = @attach_session.attach(task_name: name, session: Session.from_environment_variables)
        session = assignment.session
        @stdout.puts(JSON.generate(task: assignment.task_name, runtime: session.runtime, id: session.id))
        0
      end
    end
  end
end
