# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'brule'
  s.version     = '0.3.1'
  s.date        = '2020-05-01'
  s.summary     = 'Split and orchestrate complex business rules'
  s.authors     = ['Nicolas Zermati']
  s.email       = ''
  s.files       = Dir['lib/**/*.rb'] + %w[README.md]
  s.homepage    = 'https://github.com/nicoolas25/brule-rb'
  s.license     = 'MIT'

  s.add_development_dependency 'minitest', '~> 5.14'
  s.add_development_dependency 'rake', '~> 13.0'
end
