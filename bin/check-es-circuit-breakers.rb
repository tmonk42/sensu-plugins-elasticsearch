#! /usr/bin/env ruby
#
#  check-es-circuit-breakers
#
# DESCRIPTION:
#   This plugin checks whether the ElasticSearch circuit breakers have been tripped,
#   using the elasticsearch gem
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
#   check-es-circuit-breakers.rb --help
#
# NOTES:
#   Tested with ES 1.7.6, 2.4.3, 5.1.1 via docker,
#   and 1.5.2 and 2.3.2 via AWS ElasticSearch
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

class ESCircuitBreaker < Sensu::Plugin::Check::CLI
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
         short: '-t TIMEOUT',
         long: '--timeout TIMEOUT',
         proc: proc(&:to_i),
         default: 30

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

  option :localhost,
         description: 'only check local node',
         short: '-l',
         long: '--localhost',
         boolean: true,
         default: false

  option :debug,
         description: 'Enable debug output',
         long: '--debug'

  def breaker_status
    options = {}

    stats = client.nodes.stats

    breakers = {}

    stats['nodes'].each_pair do |_node, stat|
      host = config[:host]
      puts "DEBUG node: #{_node}" if config[:debug]
      breakers[host] = {}
      breakers[host]['breakers'] = []
      stat.each_pair do |key, val|
        if key == 'breakers'
          val.each_pair do |bk, bv|
            puts "DEBUG #{bk} #{bv}" if config[:debug]
            if bv['tripped'] != 0
              breakers[host]['breakers'] << bk
            end
          end
        end
      end
    end
    breakers
  end

  def run
    breakers = breaker_status
    tripped = false
    breakers.each_pair { |_k, v| tripped = true unless v['breakers'].empty? }
    if tripped
      critical "Circuit Breakers: #{breakers.each_pair { |k, _v| k }} trippped!"
    else
      ok 'All circuit breakers okay'
    end
  end
end
