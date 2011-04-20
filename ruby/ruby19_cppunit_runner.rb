# Usage:
#   1. ruby [test_script] --runner=cppunit
## In ruby 1.9, we must use the test-unit v 1.2.3 gem
## In ruby 1.8, the same code is distributed as part of stdlib
require 'optparse'
require 'minitest/unit'
require File.join(File.dirname(File.expand_path(__FILE__)),
                  'ruby19_error.rb')
require File.join(File.dirname(File.expand_path(__FILE__)),
                  'ruby19_failure.rb')
require File.join(File.dirname(File.expand_path(__FILE__)),
                  'ruby19_success.rb')

module MiniTest
  class Unit
    #### GMM: Emit cppunit xml results
    attr_accessor :failure_results, :error_results, :success_results # :nodoc:
    #### END GMM
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

        #### GMM: Emit cppunit xml results
        opts.on '-r', '--runner PATTERN', "Sets test runner." do |a|
          options[:runner] = a
        end
        #### END GMM

        opts.parse args
      end

      options
    end
    ##
    # Top level driver, controls all output and filtering.
    def run args = []
      options = process_args args

      @verbose = options[:verbose]

      filter = options[:filter] || '/./'
      filter = Regexp.new $1 if filter and filter =~ /\/(.*)\//

      seed = options[:seed]
      unless seed then
        srand
        seed = srand % 0xFFFF
      end

      srand seed

      @@out.puts "Loaded suite #{$0.sub(/\.rb$/, '')}\nStarted"

      start = Time.now
      run_test_suites filter

      @@out.puts
      @@out.puts "Finished in #{'%.6f' % (Time.now - start)} seconds."

      @report.each_with_index do |msg, i|
        @@out.puts "\n%3d) %s" % [i + 1, msg]
      end

      @@out.puts

      status

      @@out.puts

      help = ["--seed", seed]
      help.push "--verbose" if @verbose
      help.push("--name", options[:filter].inspect) if options[:filter]

      @@out.puts "Test run options: #{help.join(" ")}"

      #### GMM: Emit cppunit xml results
      if options[:runner] == "cppunit_runner"
        xml_file = File.expand_path($0.sub(/\.rb$/, ''))
        xml_file << ".xml"
        emit_xml(xml_file)
      end
      #### END GMM

      return failures + errors if @test_count > 0 # or return nil...
    rescue Interrupt
      abort 'Interrupted'
    end
    ##
    # Writes status for failed test +meth+ in +klass+ which finished with
    # exception +e+
    def puke klass, meth, e
      e = case e
          when MiniTest::Skip then
            @skips += 1
            "Skipped:\n#{meth}(#{klass}) [#{location e}]:\n#{e.message}\n"
          when MiniTest::Assertion then
            @failures += 1
            #### GMM: Emit cppunit xml results
            add_failure(@test_count + 1, meth, e.class.name, e.message, MiniTest::filter_backtrace(e.backtrace))
            #### END GMM
            "Failure:\n#{meth}(#{klass}) [#{location e}]:\n#{e.message}\n"
          else
            @errors += 1
            #### GMM: Emit cppunit xml results
            add_error(@test_count + 1, meth, e)
            #### END GMM
            bt = MiniTest::filter_backtrace(e.backtrace).join("\n    ")
            "Error:\n#{meth}(#{klass}):\n#{e.class}: #{e.message}\n    #{bt}\n"
          end
      @report << e
      e[0, 1]
    end
    def run_test_suites filter = /./
      @test_count, @assertion_count = 0, 0
      old_sync, @@out.sync = @@out.sync, true if @@out.respond_to? :sync=
      TestCase.test_suites.each do |suite|
        suite.test_methods.grep(filter).each do |test|
          inst = suite.new test
          inst._assertions = 0
          @@out.print "#{suite}##{test}: " if @verbose

          @start_time = Time.now
          result = inst.run(self)
          
          #### GMM: Emit cppunit xml results
          add_success(@test_count + 1, test) if result == '.'
          #### END GMM

          @@out.print "%.2f s: " % (Time.now - @start_time) if @verbose
          @@out.print result
          @@out.puts if @verbose
          @test_count += 1
          @assertion_count += inst._assertions
        end
      end
      @@out.sync = old_sync if @@out.respond_to? :sync=
      [@test_count, @assertion_count]
    end
    #### EVERYTHING AFTER HERE IS GMM ####
    def add_success(testid, name)
      @success_results = Array.new() if @success_results == nil
      @success_results.push(Test::Unit::Success.new(testid, name))
    end
    private :add_success
    def add_failure(testid, name, failuretype, message, all_locations=caller())
      file = ""
      line = ""
      location_value = if(all_locations.size == 1)
        all_locations[0].sub(/\A(.+:\d+).*/, '\\1')
      else
        "#{all_locations.join("\n     ")}"
      end
      location_array = location_value.split(':') 
      file = location_array[0]
      line = location_array[1]
      @failure_results = Array.new() if @failure_results == nil
      @failure_results.push(Test::Unit::Failure.new(testid, name, failuretype, MiniTest::filter_backtrace(all_locations), message, File.expand_path(file), line))
    end
    private :add_failure
    def add_error(testid, name, exception)
      @error_results = Array.new() if @error_results == nil
      @error_results.push(Test::Unit::Error.new(testid, name, exception))
    end
    private :add_error
    def indent(indentLevel)
      s = ""
      i = 0
      while i < indentLevel
        s << "  "
        i += 1
      end
      return s
    end
    def emit_xml(filename)
      file = File.new(filename, "w")
      indentLevel = 0
      file.write("#{indent(indentLevel)}<?xml version=\"1.0\" encoding='ISO-8859-1' standalone='yes' ?>\n")
      file.write("#{indent(indentLevel)}<TestRun>\n")
      #############
      # Go through Failed Tests.
      #############
      indentLevel += 1
      if @failure_results == nil || @failure_results.length == 0
        file.write("#{indent(indentLevel)}<FailedTests></FailedTests>\n")
      else
        file.write("#{indent(indentLevel)}<FailedTests>\n")
        indentLevel += 1
        # Iterate over array.
        @failure_results.each { |result|
          file.write("#{indent(indentLevel)}<FailedTest id=\"#{result.test_id}\">\n")
          indentLevel += 1
          file.write("#{indent(indentLevel)}<Name>#{result.test_name}</Name>\n")
          file.write("#{indent(indentLevel)}<FailureType>#{result.failuretype}</FailureType>\n")
          file.write("#{indent(indentLevel)}<Location>\n")
          indentLevel += 1
          file.write("#{indent(indentLevel)}<File>#{result.file}</File>\n")
          file.write("#{indent(indentLevel)}<Line>#{result.line}</Line>\n")
          indentLevel -= 1
          file.write("#{indent(indentLevel)}</Location>\n")
          file.write("#{indent(indentLevel)}<Message>#{result.message}</Message>\n")
          indentLevel -= 1
          file.write("#{indent(indentLevel)}</FailedTest>\n")
        }
        indentLevel -= 1
        file.write("#{indent(indentLevel)}</FailedTests>\n")
      end
      indentLevel -= 1
      #############
      # Go through Succeeded Tests.
      #############
      indentLevel += 1
      if @success_results == nil || @success_results.length == 0
        file.write("#{indent(indentLevel)}<SuccessfulTests></SuccessfulTests>\n")
      else
        file.write("#{indent(indentLevel)}<SuccessfulTests>\n")
        indentLevel += 1
        # Iterate over array.
        @success_results.each { |result|
          file.write("#{indent(indentLevel)}<Test id=\"#{result.test_id}\">\n")
          indentLevel += 1
          file.write("#{indent(indentLevel)}<Name>#{result.test_name}</Name>\n")
          indentLevel -= 1
          file.write("#{indent(indentLevel)}</Test>\n")
        }
        indentLevel -= 1
        file.write("#{indent(indentLevel)}</SuccessfulTests>\n")
      end
      indentLevel -= 1
      #############
      # Go through Statistics.
      #############
      indentLevel += 1
      file.write("#{indent(indentLevel)}<Statistics>\n")
      indentLevel += 1
      file.write("#{indent(indentLevel)}<Tests>#{@test_count}</Tests>\n")
      file.write("#{indent(indentLevel)}<FailuresTotal>#{@errors + @failures}</FailuresTotal>\n")
      file.write("#{indent(indentLevel)}<Errors>#{@errors}</Errors>\n")
      file.write("#{indent(indentLevel)}<Failures>#{@failures}</Failures>\n")
      indentLevel -= 1
      file.write("#{indent(indentLevel)}</Statistics>\n")
      indentLevel -= 1
      #############
      # Done.
      #############
      file.write("#{indent(indentLevel)}</TestRun>\n")
    end
    #### END GMM ####
  end
end
