# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'brule'
  s.version     = '0.4.0'
  s.date        = '2020-05-01'
  s.summary     = 'Split and orchestrate complex business rules'
  s.authors     = ['Nicolas Zermati']
  s.email       = ''
  s.files       = Dir['lib/**/*.rb'] + %w[README.md]
  s.homepage    = 'https://github.com/nicoolas25/brule-rb'
  s.license     = 'MIT'

  s.add_development_dependency 'minitest', '~> 5.14'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'sequel', '~> 5.32'
  s.add_development_dependency 'simplecov', '~> 0.18'
  s.add_development_dependency 'simplecov-lcov', '~> 0.8'
  s.add_development_dependency 'sqlite3', '~> 1.4'
end
