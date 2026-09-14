# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/step/step_directory'
require_relative '../../lib/agentic_runtime/catalog'
require_relative '../../lib/agentic_runtime/workspace'
require_relative '../../lib/agentic_runtime/session'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/task/create_task'

class TestStepDirectory < Minitest::Test
  def test_retrieve_the_step_instruction_from_the_saved_workflow
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

      catalog = AgenticRuntime::Catalog.new(root: project)
      workspace = AgenticRuntime::Workspace.new(root: project)
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      assignee = AgenticRuntime::Session.from(runtime: 'codex', id: 'review-session')
      create_task = AgenticRuntime::Task::CreateTask.new(workspace: workspace, catalog: catalog, assets: assets)
      create_task.create(name: 'example', goal: '変更を確認して公開する', workflow_name: 'release-review', session: assignee)
      FileUtils.rm_rf(workflows)
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_name: 'example', step_name: '02-summarize')

      directive = directory.directive

      assert_includes directive.body, '確認した結果をまとめる'
      refute_includes directive.body, '公開する変更点を確認する'
      assert_includes directive.body, File.join(project, 'workspace', 'example')
      assert_includes directive.body, 'steering step complete example 02-summarize'
    end
  end

  def test_retrieve_the_step_instruction_that_requests_an_approval
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents', 'workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        description: 公開前に変更内容を確認する
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
            approval: required
      YAML

      catalog = AgenticRuntime::Catalog.new(root: project)
      workspace = AgenticRuntime::Workspace.new(root: project)
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      assignee = AgenticRuntime::Session.from(runtime: 'codex', id: 'review-session')
      create_task = AgenticRuntime::Task::CreateTask.new(workspace: workspace, catalog: catalog, assets: assets)
      create_task.create(name: 'example', goal: '変更を確認して公開する', workflow_name: 'release-review', session: assignee)
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_name: 'example', step_name: '01-inspect')

      directive = directory.directive

      assert_includes directive.body, '## 承認を依頼する'
    end
  end

  def test_retrieve_the_step_artifacts
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      step_path = File.join(project, 'workspace', 'example', '01-inspect')
      other_step_path = File.join(project, 'workspace', 'example', '02-summarize')
      FileUtils.mkdir_p(step_path)
      FileUtils.mkdir_p(other_step_path)
      File.write(File.join(other_step_path, 'result.md'), '別のステップの結果')
      File.write(File.join(project, 'result.md'), 'プロジェクト直下の結果')
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_name: 'example', step_name: '01-inspect')

      assert_empty directory.artifacts

      File.write(File.join(step_path, 'result.md'), '確認結果')
      artifacts = directory.artifacts
      assert_equal ['result.md'], artifacts

      File.write(File.join(step_path, 'notes.md'), '確認の記録')

      assert_equal %w[notes.md result.md], directory.artifacts
      assert_equal ['result.md'], artifacts
    end
  end

  def test_retrieve_the_step_checklists
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      checks = File.join(project, '.agents', 'checks')
      step_checks = File.join(project, 'workspace', 'example', '01-inspect', 'checks')
      FileUtils.mkdir_p(checks)
      File.write(File.join(checks, 'writing-policy.md'), <<~MARKDOWN)
        - [ ] 本文が日本語で書かれている
        - [ ] 同じ対象の呼び方が揃っている
      MARKDOWN
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_name: 'example', step_name: '01-inspect')

      assert_empty directory.checklists

      FileUtils.mkdir_p(step_checks)
      partially_checked = <<~MARKDOWN
        - [x] 本文が日本語で書かれている
        - [ ] 同じ対象の呼び方が揃っている
      MARKDOWN
      File.write(File.join(step_checks, 'writing-policy.md'), partially_checked)
      checklists = directory.checklists
      assert_equal ['writing-policy'], checklists.keys
      assert_equal partially_checked, checklists.fetch('writing-policy').body
      refute_predicate checklists.fetch('writing-policy'), :checked?

      File.write(File.join(step_checks, 'writing-policy.md'), <<~MARKDOWN)
        - [x] 本文が日本語で書かれている
        - [x] 同じ対象の呼び方が揃っている
      MARKDOWN

      assert_predicate directory.checklists.fetch('writing-policy'), :checked?
      refute_predicate checklists.fetch('writing-policy'), :checked?
    end
  end
end
