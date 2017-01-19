#! /usr/bin/env ruby
#
#   check-es-cluster-health
#
# DESCRIPTION:
#   This plugin checks the ElasticSearch cluster health and status.
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
#   Tested with ES 1.7.6, 2.4.3, 5.1.1 via docker,
#   and 1.5.2 and 2.3.2 via AWS ElasticSearch
#
# LICENSE:
#   Brendan Gibat <brendan.gibat@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'elasticsearch'
require 'aws_es_transport'
require 'sensu-plugins-elasticsearch'

#
# ES Cluster Health
#
class ESClusterHealth < Sensu::Plugin::Check::CLI
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

  option :level,
         description: 'Level of detail to check returned information ("cluster", "indices", "shards").',
         short: '-l LEVEL',
         long: '--level LEVEL',
         default: 'cluster'

  option :local,
         description: 'Return local information, do not retrieve the state from master node.',
         long: '--local',
         boolean: true

  option :port,
         description: 'Elasticsearch port',
         short: '-p PORT',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 9200

  option :scheme,
         description: 'Elasticsearch connection scheme, defaults to https for authenticated connections',
         short: '-s SCHEME',
         long: '--scheme SCHEME'

  option :password,
         description: 'Elasticsearch connection password',
         short: '-P PASSWORD',
         long: '--password PASSWORD'

  option :user,
         description: 'Elasticsearch connection user',
         short: '-u USER',
         long: '--user USER'

  option :timeout,
         description: 'Elasticsearch query timeout in seconds',
         short: '-t TIMEOUT',
         long: '--timeout TIMEOUT',
         proc: proc(&:to_i),
         default: 30

  option :debug,
         description: 'Enable debug output',
         long: '--debug'

  def acquire_es_version
    c_stats = client.cluster.stats {timeout=config[:timeout]}
    puts "DEBUG es_ver: #{c_stats['nodes']['versions']}" if config[:debug]
    c_stats['nodes']['versions'][0]
  end

  def run
    acquire_es_version
    options = {}
    unless config[:level].nil?
      options[:level] = config[:level]
    end
    unless config[:local].nil?
      options[:local] = config[:local]
    end
    unless config[:index].nil?
      options[:index] = config[:index]
    end
    options[:timeout] = "#{config[:timeout]}s"

    health = client.cluster.health options
    puts "DEBUG health: #{health}" if config[:debug]

    case health['status']
    when 'yellow'
      warning "#{config[:level]} state is Yellow"
    when 'red'
      critical "#{config[:level]} state is Red"
    when 'green'
      ok "#{config[:level]} state is green"
    else
      unknown "#{config[:level]} state is in an unknown health: #{health['status']}"
    end
  end
end
