# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/catalog'
require_relative '../../lib/agentic_runtime/workspace'
require_relative '../../lib/agentic_runtime/task/task'

class TestPlan < Minitest::Test
  def test_start_the_next_step_after_completing_the_current_step
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents', 'workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
          - name: 02-summarize
            description: 確認した結果をまとめる
          - name: 03-publish
            description: 確認結果を共有する
      YAML

      catalog = AgenticRuntime::Catalog.new(root: project)
      task = AgenticRuntime::Task::Task.create(
        name: 'example', goal: '変更を確認して公開する', workflow: catalog.find('release-review'),
        workspace: AgenticRuntime::Workspace.new(root: project)
      )
      plan = task.plan
      plan.advance
      first_step = plan.current_step
      first_step.complete

      plan.advance

      assert_equal '02-summarize', plan.current_step.name
      assert_equal 'started', plan.current_step.status
      assert_equal 'completed', first_step.status
    end
  end

  def test_cannot_advance_while_a_step_is_in_progress
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents', 'workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
          - name: 02-summarize
            description: 確認した結果をまとめる
      YAML

      catalog = AgenticRuntime::Catalog.new(root: project)
      task = AgenticRuntime::Task::Task.create(
        name: 'example', goal: '変更を確認して公開する', workflow: catalog.find('release-review'),
        workspace: AgenticRuntime::Workspace.new(root: project)
      )
      plan = task.plan
      plan.advance

      assert_raises(ArgumentError) { plan.advance }

      assert_equal '01-inspect', plan.current_step.name
      assert_equal 'started', plan.current_step.status
      assert_nil plan.next_step
    end
  end
end
