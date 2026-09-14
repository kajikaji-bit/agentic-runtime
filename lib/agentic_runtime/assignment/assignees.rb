# frozen_string_literal: true

require_relative 'assignment'
require_relative '../workspace_log'
require_relative 'session'

module AgenticRuntime
  module Assignment
    class Assignees
      def initialize(root:)
        @root = File.expand_path(root).freeze
        freeze
      end

      def find_by(session:)
        path = Dir.glob(File.join(@root, 'workspace/*/session')).sort.find do |file|
          runtime, id = File.read(file).split
          next unless Session.from(runtime: runtime, id: id) == session

          log = WorkspaceLog.new(root: @root, task_name: File.basename(File.dirname(file)))
          log.events.none? { |event| event.name == 'task.closed' }
        end
        return nil unless path

        Assignment.restore(task_name: File.basename(File.dirname(path)), session: session)
      end

      def save(assignment)
        session = assignment.session
        File.write(File.join(@root, 'workspace', assignment.task_name, 'session'), "#{session.runtime} #{session.id}\n")
        WorkspaceLog.new(root: @root, task_name: assignment.task_name).append(assignment.release_events)
        assignment.clear_events
      end
    end
  end
end
