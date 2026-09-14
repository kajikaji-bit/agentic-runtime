# frozen_string_literal: true

require_relative '../task/workspace'

module AgenticRuntime
  module Project
    class Doctor
      class Result
        attr_reader :inconsistencies

        def ok?
          @inconsistencies.empty?
        end

        def initialize(inconsistencies:)
          @inconsistencies = inconsistencies.map { |inconsistency| inconsistency.dup.freeze }.freeze
          freeze
        end
      end

      def initialize(root:)
        @root = File.expand_path(root).freeze
        @workspace = Task::Workspace.new(root: @root)
        freeze
      end

      def check(task_name: nil)
        names = workspace_names
        raise ArgumentError, "タスクがありません: #{task_name}" if task_name && !names.include?(task_name)

        targets = task_name ? [task_name] : names
        restored = {}
        inconsistencies = targets.flat_map do |name|
          task = @workspace.find(name)
          restored[name] = task
          copy_inconsistencies(name: name, progress: task.progress)
        rescue ArgumentError, KeyError, SystemCallError => e
          ["#{name}: ログからタスクを復元できません (#{e.message})"]
        end

        Result.new(inconsistencies: inconsistencies + assignment_inconsistencies(restored))
      end

      private

      def workspace_names
        paths = Dir.glob(File.join(@root, 'workspace/*')).select { |path| File.directory?(path) }
        paths.map { |path| File.basename(path) }.sort
      end

      def copy_inconsistencies(name:, progress:)
        copies = { 'state' => progress.task_status, 'current_step' => progress.current_step_name.to_s }
        copies.filter_map do |file, logged|
          path = File.join(@root, 'workspace', name, file)
          next "#{name}: #{file} の写しがありません" unless File.exist?(path)

          copy = File.read(path).chomp
          next if copy == logged

          "#{name}: #{file} の写しがログと食い違います (写し: #{copy}、ログ: #{logged})"
        end
      end

      def assignment_inconsistencies(tasks)
        assigned = tasks.filter_map do |name, task|
          next if task.progress.task_status == 'closed'

          path = File.join(@root, 'workspace', name, 'session')
          next unless File.exist?(path)

          [File.read(path).strip, name]
        end

        assigned.group_by(&:first).filter_map do |session, pairs|
          next if pairs.size < 2

          "#{session}: クローズしていないタスクを二つ以上担当しています (#{pairs.map(&:last).join('、')})"
        end
      end
    end
  end
end
