# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'cyclid-lxd-plugin'
  s.version     = '0.2.0'
  s.licenses    = ['Apache-2.0']
  s.summary     = 'Cyclid LXD Builder & Transport plugin'
  s.description = 'Creates LXD container based build hosts'
  s.authors     = ['Kristian Van Der Vliet']
  s.homepage    = 'https://cyclid.io'
  s.email       = 'contact@cyclid.io'
  s.files       = Dir.glob('lib/**/*')

  s.add_runtime_dependency('hyperkit', '~> 1.1')
  s.add_runtime_dependency('websocket-client-simple', '~> 0.3.0')

  s.add_runtime_dependency('cyclid', '~> 0.4')
end
