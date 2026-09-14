# frozen_string_literal: true

require 'erb'

module AgenticRuntime
  module Step
    # Directive は Read Model として、取得済みの仕事を指示文に組み立てて保持し、取得や配送を追加で行わない。
    class Directive
      attr_reader :body

      def initialize(task_name:, step_definition:, workspace_path:)
        template = ERB.new(<<~'BODY', trim_mode: '-')
          以下の指示に従ってステップを実行してください。

          ## やること
          <%= step_definition.description %>

          ## ワークスペース
          <%= workspace_path %>
          進行中のステップは <%= step_definition.name %> にある。

          <%- if step_definition.checks.any? -%>
          ## チェックリスト
          <%- step_definition.checks.each do |name| -%>
          - <%= step_definition.name %>/checks/<%= name %>.md
          <%- end -%>

          <%- end -%>
          <%- if step_definition.approval_required? -%>
          ## 承認を依頼する
          このステップの完了には承認が必要。ユーザーへ承認を求め、ターンを終了する。

          ## ステップを完了させる
          steering step complete <%= task_name %> <%= step_definition.name %> --approval-evidence '<承認者本人の発言>'
          <%- else -%>
          ## ステップを完了させる
          steering step complete <%= task_name %> <%= step_definition.name %>
          <%- end -%>
        BODY
        @body = template.result_with_hash(task_name: task_name, step_definition: step_definition,
                                          workspace_path: workspace_path)
        @body.freeze
        freeze
      end
    end
  end
end
