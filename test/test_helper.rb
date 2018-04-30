$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'simplecov'
SimpleCov.start
SimpleCov.merge_timeout 3600

require 'drotto'

require 'minitest/autorun'

require 'webmock/minitest'
require 'vcr'
require 'yaml'
require 'pry'
require 'securerandom'
require 'delorean'

VCR.configure do |c|
  c.cassette_library_dir = 'test/fixtures/vcr_cassettes'
  c.hook_into :webmock
end

if ENV["HELL_ENABLED"]
  require "minitest/hell"
  
  class Minitest::Test
    # See: https://gist.github.com/chrisroos/b5da6c6a37ac8af5fe78
    parallelize_me! unless defined? WebMock
  end
else
  require "minitest/pride"
end

if defined? WebMock 
  WebMock.disable_net_connect!(allow_localhost: false, allow: 'codeclimate.com:443')
end

class DrOtto::Test < MiniTest::Test
  # Most likely modes: 'once' and 'new_episodes'
  VCR_RECORD_MODE = (ENV['VCR_RECORD_MODE'] || 'once').to_sym
  
  def vcr_cassette(name, options = {}, &block)
    options[:record] ||= VCR_RECORD_MODE
    options[:match_requests_on] ||= [:method, :uri, :body]
    
    VCR.use_cassette(name, options) do
      yield
    end
  end
end
