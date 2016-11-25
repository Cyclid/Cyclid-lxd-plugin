# frozen_string_literal: true
require 'spec_helper'

def ctx_hash
  { workspace: '/tmp' }
end

def metadata_hash
  { metadata: { fds: { '0': '01234556789abcdef' } } }
end

def status_hash
  { metadata: { return: 0 } }
end

def instance_name
  'test-1234'
end

class Empty
  def data
    String.new
  end
end

describe Cyclid::API::Plugins::LxdApi do

  let :ctx do
    ctx_hash
  end

  let :exec_metadata do
    metadata_hash
  end

  let :operation_status do
    status_hash
  end

  let :empty_data do
    Empty.new
  end

  let :name do
    instance_name
  end

  subject do
      Cyclid::API::Plugins::LxdApi.new(host: instance_name,
                                       log: STDERR,
                                       ctx: ctx_hash)
  end

  it 'should create a new instance' do
    expect { subject }.to_not raise_error
  end

  it 'should execute a command' do
    expect_any_instance_of(Hyperkit::Client).to receive(:execute_command).and_return(exec_metadata)
    expect_any_instance_of(Hyperkit::Client).to receive(:operation).and_return(operation_status)

    ws = double(WebSocket::Client::Simple::Client)
    expect(ws).to receive(:on).with(:message).and_yield(empty_data)
    expect(ws).to receive(:on).with(:open).and_yield
    expect(ws).to receive(:on).with(:close).and_yield('')
    expect(ws).to receive(:on).with(:error).and_yield('')
    expect(WebSocket::Client::Simple).to receive(:connect).and_yield(ws)

    expect( subject.exec('/bin/true') ).to be true
  end

  it 'should upload a file' do
    expect_any_instance_of(Hyperkit::Client).to receive(:push_file).with(nil, name, '/foo/bar')

    expect { subject.upload(nil, '/foo/bar') }.to_not raise_error
  end

  it 'should download a file' do
    expect_any_instance_of(Hyperkit::Client).to receive(:pull_file).with(name, '/foo/bar', nil)

    expect { subject.download(nil, '/foo/bar') }.to_not raise_error
  end
end
