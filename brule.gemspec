# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'brule'
  s.version     = '0.2.0'
  s.date        = '2020-05-01'
  s.summary     = 'Split and orchestrate complex business rules'
  s.authors     = ['Nicolas Zermati']
  s.email       = ''
  s.files       = %w[
    lib/brule.rb
    lib/brule/context.rb
    lib/brule/engine.rb
    lib/brule/rule.rb
    README.md
  ]
  s.homepage    = 'https://rubygems.org/gems/brule'
  s.license     = 'MIT'

  s.add_development_dependency 'minitest', '~> 5.14'
  s.add_development_dependency 'rake', '~> 13.0'
end
