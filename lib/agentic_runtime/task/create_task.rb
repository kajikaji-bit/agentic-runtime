# frozen_string_literal: true

require_relative 'task'
require_relative '../assignment'

module AgenticRuntime
  module Task
    # CreateTask は Application Service として、作成した仕事を保存し、担当する会話から取得できるようにする。
    class CreateTask
      def initialize(workspace:, catalog:, assets:)
        @workspace = workspace
        @catalog = catalog
        @assets = assets
        freeze
      end

      def create(name:, goal:, workflow_name:, session:)
        task = Task.create(name: name, goal: goal, workflow: verified_workflow(workflow_name), workspace: @workspace)
        @workspace.save(task)
        @workspace.save_assignment(Assignment.assign(task: task, session: session))
        @workspace.find(name)
      end

      private

      def verified_workflow(workflow_name)
        workflow = @catalog.find(workflow_name)
        workflow.steps.each { |definition| @assets.for_step(definition: definition) }
        workflow
      end
    end
  end
end
