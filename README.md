# Service Testing Frameworks

Here lives a framework that can be used to allow for 
the creation of browserplus service unit tests.  Included
in this repository are libraries for high level languages
that drive the "ServiceRunner" binary (distributed in the 
browserplus sdk) and expose a programatic API by which a 
service may be run.

The whole point is to make it possible to craft meaningful
unit tests in a few lines of code.  Here's an example from
the ruby framework:

    #!/usr/bin/env ruby
    
    require File.join(File.dirname(__FILE__), 'bp_service_runner')
    require 'uri'
    require 'test/unit'
    require 'open-uri'
    
    class TestFileAccess < Test::Unit::TestCase
      def setup
        curDir = File.dirname(__FILE__)
        pathToService = File.join(curDir, "..", "src", "build", "FileAccess")
        @s = BrowserPlus::Service.new(pathToService)
    
        @textfile_path = File.expand_path(File.join(curDir, "services.txt"))
        @textfile_uri = (( @textfile_path[0] == "/") ? "file://" : "file:///" ) + @textfile_path
      end
      
      def teardown
        @s.shutdown
      end
    
      def test_read
        # a simple test of the read() function, read a text file 
        want = File.open(@textfile_path, "rb") { |f| f.read }
        got = @s.read({ 'file' => @textfile_uri })
        assert_equal want, got
      end
    end
