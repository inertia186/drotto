require 'bundler/gem_tasks'
require 'rake/testtask'
require 'yard'
require 'drotto'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
  t.ruby_opts << if ENV['HELL_ENABLED']
    '-W2'
  else
    '-W1'
  end
end

YARD::Rake::YardocTask.new do |t|
  t.files = ['lib/**/*.rb']
end

task default: :test

task :console do
  exec "irb -r drotto -I ./lib"
end

task :report, :limit do |t, args|
  limit = args[:limit]
  DrOtto.bounce_once(limit, pretend: true)
end

task :bounce_once, :limit do |t, args|
  limit = args[:limit] || '200'
  DrOtto.bounce_once(limit)
end

task :bounce, :limit do |t, args|
  limit = args[:limit] || '200'
  DrOtto.bounce(limit)
end

task :bounce_stream do
  DrOtto.bounce_stream
end

task :manual_bounce, :trx_id do |t, args|
  DrOtto.manual_bounce(args[:trx_id])
end

task :run do
  DrOtto.run
end

task :run_once do
  DrOtto.run_once
end

task :state do
  DrOtto.state
end

task :usage, :account_name, :days do |t, args|
  DrOtto.usage(args)
end
