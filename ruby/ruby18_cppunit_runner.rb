# Usage:
#   1. ruby [test_script] --runner=cppunit
## In ruby 1.9, we must use the test-unit v 1.2.3 gem
## In ruby 1.8, the same code is distributed as part of stdlib
#begin
#  require 'rubygems'
#  gem 'test-unit'
#rescue LoadError
#end
require 'test/unit'
require 'test/unit/ui/console/testrunner'
require 'rexml/document'

module Test
  module Unit
    module UI
      module XML
        class CppUnitTestResult
          attr_accessor :testid, :testname

          def initialize(testname)
            @testid = 0
            test_method = testname.split(/\(.+\)/)[0]
            test_class = testname.slice(testname.index(/\(.+\)/) + 1, testname.length - testname.index(/\(.+\)/) - 2)
            @testname = "#{test_class}::#{test_method}"
          end
        end

        class CppUnitTestError < Test::Unit::UI::XML::CppUnitTestResult
          def initialize(testname)
            super(testname)
          end
        end

        class CppUnitTestFailure < Test::Unit::UI::XML::CppUnitTestResult
          attr_accessor :failuretype, :file, :line, :message

          def initialize(testname, failuretype, file, line, message)
            super(testname)
            @failuretype = failuretype
            @file = file
            @line = line
            @message = message
          end
        end

        class CppUnitTestSuccess < Test::Unit::UI::XML::CppUnitTestResult
          def initialize(testname)
            super(testname)
          end
        end

        class CppUnitTestRun
          attr_accessor :errors, :failures, :successes

          def initialize()
            @errors = Array.new()
            @failures = Array.new()
            @successes = Array.new()
          end

          def indent(indentLevel)
            s = ""
            i = 0
            while i < indentLevel
              s << "  "
              i += 1
            end
            return s
          end

          def add_result(testresult)
            testresult.testid = @errors.length + @failures.length + @successes.length + 1
            if testresult.kind_of? CppUnitTestError
              errors.push(testresult)
            elsif testresult.kind_of? CppUnitTestFailure
              failures.push(testresult)
            elsif testresult.kind_of? CppUnitTestSuccess
              successes.push(testresult)
            elsif testresult.kind_of? CppUnitTestResult
              raise TypeError
            else
              raise ArgumentError
            end
          end

          def emit_xml(filename)
            xmldoc = REXML::Document.new("<?xml version=\"1.0\" encoding='ISO-8859-1' standalone='yes' ?>")
            testrun = xmldoc.add_element("TestRun")
            #############
            # Go through Failed Tests.
            #############
            failedtests = testrun.add_element("FailedTests")
            if @failures != nil && @failures.length > 0
              # Iterate over array.
              @failures.each_with_index { |result, i|
                failedtest = failedtests.add_element("FailedTest")
                failedtest.add_attributes({"id" => result.testid})
                name = failedtest.add_element("Name")
                name.add_text(result.testname)
                failuretype = failedtest.add_element("FailureType")
                failuretype.add_text(result.failuretype)
                location = failedtest.add_element("Location")
                file = location.add_element("File")
                file.add_text(result.file)
                line = location.add_element("Line")
                line.add_text(result.line)
                message = failedtest.add_element("Message")
                message.add_text(result.message)
              }
            end
            #############
            # Go through Succeeded Tests.
            #############
            successfultests = testrun.add_element("SuccessfulTests")
            if @successes != nil && @successes.length > 0
              # Iterate over array.
              @successes.each_with_index { |result, i|
                test = successfultests.add_element("Test")
                test.add_attributes({"id" => result.testid})
                name = successfultests.add_element("Name")
                name.add_text(result.testname)
              }
            end
            #############
            # Go through Statistics.
            #############
            statistics = testrun.add_element("Statistics")
            tests = statistics.add_element("Tests")
            tests.add_text((@errors.length + @failures.length + @successes.length).to_s)
            failurestotal = statistics.add_element("FailuresTotal")
            failurestotal.add_text((@errors.length + @failures.length).to_s)
            errors = statistics.add_element("Errors")
            errors.add_text(@errors.length.to_s)
            failures = statistics.add_element("Failures")
            failures.add_text(@failures.length.to_s)
            #############
            # Done.
            #############
            formatter = REXML::Formatters::Pretty.new()
            out = String.new()
            formatter.write(xmldoc, out)
            file = File.new(filename, "w")
            file.write(out)
          end
        end

        class CppUnitRunner < Test::Unit::UI::Console::TestRunner
          attr_accessor :test_run

          def started(result)
            super(result)
            @test_run = CppUnitTestRun.new()
          end

          def test_started(name)
            super(name)
          end

          def add_fault(fault)
            result = nil
            if fault.kind_of? Test::Unit::Error
              result = CppUnitTestError.new(fault.test_name)
            elsif fault.kind_of? Test::Unit::Failure
              failuretype = ""
              file = ""
              line = ""
              location_value = if(fault.location.size == 1)
                fault.location[0].sub(/\A(.+:\d+).*/, '\\1')
              else
                "\n    [#{fault.location.join("\n     ")}]"
              end
              location_array = location_value.split(':')
              i = 0
              while i < location_array.length
                file << location_array[i] unless i == (location_array.length - 1)
                line << location_array[i] if i == (location_array.length - 1)
                i += 1
              end
              # NEEDSWORK!!!  We can't determine failure reason currently?
              result = CppUnitTestFailure.new(fault.test_name, failuretype, File.expand_path(file), line, fault.message)
            end
            @test_run.add_result(result) if (result != nil)
            super(fault)
          end

          def test_finished(name)
            @test_run.add_result(CppUnitTestSuccess.new(name)) unless (@already_outputted)
            super(name)
          end

          def finished(elapsed_time)
            super(elapsed_time)
            suite_name = @suite.to_s
            if ( @suite.kind_of?(Module) )
              # NEEDSWORK!!!
              # Uh, need to run into this case before we can figure out how to parse the result.
              raise ArgumentException
              #suite_name = @suite.name
            end
            xml_file = File.expand_path(suite_name)
            xml_file << ".xml"
            @test_run.emit_xml(xml_file)
            puts "Output saved to:"
            puts xml_file
          end
        end
      end
    end
  end
end

Test::Unit::AutoRunner::RUNNERS[:cppunit_runner] = proc do |r|
  Test::Unit::UI::XML::CppUnitRunner
end
