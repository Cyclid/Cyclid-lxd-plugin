# frozen_string_literal: true
require 'spec_helper'

describe Cyclid::API::Plugins::Lxd do

  it 'should create a new instance' do
    expect{ Cyclid::API::Plugins::Lxd.new }.to_not raise_error
  end

end
