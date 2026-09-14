# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/step/step'
require_relative '../../lib/agentic_runtime/step/step_directory'
require_relative '../../lib/agentic_runtime/catalog'
require_relative '../../lib/agentic_runtime/workspace'
require_relative '../../lib/agentic_runtime/session'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/task/create_task'

class TestStep < Minitest::Test
  def test_start_a_step
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

      definition = catalog.find('release-review').steps.first
      directory = workspace.step_directory(task_name: 'example', step_name: '01-inspect')
      step = AgenticRuntime::Step::Step.start(task_name: 'example', definition: definition, directory: directory)

      assert_equal '01-inspect', step.name
      assert_equal 'started', step.status
    end
  end

  def test_complete_a_step
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents', 'workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'review.yaml'), <<~YAML)
        name: review
        steps:
          - name: 01-inspect
            description: 変更点を確認する
            artifacts:
              - result.md
              - notes.md
            checks:
              - writing-policy
            approval: required
      YAML
      workflow = AgenticRuntime::Catalog.new(root: project).find('review')
      step_path = File.join(project, 'workspace', 'example', '01-inspect')
      FileUtils.mkdir_p(File.join(step_path, 'checks'))
      File.write(File.join(step_path, 'result.md'), '確認結果')
      File.write(File.join(step_path, 'notes.md'), '確認の記録')
      File.write(File.join(step_path, 'checks', 'writing-policy.md'), <<~MARKDOWN)
        - [x] 本文が日本語で書かれている
        - [x] 同じ対象の呼び方が揃っている
      MARKDOWN
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_name: 'example', step_name: '01-inspect')
      step = AgenticRuntime::Step::Step.start(
        task_name: 'example', definition: workflow.steps.first, directory: directory
      )

      step.complete(approval_evidence: '承認します')

      assert_equal 'completed', step.status
    end
  end

  def test_do_not_complete_a_step_without_the_approval_evidence
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents', 'workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'review.yaml'), <<~YAML)
        name: review
        steps:
          - name: 01-inspect
            description: 変更点を確認する
            approval: required
      YAML
      workflow = AgenticRuntime::Catalog.new(root: project).find('review')
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_name: 'example', step_name: '01-inspect')
      step = AgenticRuntime::Step::Step.start(
        task_name: 'example', definition: workflow.steps.first, directory: directory
      )

      assert_raises(AgenticRuntime::Step::Step::CompletionRejected) { step.complete }

      assert_equal 'started', step.status
    end
  end

  def test_do_not_complete_a_step_with_missing_artifacts
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents', 'workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'review.yaml'), <<~YAML)
        name: review
        steps:
          - name: 01-inspect
            description: 変更点を確認する
            artifacts:
              - result.md
              - notes.md
      YAML
      workflow = AgenticRuntime::Catalog.new(root: project).find('review')
      step_path = File.join(project, 'workspace', 'example', '01-inspect')
      FileUtils.mkdir_p(step_path)
      File.write(File.join(step_path, 'result.md'), '確認結果')
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_name: 'example', step_name: '01-inspect')
      step = AgenticRuntime::Step::Step.start(
        task_name: 'example', definition: workflow.steps.first, directory: directory
      )

      assert_raises(AgenticRuntime::Step::Step::CompletionRejected) { step.complete }

      assert_equal 'started', step.status
    end
  end

  def test_do_not_complete_a_step_with_unfinished_checks
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents', 'workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'review.yaml'), <<~YAML)
        name: review
        steps:
          - name: 01-inspect
            description: 変更点を確認する
            artifacts:
              - result.md
              - notes.md
            checks:
              - writing-policy
              - uses-terminology
      YAML
      workflow = AgenticRuntime::Catalog.new(root: project).find('review')
      step_path = File.join(project, 'workspace', 'example', '01-inspect')
      FileUtils.mkdir_p(File.join(step_path, 'checks'))
      File.write(File.join(step_path, 'result.md'), '確認結果')
      File.write(File.join(step_path, 'notes.md'), '確認の記録')
      File.write(File.join(step_path, 'checks', 'writing-policy.md'), <<~MARKDOWN)
        - [x] 本文が日本語で書かれている
        - [x] 同じ対象の呼び方が揃っている
      MARKDOWN
      File.write(File.join(step_path, 'checks', 'uses-terminology.md'), <<~MARKDOWN)
        - [x] 用語集にない言葉が使われていない
        - [ ] 用語集の言葉を用語集が定めた意味で使っている
      MARKDOWN
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_name: 'example', step_name: '01-inspect')
      step = AgenticRuntime::Step::Step.start(
        task_name: 'example', definition: workflow.steps.first, directory: directory
      )

      assert_raises(AgenticRuntime::Step::Step::CompletionRejected) { step.complete }

      assert_equal 'started', step.status
    end
  end
end
