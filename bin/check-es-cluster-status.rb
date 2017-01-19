#! /usr/bin/env ruby
#
#  check-es-cluster-status
#
# DESCRIPTION:
#   This plugin checks the ElasticSearch cluster status, using the
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
#   check-es-cluster-status.rb --help
#
# NOTES:
#   Tested with ES 1.7.6, 2.4.3, 5.1.1 via docker
#   Does NOT work with AWS ElasticSearch
#
# LICENSE:
#   Copyright 2012 Sonian, Inc <chefs@sonian.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'elasticsearch'
require 'aws_es_transport'
require 'sensu-plugins-elasticsearch'

#
# ES Cluster Status
#
class ESClusterStatus < Sensu::Plugin::Check::CLI
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

  option :master_only,
         description: 'Use master Elasticsearch server only',
         short: '-m',
         long: '--master-only',
         default: false

  option :timeout,
         description: 'Elasticsearch query timeout in seconds',
         short: '-t SECS',
         long: '--timeout SECS',
         proc: proc(&:to_i),
         default: 30

  option :status_timeout,
         description: 'Sets the time to wait for the cluster status to be green',
         short: '-T SECS',
         long: '--status_timeout SECS',
         proc: proc(&:to_i)

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

  def master?
    c_state = client.cluster.state @options
    node_stats = client.nodes.stats @options

    puts "DEBUG master node: #{c_state['master_node']}" if config[:debug]
    puts "DEBUG this node: #{node_stats['nodes'].keys.first}" if config[:debug]
    master = c_state['master_node']

    node_stats['nodes'].keys.first == master
  end

  def acquire_status
    acquire_es_version
    c_health = client.cluster.health @health_options
    puts "DEBUG health: #{c_health}" if config[:debug]

    c_health['status'].downcase
  end

  def run
    @options = {}
    @health_options = {}
    if config[:status_timeout].nil?
      @options[:timeout] = "#{config[:timeout]}s"
    else
      @health_options[:wait_for_status] = 'green'
      @options[:timeout] = "#{config[:status_timeout]}s"
    end

    if !config[:master_only] || master?
      case acquire_status
      when 'green'
        ok 'Cluster is green'
      when 'yellow'
        warning 'Cluster is yellow'
      when 'red'
        critical 'Cluster is red'
      end
    else
      ok 'Not the master'
    end
  end
end
