# frozen_string_literal: true

# Copyright 2016 Liqwyd Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'hyperkit'

# Top level module for the core Cyclid code.
module Cyclid
  # Module for the Cyclid API
  module API
    # Module for Cyclid Plugins
    module Plugins
      # LXD build host
      class LxdHost < BuildHost
        # LXD is the only acceptable Transport
        def transports
          ['lxdapi']
        end
      end

      # LXD builder. Uses the LXD REST API to create a build host container.
      class Lxd < Builder
        def initialize
          @config = load_lxd_config(Cyclid.config.plugins)
          @client = Hyperkit::Client.new(api_endpoint: @config[:api],
                                         verify_ssl: @config[:verify_ssl],
                                         client_cert: @config[:client_cert],
                                         client_key: @config[:client_key])
        end

        # Create & return a build host
        def get(args = {})
          args.symbolize_keys!

          Cyclid.logger.debug "lxd: args=#{args}"

          # If there is one, split the 'os' into a 'distro' and 'release'
          if args.key? :os
            match = args[:os].match(/\A(\w*)_(.*)\Z/)
            distro = match[1] if match
            release = match[2] if match
          else
            # No OS was specified; use the default
            # XXX Defaults should be configurable
            distro = 'ubuntu'
            release = 'trusty'
          end

          # Find the template fingerprint for the given distribution & release
          image_alias = "#{distro}/#{release}"
          fingerprint = find_or_create_image(image_alias)
          Cyclid.logger.debug "fingerprint=#{fingerprint}"

          # Create a new instance
          name = create_name
          create_container(name, fingerprint)

          # Wait for the instance to settle
          sleep 5

          # Create a buildhost from the container details
          buildhost = LxdHost.new(host: name,
                                  name: name,
                                  username: 'root',
                                  workspace: '/root',
                                  distro: distro,
                                  release: release)

          buildhost
        end

        # Destroy the build host
        def release(_transport, buildhost)
          name = buildhost[:host]

          @client.stop_container(name)
          wait_for_container(name, 'Stopped')

          @client.delete_container(name)
        rescue StandardError => ex
          Cyclid.logger.error "LXD destroy timed out: #{ex}"
        end

        # Register this plugin
        register_plugin 'lxd'

        private

        # Load the config for the LXD Builder plugin and set defaults if they're not
        # in the config
        def load_lxd_config(config)
          config.symbolize_keys!

          lxd_config = config[:lxd] || {}
          lxd_config.symbolize_keys!
          Cyclid.logger.debug "config=#{lxd_config}"

          raise 'the LXD API URL must be provided' \
            unless lxd_config.key? :api

          lxd_config[:client_cert] = File.join(%w[/ etc cyclid lxd_client.crt]) \
            unless lxd_config.key? :client_cert
          lxd_config[:client_key] = File.join(%w[/ etc cyclid lxd_client.key]) \
            unless lxd_config.key? :client_key

          lxd_config[:verify_ssl] = false \
            unless lxd_config.key? :verify_ssl
          lxd_config[:image_server] = 'https://images.linuxcontainers.org:8443' \
            unless lxd_config.key? :image_server
          lxd_config[:instance_name] = 'cyclid-build' \
            unless lxd_config.key? :instance_name

          lxd_config
        end

        def find_or_create_image(image_alias)
          Cyclid.logger.debug "Create image #{image_alias}"
          fingerprint = ''
          begin
            image = @client.image_by_alias(image_alias)
            Cyclid.logger.debug "found image=#{image.inspect}"
            fingerprint = image.fingerprint
          rescue Hyperkit::NotFound
            Cyclid.logger.debug "Downloading image for #{image_alias}"
            image = @client.create_image_from_remote(@config[:image_server],
                                                     alias: image_alias,
                                                     protocol: 'simplestreams')

            Cyclid.logger.debug "created image=#{image.inspect}"
            fingerprint = image.metadata.fingerprint
            @client.create_image_alias(fingerprint, image_alias)
          end

          fingerprint
        end

        def create_container(name, fingerprint)
          Cyclid.logger.debug "Creating container #{name}"
          @client.create_container(name, fingerprint: fingerprint)
          @client.start_container(name)

          wait_for_container(name, 'Running')
        end

        def wait_for_container(name, state)
          29.times.each do |_t|
            status = @client.container(name).status
            break if status == state
            Cyclid.logger.debug status
            sleep 2
          end
        end

        def create_name
          base = @config[:instance_name]
          "#{base}-#{SecureRandom.hex(16)}"
        end
      end
    end
  end
end
