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
  limit = limit.to_i unless limit.nil?
  DrOtto.bounce_once(limit, pretend: true)
end

task :bounce_once, :limit do |t, args|
  limit = args[:limit]
  limit = limit.to_i unless limit.nil?
  DrOtto.bounce_once(limit)
end

task :bounce, :limit do |t, args|
  limit = args[:limit]
  limit = limit.to_i unless limit.nil?
  DrOtto.bounce(limit)
end

task :run do
  DrOtto.run
end

task :run_once do
  DrOtto.run_once
end
