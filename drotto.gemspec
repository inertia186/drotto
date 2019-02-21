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

  spec.add_development_dependency 'bundler', '~> 2.0', '>= 2.0.1'
  spec.add_development_dependency 'rake', '~> 12.3', '>= 12.3.2'
  spec.add_development_dependency 'minitest', '~> 5.10', '>= 5.10.2'
  spec.add_development_dependency 'minitest-line', '~> 0.6.3'
  spec.add_development_dependency 'minitest-proveit', '~> 1.0', '>= 1.0.0'
  spec.add_development_dependency 'webmock', '~> 3.5', '>= 3.5.1'
  spec.add_development_dependency 'vcr', '~> 4.0', '>= 4.0.0'
  spec.add_development_dependency 'simplecov', '~> 0.16.1'
  spec.add_development_dependency 'yard', '~> 0.9.18'
  spec.add_development_dependency 'pry', '~> 0.12.2'
  spec.add_development_dependency 'rb-readline', '~> 0.5', '>= 0.5.5'
  spec.add_development_dependency 'awesome_print', '~> 1.7', '>= 1.7.0'
  spec.add_development_dependency 'delorean', '~> 2.1', '>= 2.1.0'

  spec.add_dependency 'radiator', '~> 0.4', '>= 0.4.3'
  spec.add_dependency 'rdiscount', '~> 2.2', '>= 2.2.0.1'
  spec.add_dependency 'steem_api', '~> 1.1', '>= 1.1.2'
  spec.add_dependency 'activerecord', '5.1.6.1'
  spec.add_dependency 'lru_redux', '~> 1.1', '>= 1.1.0'
end
