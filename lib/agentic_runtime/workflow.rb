# frozen_string_literal: true

require 'yaml'
require_relative 'step/step_definition'

module AgenticRuntime
  # Workflow は Read Model として、読み取った定義と原文を保持し、元ファイルの変更から切り離す。
  class Workflow
    attr_reader :name, :steps, :source

    def self.parse(source)
      data = YAML.safe_load(source)
      raise ArgumentError, 'ワークフローには名前とステップが必要です' unless data.is_a?(Hash)

      new(name: data.fetch('name'), steps: definitions(data.fetch('steps')), source: source)
    rescue Psych::Exception, KeyError, TypeError => e
      raise ArgumentError, "ワークフローが不正です: #{e.message}"
    end

    private

    def initialize(name:, steps:, source:)
      raise ArgumentError, 'ワークフロー名が必要です' unless name.is_a?(String) && /\S/.match?(name)

      @name = name.dup.freeze
      @steps = steps.freeze
      @source = source.dup.freeze
      freeze
    end

    def self.definitions(entries)
      raise ArgumentError, 'ステップが必要です' unless entries.is_a?(Array) && entries.any?

      steps = entries.map { |entry| definition(entry) }
      names = steps.map(&:name)
      raise ArgumentError, 'ステップ名が重複しています' unless names.uniq == names

      steps
    end

    def self.definition(entry)
      raise ArgumentError, 'ステップには名前と仕事内容が必要です' unless entry.is_a?(Hash)

      attributes = entry.compact
      Step::StepDefinition.new(name: attributes.fetch('name'), description: attributes.fetch('description'),
                               artifacts: attributes.fetch('artifacts', []), checks: attributes.fetch('checks', []),
                               approval: attributes['approval'])
    end

    private_class_method :definition

    private_class_method :new, :definitions
  end
end
