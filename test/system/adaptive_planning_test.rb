# frozen_string_literal: true

require_relative '../helper'

class TestAdaptivePlanning < Minitest::Test
  include Helper

  %w[claude codex cursor].each do |runtime|
    define_method("test_adaptive_planning_while_in_progress_at_#{runtime}") do
      Dir.mktmpdir('agentic-runtime-') do |project|
        session_id = "adapt-#{runtime}-session"
        env = session_env(runtime, session_id)
        FileUtils.mkdir_p(File.join(project, '.agents/workflows'))
        File.write(File.join(project, '.agents/workflows/adapt-flow.yaml'), <<~YAML)
          name: adapt-flow
          description: 未着手の仕事を変更して作業を続ける
          steps:
            - name: 01-first
              description: 最初の仕事をする
            - name: 02-last
              description: 最後の仕事をする
        YAML

        run_cli(project, 'task create example --workflow adapt-flow', env: env)
        assert_instruction run_stop(project, runtime, session_id: session_id), runtime, '最初の仕事をする'
        completed = run_cli(project, 'step complete example 01-first', env: env)
        assert_equal '02-last', completed.body.fetch('next_step')

        File.write(File.join(project, 'workspace/example/workflow.yaml'), <<~YAML)
          name: adapt-flow
          description: 未着手の仕事を変更して作業を続ける
          steps:
            - name: 01-first
              description: 最初の仕事をする
            - name: 02-review
              description: 分かったことを見直す
            - name: 03-last
              description: 見直した結果を届ける
        YAML

        assert_instruction run_stop(project, runtime, session_id: session_id), runtime, '分かったことを見直す'
        assert_equal "02-review\n", File.read(File.join(project, 'workspace/example/current_step'))

        completed = run_cli(project, 'step complete example 02-review', env: env)
        assert_equal '03-last', completed.body.fetch('next_step')
        assert_instruction run_stop(project, runtime, session_id: session_id), runtime, '見直した結果を届ける'

        completed = run_cli(project, 'step complete example 03-last', env: env)
        assert_nil completed.body.fetch('next_step')
        assert_instruction run_stop(project, runtime, session_id: session_id), runtime, 'タスク example をクローズした。'
        assert_equal "closed\n", File.read(File.join(project, 'workspace/example/state'))
      end
    end
  end
end
