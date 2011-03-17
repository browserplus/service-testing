# Usage:
#   1. ruby [test_script] --runner=cppunit
## In ruby 1.9, we must use the test-unit v 1.2.3 gem
## In ruby 1.8, the same code is distributed as part of stdlib
require 'optparse'
require 'minitest/unit'

module MiniTest
  class Unit
    def process_args args = []
      options = {}

      OptionParser.new do |opts|
        opts.banner  = 'minitest options:'
        opts.version = MiniTest::Unit::VERSION

        opts.on '-h', '--help', 'Display this help.' do
          puts opts
          exit
        end

        opts.on '-s', '--seed SEED', Integer, "Sets random seed" do |m|
          options[:seed] = m.to_i
        end

        opts.on '-v', '--verbose', "Verbose. Show progress processing files." do
          options[:verbose] = true
        end

        opts.on '-n', '--name PATTERN', "Filter test names on pattern." do |a|
          options[:filter] = a
        end

        opts.on '-r', '--runner PATTERN', "Sets test runner." do |a|
          options[:runner] = a
        end

        opts.parse args
      end

      options
    end
  end
end
