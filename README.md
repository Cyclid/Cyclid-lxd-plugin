Cyclid LXD plugin
==========================

This is a Builder & Transport plugin for Cyclid which creates build hosts using [LXD](https://linuxcontainers.org/lxd/).

The plugin is built on top of the [Hyperkit Gem](https://github.com/jeffshantz/hyperkit), which provides a Ruby interface to the LXD API.

# Installation

Install the plugin and restart Cyclid & Sidekiq

```
$ gem install cyclid-lxd-plugin
$ service cyclid restart
$ service sidekiq restart
```

# Configuration

| Option | Required? | Default | Notes |
| --- | --- | --- | --- |
| api | Y | *None* | Your LXD server API |
| verify\_ssl | N | false | Enable SSL validation for the LXD server API |
| client\_cert | N | `/etc/cyclid/lxd_client.crt` | Your LXD client certificate |
| client\_key | N | `/etc/cyclid/lxd_client.key` | Your LXD client certificate key |
| image\_server | N | `https://images.linuxcontainers.org:8443` | LXD image server URL |
| instance\_name | N | cyclid-build | Cyclid build host name prefix |

The only option which is required is _api_. This should be the URL of an LXD server which is accessable from Cyclid. The _client\_cert_ and _client\_key_ must be a valid registered certificate on the LXD server.

## Client certificate

You can create a new certificate using OpenSSL:

```
cyclid-server$ openssl req -x509 -newkey rsa:2048 -keyout /etc/cyclid/lxd_client.key.secure -out /etc/cyclid/lxd_client.crt -days 3650
cyclid-server$ openssl rsa -in /etc/cyclid/lxd_client.key.secure -out /etc/cyclid/lxd_client.key
```

You can then copy the client certificate (``) to your LXD server and trust it:

```
lxd-server$ lxc config trust add lxd_client.crt
```

# Usage

Install & configure the plugin as above, and configure Cyclid to use the plugin for it's Builder by setting the _builder_ option to "lxd". Build hosts created with LXD will automatically select the "lxdapi" transport.

## Example

Create instances using an LXD server running on `example.com` and verify that SSL certificate:

```yaml
server:
  ...
  builder: lxd
  ...
  plugins:
    lxd:
      api: https://example.com:8443
      verify_ssl: true
```
