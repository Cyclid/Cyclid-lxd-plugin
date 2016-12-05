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
require 'websocket-client-simple'

# Top level module for the core Cyclid code.
module Cyclid
  # Module for the Cyclid API
  module API
    # Module for Cyclid Plugins
    module Plugins
      # LXD based transport
      class LxdApi < Transport
        attr_reader :exit_code, :exit_signal

        def initialize(args = {})
          args.symbolize_keys!

          Cyclid.logger.debug "args=#{args}"

          # Container name & a log target are required
          return false unless args.include?(:host) && \
                              args.include?(:log)

          @name = args[:host]
          @log = args[:log]
          Cyclid.logger.debug "log=#{@log}"

          @config = load_lxd_config(Cyclid.config.plugins)
          @client = Hyperkit::Client.new(api_endpoint: @config[:api],
                                         verify_ssl: @config[:verify_ssl],
                                         client_cert: @config[:client_cert],
                                         client_key: @config[:client_key])

          # Grab some data from the context
          ctx = args[:ctx]
          @base_env = { 'HOME' => ctx[:workspace],
                        'TERM' => 'xterm-mono' }
        end

        # Execute a command via. the LXD API
        def exec(cmd, path = nil)
          command = build_command(cmd, path)
          Cyclid.logger.debug "command=#{command}"

          # Ensure some important variables are set, like HOME & TERM
          env = @env || {}
          env = env.merge @base_env

          # Run the command...
          rc = @client.execute_command(@name,
                                       command,
                                       environment: env,
                                       wait_for_websocket: true,
                                       interactive: true,
                                       sync: false)

          # ... and then connect a Websocket and read the output
          operation = rc[:id]
          ws_secret = rc[:metadata][:fds][:'0']
          ws_url = "#{@config[:api]}/1.0/operations/#{operation}/websocket?secret=#{ws_secret}"

          closed = false
          log = @log
          WebSocket::Client::Simple.connect ws_url do |ws|
            ws.on :message do |msg|
              close if msg.data.empty?
              # Strip out any XTerm control characters and convert lint endings
              data = msg.data.force_encoding('UTF-8')
                        .gsub(/\r\n/, "\n")
                        .gsub(/\r+/, "\n")
                        .gsub(/\033\[(.?\d+\D?|\w+)/, '')

              log.write data
            end
            ws.on :open do
              Cyclid.logger.debug 'websocket opened'
              closed = false
            end
            ws.on :close do |e|
              Cyclid.logger.debug "websocket closed: #{e}"
              closed = true
            end
            ws.on :error do |e|
              Cyclid.logger.debug "websocket error: #{e}"
            end
          end

          # Wait until the Websocket thread has finished.
          loop do
            break if closed
            sleep 1
          end

          # Get exit status
          status = @client.operation(operation)
          Cyclid.logger.debug "status=#{status.inspect}"

          @exit_code = status[:metadata][:return]
          @exit_code.zero? ? true : false
        end

        # Copy data from a local IO object to a remote file via. the API
        def upload(io, path)
          @client.push_file(io, @name, path)
        end

        # Copy a data from remote file to a local IO object
        def download(io, path)
          @client.pull_file(@name, path, io)
        end

        # Register this plugin
        register_plugin 'lxdapi'

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

          lxd_config[:client_cert] = File.join(%w(/ etc cyclid lxd_client.crt)) \
            unless lxd_config.key? :client_cert
          lxd_config[:client_key] = File.join(%w(/ etc cyclid lxd_client.key)) \
            unless lxd_config.key? :client_key

          lxd_config[:verify_ssl] = false \
            unless lxd_config.key? :verify_ssl

          lxd_config
        end

        def build_command(cmd, path = nil)
          command = []
          command << "cd #{path}" if path
          command << cmd
          "sh -l -c '#{command.join(';')}'"
        end
      end
    end
  end
end
