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

desc 'Deletes test/fixtures/vcr_cassettes/*.yml so they can be rebuilt fresh.'
task :dump_vcr do |t|
  exec 'rm -v test/fixtures/vcr_cassettes/*.yml'
end

desc 'Ruby console with drotto already required.'
task :console do
  exec "irb -r drotto -I ./lib"
end

desc 'Does reporting like rake bounce_once, but without doing the transfers.'
task :report, :limit do |t, args|
  limit = args[:limit]
  DrOtto.bounce_once(limit, pretend: true)
end

desc 'Make one attempt to process bids and quit, but each bid waits until after the window.'
task :bounce_once, :limit do |t, args|
  limit = args[:limit] || '200'
  DrOtto.bounce_once(limit)
end

desc 'Process bids continuously, but each bid waits until after the window.'
task :bounce, :limit do |t, args|
  limit = args[:limit] || '200'
  DrOtto.bounce(limit)
end

desc 'Process bids continuously without waiting for the window.'
task :bounce_stream do
  DrOtto.bounce_stream
end

desc 'Do a manual bounce by passing the original bid transaction id.'
task :manual_bounce, :trx_id do |t, args|
  DrOtto.manual_bounce(args[:trx_id])
end

desc 'Process bids continuously.'
task :run do
  DrOtto.run
end

desc 'Make one attempt to process bids and quit.'
task :run_once do
  DrOtto.run_once
end

desc 'Returns the current state of the bot.  Can be used by external scripts to see if the bot has stopped voting.'
task :state do
  DrOtto.state
end

desc 'Check usage for the last 7 days.  Pass account name and number of days as arguments, for example: rake usage[drotto,90] to check the account named drotto, over 90 days.'
task :usage, :account_name, :days do |t, args|
  DrOtto.usage(args)
end

desc 'Audit bidder.'
task :audit_bidder, :account_name, :bidder, :symbol, :days do |t, args|
  DrOtto.audit_bidder(args)
end
