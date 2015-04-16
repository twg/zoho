require 'bundler'
require 'rake/testtask'

Bundler.require

Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

task :default => :test

task :coverage do
  require 'simplecov'
  SimpleCov.start
  Rake::Task['test'].execute
end

