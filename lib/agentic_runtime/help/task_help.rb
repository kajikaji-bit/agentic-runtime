# frozen_string_literal: true

module AgenticRuntime
  module Help
    class TaskHelp
      attr_reader :body, :usage

      def initialize(action: nil)
        case action
        when 'create'
          @usage = 'agentic-runtime task create <task> --workflow <name>'
          @body = <<~BODY
            タスクを作ってワークスペースを用意する

            Usage:
              #{@usage}

            Options:
              --workflow <name>  カタログのワークフローの名前
              -h, --help         ヘルプを表示する
          BODY
        when 'close'
          @usage = 'agentic-runtime task close <task>'
          @body = <<~BODY
            タスクをクローズする

            Usage:
              #{@usage}

            Options:
              -h, --help  ヘルプを表示する
          BODY
        else
          @usage = 'agentic-runtime task <action> [arguments]'
          @body = <<~BODY
            Usage:
              #{@usage}

            Commands:
              task create  タスクを作ってワークスペースを用意する
              task close   タスクをクローズする

            Options:
              -h, --help  ヘルプを表示する

            アクションごとの使い方は `agentic-runtime task <action> --help` で確かめる。
          BODY
        end
        freeze
      end
    end
  end
end
