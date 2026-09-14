# frozen_string_literal: true

require_relative 'checklist'
require_relative 'step_assets'

module AgenticRuntime
  module Asset
    class ProjectAssets # rubocop:disable Style/Documentation
      def initialize(root:)
        @root = File.expand_path(root).freeze
        freeze
      end

      def for_step(definition:)
        StepAssets.new(checklists: definition.checks.map { |name| checklist(name) })
      end

      private

      def checklist(name)
        path = sole_path(name)
        raise ArgumentError, "チェックリストがプロジェクトの外を指しています: #{name}" unless inside_project?(path)

        Checklist.from_markdown(File.read(path), path: path.delete_prefix("#{@root}/"))
      end

      def sole_path(name)
        paths = Dir.glob(File.join(@root, '.agents', 'checks', '**', "#{name}.md")).sort.select do |path|
          File.file?(path)
        end
        raise ArgumentError, "チェックリストが見つかりません: #{name}" if paths.empty?
        raise ArgumentError, "チェックリストが重複しています: #{name}" if paths.size > 1

        paths.first
      end

      def inside_project?(path)
        File.realpath(path).start_with?("#{File.realpath(@root)}/")
      end
    end
  end
end
