# frozen_string_literal: true

module AgenticRuntime
  module Task
    # Continuation は Service として、取得済みの進捗を判断する。仕事の取得や状態変更は行わない。
    class Continuation
      def initialize
        freeze
      end

      def decide(progress:)
        return :continue if progress.in_progress?
        return :done if progress.completed?

        :next
      end
    end
  end
end
