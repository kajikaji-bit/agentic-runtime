# frozen_string_literal: true

require_relative '../workflow'
require_relative '../asset/checklist'
require_relative 'directive'

module AgenticRuntime
  module Step
    # StepDirectory は Read Model Repository として、保存した定義から、対象ステップの仕事を指示として取得する。
    class StepDirectory
      def initialize(root:, task_name:, step_name:)
        @path = File.join(root, 'workspace', task_name).freeze
        @task_name = task_name.dup.freeze
        @step_name = step_name.dup.freeze
        freeze
      end

      def artifacts
        path = File.join(@path, @step_name)
        Dir.glob('**/*', File::FNM_DOTMATCH, base: path).select do |file|
          File.file?(File.join(path, file))
        end.sort.map(&:freeze).freeze
      end

      def checklists
        checks = File.join(@step_name, 'checks')
        files = Dir.glob('*.md', base: File.join(@path, checks)).sort
        files.map { |file| checklist(File.join(checks, file)) }.to_h { |checklist| [checklist.name, checklist] }.freeze
      end

      def directive
        workflow = Workflow.parse(File.read(File.join(@path, 'workflow.yaml')))
        definition = workflow.steps.find { |step| step.name == @step_name }
        raise ArgumentError, "ステップが見つかりません: #{@step_name}" unless definition

        Directive.new(task_name: @task_name, step_definition: definition, workspace_path: @path)
      end

      private

      def checklist(path)
        Asset::Checklist.from_markdown(File.read(File.join(@path, path)), path: path)
      end
    end
  end
end
