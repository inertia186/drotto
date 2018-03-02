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

  spec.add_development_dependency 'bundler', '~> 1.15', '>= 1.15.4'
  spec.add_development_dependency 'rake', '~> 12.1', '>= 12.1.0'
  spec.add_development_dependency 'minitest', '~> 5.9', '>= 5.9.0'
  spec.add_development_dependency 'minitest-line', '~> 0.6.3'
  spec.add_development_dependency 'minitest-proveit', '~> 1.0', '>= 1.0.0'
  spec.add_development_dependency 'webmock', '~> 3.1', '>= 3.1.0'
  spec.add_development_dependency 'vcr', '~> 3.0', '>= 3.0.3'
  spec.add_development_dependency 'simplecov', '~> 0.15.1'
  spec.add_development_dependency 'yard', '~> 0.9.9'
  spec.add_development_dependency 'pry', '~> 0.11.1'
  spec.add_development_dependency 'awesome_print', '~> 1.7', '>= 1.7.0'
  spec.add_development_dependency 'delorean', '~> 2.1', '>= 2.1.0'

  spec.add_dependency 'krang', '0.0.1rc11'
  spec.add_dependency 'rdiscount', '~> 2.2', '>= 2.2.0.1'
  spec.add_dependency 'steem_api', '~> 1.1', '>= 1.1.1'
  spec.add_dependency 'golos_cloud', '~> 1.1', '>= 1.1.1'
end
