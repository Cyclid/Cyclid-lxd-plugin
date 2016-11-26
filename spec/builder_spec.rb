# frozen_string_literal: true
require 'spec_helper'

class Image
  def fingerprint
    '0123456789abcdef'
  end
end

class RemoteImage
  def metadata
    Image.new
  end
end

describe Cyclid::API::Plugins::Lxd do

  subject do
    Cyclid::API::Plugins::Lxd.new
  end

  let :fingerprint do
    fingerprint_id
  end

  it 'should create a new instance' do
    expect{ subject }.to_not raise_error
  end

  context 'obtaining a build host' do

    before do
      expect_any_instance_of(Hyperkit::Client).to receive(:create_container)
      expect_any_instance_of(Hyperkit::Client).to receive(:start_container)
      expect_any_instance_of(Hyperkit::Client).to receive_message_chain('container.status').and_return('Running')
    end

    it 'returns a host with "lxdapi" as the only valid transport' do
      expect_any_instance_of(Hyperkit::Client).to receive(:image_by_alias).and_return(Image.new)

      buildhost = subject.get
      expect(buildhost.transports).to match_array(['lxdapi'])
    end

    context 'when the template exists on the server' do

      before do
        expect_any_instance_of(Hyperkit::Client).to receive(:image_by_alias).and_return(Image.new)
      end

      it 'returns a host when called with default arguments' do
        expect{ subject.get }.to_not raise_error
      end

      it 'returns a host when pass an OS in the arguments' do
        buildhost = nil
        expect{ buildhost = subject.get(os: 'example_test') }.to_not raise_error
        expect(buildhost[:distro]).to eq('example')
        expect(buildhost[:release]).to eq('test')
      end

   end

    context 'when the template does not exist on the server' do

      before do
        expect_any_instance_of(Hyperkit::Client).to receive(:image_by_alias).and_raise(Hyperkit::NotFound)
        expect_any_instance_of(Hyperkit::Client).to receive(:create_image_from_remote).and_return(RemoteImage.new)
        expect_any_instance_of(Hyperkit::Client).to receive(:create_image_alias)
      end

      it 'returns a host when called with default arguments' do
        expect{ subject.get }.to_not raise_error
      end

      it 'returns a host when pass an OS in the arguments' do
        buildhost = nil
        expect{ buildhost = subject.get(os: 'example_test') }.to_not raise_error
        expect(buildhost[:distro]).to eq('example')
        expect(buildhost[:release]).to eq('test')
      end

    end
  end

  context 'releasing a build host' do
    before do
      expect_any_instance_of(Hyperkit::Client).to receive(:stop_container)
      expect_any_instance_of(Hyperkit::Client).to receive(:delete_container)
      expect_any_instance_of(Hyperkit::Client).to receive_message_chain('container.status').and_return('Stopped')
    end

    it 'releases a build host' do
      buildhost = double(Cyclid::API::Plugins::LxdHost)
      expect(buildhost).to receive(:[]).with(:host).and_return('test')

      expect{ subject.release(nil, buildhost) }.to_not raise_error
    end
  end

end
