# frozen_string_literal: true

require 'json'
require_relative 'event'

module AgenticRuntime
  class WorkspaceLog
    def initialize(root:, task_name:)
      @path = File.join(File.expand_path(root), 'workspace', task_name, 'log.jsonl').freeze
      freeze
    end

    def events
      records = File.readlines(@path, chomp: true).reject { |line| line.strip.empty? }.map { |line| JSON.parse(line) }
      records.filter_map { |record| Event.from(record) if Event::NAMES.include?(record['event']) }.freeze
    end

    def append(events)
      File.open(@path, 'a') do |file|
        Array(events).each do |event|
          at = Time.now.getlocal('+09:00').strftime('%Y-%m-%dT%H:%M:%S%:z')
          file.puts(JSON.generate({ 'at' => at, 'event' => event.name }.merge(event.attributes)))
        end
      end
      nil
    end
  end
end
