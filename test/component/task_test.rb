# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/task/task'
require_relative '../../lib/agentic_runtime/catalog'
require_relative '../../lib/agentic_runtime/workspace'

class TestTask < Minitest::Test
  def test_create_a_task
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents', 'workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        description: 公開前に変更内容を確認する
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
          - name: 02-summarize
            description: 確認した結果をまとめる
      YAML

      workflow = AgenticRuntime::Catalog.new(root: project).find('release-review')

      task = AgenticRuntime::Task::Task.create(
        name: 'example', goal: '変更を確認して公開する', workflow: workflow,
        workspace: AgenticRuntime::Workspace.new(root: project)
      )

      assert_equal 'example', task.name
      assert_equal 'created', task.progress.task_status
      assert_equal '01-inspect', task.progress.next_step_name
    end
  end

  def test_close_a_task
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents', 'workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
      YAML

      catalog = AgenticRuntime::Catalog.new(root: project)
      task = AgenticRuntime::Task::Task.create(
        name: 'example', goal: '変更を確認して公開する', workflow: catalog.find('release-review'),
        workspace: AgenticRuntime::Workspace.new(root: project)
      )
      task.plan.advance
      task.plan.current_step.complete
      before_close = task.progress

      task.close

      assert_equal 'closed', task.progress.task_status
      assert_equal 'created', before_close.task_status
    end
  end
end
