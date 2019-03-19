#! /usr/bin/env ruby
#
#   check-es-heap
#
# DESCRIPTION:
#   This plugin checks ElasticSearch's Java heap usage using the
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
#   gem: aws-es-transport
#
# USAGE:
#   check-heap.rb --help
#
# NOTES:
#   Tested with ES 0.90.13, 1.7.6, 2.4.3, 5.1.1 via docker,
#   and 1.5.2 and 2.3.2 via AWS ElasticSearch
#
# LICENSE:
#  Copyright 2012 Sonian, Inc <chefs@sonian.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'elasticsearch'
require 'aws-es-transport'
require 'sensu-plugins-elasticsearch'

#
# ES Heap
#
class ESHeap < Sensu::Plugin::Check::CLI
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

  option :warn,
         short: '-w N',
         long: '--warn N',
         description: 'Heap used in bytes WARNING threshold',
         proc: proc(&:to_i),
         default: 0

  option :timeout,
         description: 'Elasticsearch query timeout in seconds',
         short: '-t TIMEOUT',
         long: '--timeout TIMEOUT',
         proc: proc(&:to_i),
         default: 30

  option :crit,
         short: '-c N',
         long: '--crit N',
         description: 'Heap used in bytes CRITICAL threshold',
         proc: proc(&:to_i),
         default: 0

  option :percentage,
         short: '-P',
         long: '--percentage',
         description: 'Use the WARNING and CRITICAL threshold numbers as percentage indicators of the total heap available',
         default: false

  option :user,
         description: 'Elasticsearch User',
         short: '-u USER',
         long: '--user USER'

  option :password,
         description: 'Elasticsearch Password',
         short: '-W PASS',
         long: '--password PASS'

  option :scheme,
         description: 'Elasticsearch connection scheme, defaults to https for authenticated connections',
         short: '-s SCHEME',
         long: '--scheme SCHEME'

  option :debug,
         description: 'Enable debug output',
         long: '--debug'

  def acquire_heap_data(return_max = false)
    stats = client.cluster.stats @options
    puts "DEBUG es_ver: #{stats['nodes']['versions']}\nDEBUG stats.nodes.jvm.mem: #{stats['nodes']['jvm']['mem']}" if config[:debug]
    begin
      if return_max
        return stats['nodes']['jvm']['mem']['heap_used_in_bytes'], stats['nodes']['jvm']['mem']['heap_max_in_bytes']
      else
        stats['nodes']['jvm']['mem']['heap_used_in_bytes']
      end
    rescue
      warning 'Failed to obtain heap used in bytes'
    end
  end

  def run
    @options = {}
    @options[:timeout] = "#{config[:timeout]}s"
    if config[:percentage]
      heap_used, heap_max = acquire_heap_data(true)
      heap_used_ratio = ((100 * heap_used) / heap_max).to_i
      message "Heap used in bytes #{heap_used} (#{heap_used_ratio}% full)"
      if heap_used_ratio >= config[:crit]
        critical
      elsif heap_used_ratio >= config[:warn]
        warning
      else
        ok
      end
    else
      heap_used = acquire_heap_data(false)
      message "Heap used in bytes #{heap_used}"
      if heap_used >= config[:crit]
        critical
      elsif heap_used >= config[:warn]
        warning
      else
        ok
      end
    end
  end
end
