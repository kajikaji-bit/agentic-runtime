# frozen_string_literal: true

require_relative 'assignment'

module AgenticRuntime
  module Assignment
    class AttachSession
      def initialize(workspace:, assignees:)
        @workspace = workspace
        @assignees = assignees
        freeze
      end

      def attach(task_name:, session:)
        assignment = Assignment.assign(task: @workspace.find(task_name), session: session)
        @assignees.save(assignment)
        assignment
      end
    end
  end
end
