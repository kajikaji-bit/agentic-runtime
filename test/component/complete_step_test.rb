# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/step/complete_step'
require_relative '../../lib/agentic_runtime/catalog'
require_relative '../../lib/agentic_runtime/workspace'
require_relative '../../lib/agentic_runtime/session'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/task/create_task'

class TestCompleteStep < Minitest::Test
  def test_complete_a_step
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
      workspace = AgenticRuntime::Workspace.new(root: project)
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      assignee = AgenticRuntime::Session.from(runtime: 'codex', id: 'review-session')
      create_task = AgenticRuntime::Task::CreateTask.new(workspace: workspace, catalog: catalog, assets: assets)
      task = create_task.create(
        name: 'example', goal: '変更を確認して公開する', workflow_name: 'release-review', session: assignee
      )
      task.plan.advance
      workspace.save(task)
      complete_step = AgenticRuntime::Step::CompleteStep.new(workspace: workspace)

      completed = complete_step.complete(task_name: 'example', step_name: '01-inspect')

      assert_equal 'example', completed.name
      assert_nil completed.progress.current_step_name
      assert_equal '02-summarize', completed.progress.next_step_name
      saved = AgenticRuntime::Workspace.new(root: project).find('example')
      assert_equal 'completed', saved.plan.steps.find { |step| step.name == '01-inspect' }.status
    end
  end

  def test_cannot_complete_an_unstarted_step
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
      workspace = AgenticRuntime::Workspace.new(root: project)
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      assignee = AgenticRuntime::Session.from(runtime: 'codex', id: 'review-session')
      create_task = AgenticRuntime::Task::CreateTask.new(workspace: workspace, catalog: catalog, assets: assets)
      task = create_task.create(
        name: 'example', goal: '変更を確認して公開する', workflow_name: 'release-review', session: assignee
      )
      task.plan.advance
      workspace.save(task)
      complete_step = AgenticRuntime::Step::CompleteStep.new(workspace: workspace)

      assert_raises(ArgumentError) do
        complete_step.complete(task_name: 'example', step_name: '02-summarize')
      end

      saved = AgenticRuntime::Workspace.new(root: project).find('example')
      assert_equal '01-inspect', saved.progress.current_step_name
      assert_equal 'started', saved.plan.current_step.status
      assert_nil saved.progress.next_step_name
    end
  end
end
