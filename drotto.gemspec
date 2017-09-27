# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'drotto/version'

Gem::Specification.new do |spec|
  spec.name = 'drotto'
  spec.version = DrOtto::VERSION
  spec.authors = ['Anthony Martin']
  spec.email = ['drotto@martin-studio.com']

  spec.summary = %q{Pay-to-play voting bot.}
  spec.description = %q{Where you bid for votes/}
  spec.homepage = 'https://github.com/inertia186/drotto'
  spec.license = 'CC0 1.0'

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test)/}) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'rake', '~> 12.0.0'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-line'
  spec.add_development_dependency 'minitest-proveit'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'vcr'
  spec.add_development_dependency 'faraday'
  spec.add_development_dependency 'typhoeus'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'codeclimate-test-reporter', '~> 0.5.2'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'delorean'

  spec.add_dependency 'krang', '0.0.1rc9'
  spec.add_dependency 'rdiscount'
  spec.add_dependency 'steem_api'
end
