# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.test_files = FileList['test/**/*_test.rb']
  t.libs << 'test'
end

desc 'Run tests'
task default: :test

desc 'Console'
task :console do
  $LOAD_PATH.unshift('./lib')

  require 'irb'

  ARGV.clear
  IRB.start
end
