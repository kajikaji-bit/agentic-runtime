# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/task/create_task'
require_relative '../../lib/agentic_runtime/catalog'
require_relative '../../lib/agentic_runtime/workspace'
require_relative '../../lib/agentic_runtime/session'

class TestCreateTask < Minitest::Test
  def test_task_creation_prepares_a_working_directory_and_assigns_the_session
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

      task = create_task.create(
        name: 'example', goal: '変更を確認して公開する', workflow_name: 'release-review', session: assignee
      )

      reloaded = AgenticRuntime::Workspace.new(root: project)
      assert_equal 'example', task.name
      assert File.directory?(File.join(project, 'workspace', 'example'))
      assert_equal 'created', reloaded.find('example').progress.task_status
      assert_equal 'example', reloaded.find_by(session: assignee).name
    end
  end
end
