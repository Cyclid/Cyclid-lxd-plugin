# frozen_string_literal: true
require 'bundler/setup'
require 'simplecov'

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/test/'
end

require_relative '../../Cyclid/spec/spec_setup'

require_relative '../lib/cyclid/plugins/transport/lxdapi'
require_relative '../lib/cyclid/plugins/builder/lxd'
