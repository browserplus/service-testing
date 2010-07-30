# Usage:
#   1. add require 'cppunit_runner.rb' to your test_script
#   2. ruby [test_script] --runner=cppunit
require 'test/unit'
require 'test/unit/ui/console/testrunner'

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
            file = File.new(filename, "w")
            indentLevel = 0
            file.write("#{indent(indentLevel)}<?xml version=\"1.0\" encoding='ISO-8859-1' standalone='yes' ?>\n")
            file.write("#{indent(indentLevel)}<TestRun>\n")
            #############
            # Go through Failed Tests.
            #############
            indentLevel += 1
            if @failures.length == 0
              file.write("#{indent(indentLevel)}<FailedTests></FailedTests>\n")
            else
              file.write("#{indent(indentLevel)}<FailedTests>\n")
              indentLevel += 1
              # Iterate over array.
              @failures.each_with_index { |result, i|
                file.write("#{indent(indentLevel)}<FailedTest id=\"#{result.testid}\">\n")
                indentLevel += 1
                file.write("#{indent(indentLevel)}<Name>#{result.testname}</Name>\n")
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
            if @successes.length == 0
              file.write("#{indent(indentLevel)}<SuccessfulTests></SuccessfulTests>\n")
            else
              file.write("#{indent(indentLevel)}<SuccessfulTests>\n")
              indentLevel += 1
              # Iterate over array.
              @successes.each_with_index { |result, i|
                file.write("#{indent(indentLevel)}<Test id=\"#{result.testid}\">\n")
                indentLevel += 1
                file.write("#{indent(indentLevel)}<Name>#{result.testname}</Name>\n")
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
            file.write("#{indent(indentLevel)}<Tests>#{@errors.length + @failures.length + @successes.length}</Tests>\n")
            file.write("#{indent(indentLevel)}<FailuresTotal>#{@errors.length + @failures.length}</FailuresTotal>\n")
            file.write("#{indent(indentLevel)}<Errors>#{@errors.length}</Errors>\n")
            file.write("#{indent(indentLevel)}<Failures>#{@failures.length}</Failures>\n")
            indentLevel -= 1
            file.write("#{indent(indentLevel)}</Statistics>\n")
            indentLevel -= 1
            #############
            # Done.
            #############
            file.write("#{indent(indentLevel)}</TestRun>\n")
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
