# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_delegate/version'

Gem::Specification.new do |spec|
  spec.name          = 'active_delegate'
  spec.version       = ActiveDelegate::VERSION
  spec.authors       = ['Jonian Guveli']
  spec.email         = ['jonian@hardpixel.eu']
  spec.summary       = 'Delegate ActiveRecord model attributes and associations'
  spec.description   = 'Stores and retrieves delegatable data through attributes on an ActiveRecord class, with support for translatable attributes.'
  spec.homepage      = 'https://github.com/hardpixel/active-delegate'
  spec.license       = 'MIT'
  spec.files         = Dir['{lib/**/*,[A-Z]*}']
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 5.0', '< 7.0'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 10.0'
end
