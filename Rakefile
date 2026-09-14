# frozen_string_literal: true

require 'rake/testtask'

LINT_PATHS = %w[bin/steering lib test hooks].select { |path| File.exist?(path) }.freeze
RUBOCOP_PATHS = (LINT_PATHS + %w[Rakefile Gemfile]).freeze

desc 'Run the complete test suite'
Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.warning = false
end

desc 'Run tests and enforce minimum coverage'
task :coverage do
  require 'simplecov'
  SimpleCov.start do
    command_name 'Minitest'
    enable_coverage :branch
    cover(*%w[bin/steering hooks/**/*.rb lib/**/*.rb])
    minimum_coverage line: 90, branch: 80
  end
  ARGV.clear
  load File.expand_path('test/run.rb', __dir__)
end

desc 'Inspect Ruby files with RuboCop'
task :rubocop do
  sh(*(%w[bundle exec rubocop --cache false] + RUBOCOP_PATHS))
end

desc 'Inspect Ruby files with Reek'
task :reek do
  sh(*(%w[bundle exec reek] + LINT_PATHS))
end

desc 'Run all static analysis'
task lint: %i[rubocop reek]

desc 'Run every development gate'
task default: %i[test lint]
