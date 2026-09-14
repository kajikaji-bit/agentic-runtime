# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/catalog'
require_relative '../../lib/agentic_runtime/workspace'
require_relative '../../lib/agentic_runtime/session'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/step/start_step'
require_relative '../../lib/agentic_runtime/task/create_task'

class TestStartStep < Minitest::Test
  def test_start_a_step_and_arrange_its_checklists
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents', 'workflows')
      checks = File.join(project, '.agents', 'checks')
      FileUtils.mkdir_p(workflows)
      FileUtils.mkdir_p(checks)
      File.write(File.join(workflows, 'review.yaml'), <<~YAML)
        name: review
        steps:
          - name: 01-inspect
            description: 変更点を確認する
            checks:
              - writing-policy
      YAML
      writing_policy = <<~MARKDOWN
        - [ ] 本文が日本語で書かれている
        - [ ] 同じ対象の呼び方が揃っている
      MARKDOWN
      File.write(File.join(checks, 'writing-policy.md'), writing_policy)
      catalog = AgenticRuntime::Catalog.new(root: project)
      workspace = AgenticRuntime::Workspace.new(root: project)
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      assignee = AgenticRuntime::Session.from(runtime: 'codex', id: 'review-session')
      create_task = AgenticRuntime::Task::CreateTask.new(workspace: workspace, catalog: catalog, assets: assets)
      create_task.create(name: 'example', goal: '変更を確認する', workflow_name: 'review', session: assignee)
      start_step = AgenticRuntime::Step::StartStep.new(workspace: workspace, assets: assets)

      task = start_step.start(task_name: 'example')

      assert_equal '01-inspect', task.progress.current_step_name
      arranged = File.join(project, 'workspace', 'example', '01-inspect', 'checks', 'writing-policy.md')
      assert_equal writing_policy, File.read(arranged)
      saved = AgenticRuntime::Workspace.new(root: project).find('example')
      assert_equal '01-inspect', saved.progress.current_step_name
    end
  end
end
