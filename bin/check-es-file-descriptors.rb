#! /usr/bin/env ruby
#
#   check-es-file-descriptors
#
# DESCRIPTION:
#   This plugin checks the ElasticSearch file descriptor usage, using the
#     elasticsearch gem
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: elasticsearch
#   gem: aws_es_transport
#
# USAGE:
#   
#
# NOTES:
#   Tested with ES 1.7.6, 2.4.3, 5.1.1 via docker,
#   and 1.5.2 and 2.3.2 via AWS ElasticSearch
#
# LICENSE:
#   Author: S. Zachariah Sprackett <zac@sprackett.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'elasticsearch'
require 'aws_es_transport'
require 'sensu-plugins-elasticsearch'

#
# ES File Descriptiors
#
class ESFileDescriptors < Sensu::Plugin::Check::CLI
  include ElasticsearchCommon

  option :transport,
         long: '--transport TRANSPORT',
         description: 'Transport to use to communicate with ES. Use "AWS" for signed AWS transports.'

  option :region,
         long: '--region REGION',
         description: 'Region (necessary for AWS Transport)'

  option :profile,
         long: '--profile PROFILE',
         description: 'AWS Profile (optional for AWS Transport)'

  option :host,
         description: 'Elasticsearch host',
         short: '-h HOST',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'Elasticsearch port',
         short: '-p PORT',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 9200

  option :timeout,
         description: 'Elasticsearch query timeout in seconds',
         short: '-t SECS',
         long: '--timeout SECS',
         proc: proc(&:to_i),
         default: 30

  option :critical,
         description: 'Critical percentage of FD usage',
         short: '-c PERCENTAGE',
         proc: proc(&:to_i),
         default: 90

  option :warning,
         description: 'Warning percentage of FD usage',
         short: '-w PERCENTAGE',
         proc: proc(&:to_i),
         default: 80

  option :user,
         description: 'Elasticsearch User',
         short: '-u USER',
         long: '--user USER'

  option :password,
         description: 'Elasticsearch Password',
         short: '-P PASS',
         long: '--password PASS'

  option :scheme,
         description: 'Elasticsearch connection scheme, defaults to https for authenticated connections',
         short: '-s SCHEME',
         long: '--scheme SCHEME'

  option :debug,
         description: 'Enable debug output',
         long: '--debug'

  def acquire_es_version
    c_stats = client.cluster.stats @options
    puts "DEBUG es_ver: #{c_stats['nodes']['versions']}" if config[:debug]
    c_stats['nodes']['versions'][0]
  end

  def es_version
    @es_version ||= Gem::Version.new(acquire_es_version)
  end

  def acquire_open_fds
    node_stats = client.nodes.stats @options
    keys = node_stats['nodes'].keys

    # we're going to find the node with the highest open FDs
    open_fds = []
    keys.each do |my_key|
      puts "DEBUG open file descriptors for #{my_key} #{node_stats['nodes'][my_key]['process']['open_file_descriptors']}" if config[:debug]
      open_fds << node_stats['nodes'][my_key]['process']['open_file_descriptors']
    end
    puts "DEBUG max of open fds: #{open_fds.max}" if config[:debug]
    return open_fds.max
  end

  def acquire_max_fds
    node_stats = client.nodes.stats @options
    node_info = client.nodes.info {timeout=config[:timeout]} # ES1.X doesn't like the 's'
    keys = node_stats['nodes'].keys

    my_max = 0
    keys.each do |my_key|
      if es_version < Gem::Version.new('2.0.0')
        my_max = node_info['nodes'][my_key]['process']['max_file_descriptors']
      else
        my_max = node_stats['nodes'][my_key]['process']['max_file_descriptors']
      end
    end
    puts "DEBUG max file descriptors: #{my_max}" if config[:debug]
    return my_max
  end

  def run
    @options = {}
    @options[:timeout] = "#{config[:timeout]}s"

    open_fds = acquire_open_fds
    max_fds = acquire_max_fds

    used_percent = ((open_fds.to_f / max_fds.to_f) * 100).to_i

    if used_percent >= config[:critical]
      critical "fd usage #{used_percent}% exceeds #{config[:critical]}% (#{open_fds}/#{max_fds})"
    elsif used_percent >= config[:warning]
      warning "fd usage #{used_percent}% exceeds #{config[:warning]}% (#{open_fds}/#{max_fds})"
    else
      ok "fd usage at #{used_percent}% (#{open_fds}/#{max_fds})"
    end
  end
end
