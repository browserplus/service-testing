# A little ruby library which can allow client code to programattically drive service runner.
# Great for unit tests!

# if we're talkin' ruby 1.9, we'll use built in json, otherwise use
# the pure ruby library sittin' here
$:.push(File.dirname(__FILE__))
begin
  require 'json'
rescue LoadError
  require "json/json.rb"
end
begin
  require 'ruby18_cppunit_runner.rb'
rescue NameError
  require 'ruby19_cppunit_runner.rb'
end
require 'bp_assert.rb'

module BrowserPlus
  module ProcessController
    def getmsg(pio, timeo, lookFor = false)
      j = nil
      @outputbuffer = String.new if (@outputbuffer == nil)
      while true
        begin
          # now peel off the first json map, taking advantage of the fact that
          # ServiceRunner inserts newlines
          lines = @outputbuffer.split "\n"
          lines.shift while lines.length && lines[0].strip == ""
          if lines != nil && lines.length
            # regex pulls off that \n, so add it back!
            msg = lines.shift
            @outputbuffer = (lines.length ? lines.join("\n") : "")
            j = JSON.parse(msg)
            return j
          end
        rescue
        end
        break if (nil == select( [ pio ], nil, nil, timeo ))  
        buf = ""
        while true
          buf += pio.sysread(1024) 
          # keep reading until we get a buffer who's last char is a newline.
          # this guarantees we're not in a partially read state
          break if buf[buf.length - 1].ord == 10
        end
        @outputbuffer += buf          
      end
      nil
    end
  end

  class Service
    def initialize path, downloadPath = nil, distroServer = nil, providerPath = nil, logfile = nil, debugService = false, allocateUri = nil
      @allocateUri = allocateUri
      sr = findServiceRunner
      raise "can't execute ServiceRunner: #{sr}" if !File.executable? sr
      debugopts = ""
      if debugService == true
        debugopts = "-debugService"
      end
      logopts = ""
      if logfile != nil
        logopts = "-log debug -logfile \"#{logfile}\""
      end
      cmd = ""
      if downloadPath != nil
        if distroServer != nil
          cmd = "#{sr} #{debugopts} #{logopts} -slave -downloadPath \"#{downloadPath}\" -distroServer \"${distroServer}\"\" #{path}\""
        else
          cmd = "#{sr} #{debugopts} #{logopts} -slave -downloadPath \"#{downloadPath}\" \"#{path}\""
        end
      else
        if providerPath != nil
          cmd = "#{sr} #{debugopts} #{logopts} -slave -providerPath \"#{providerPath}\" \"#{path}\""
        else
          cmd = "#{sr} #{debugopts} #{logopts} -slave \"#{path}\""
        end
      end
      @srp = IO.popen(cmd, "w+")
      msgok = true
      x = 0
      while true
        i = getmsg(@srp, 2.0)
        raise i['msg'] if i && i['type'] == 'error' && i['msg']
        raise "couldn't initialize" if i && (i['msg'] !~ /service initialized/ && i['msg'] !~ /Downloading service/ && i['msg'] != "." && i['msg'] !~ /Installing service/)
        @instance = nil
        break if i && i['msg'] =~ /service initialized/
        # This is a catch-all timeout.  Might need some adjustment for real-world.
        x = x + 1
        raise "couldn't initialize" if x > 240
      end
    end

    # allocate a new instance
    def allocate
      uri = @allocateUri
      uri = "" if uri == nil
      @srp.syswrite "allocate #{uri}\n"
      i = getmsg(@srp, 2.0)
      raise "couldn't allocate" if !i.has_key?('msg')
      num = i['msg']
      Instance.new(@srp, num)
    end

    # invoke a function on an automatically allocated instance of the service
    def invoke f, a, &cb
      @instance = allocate() if @instance == nil
      @instance.invoke f, a, &cb
    end

    def method_missing func, *args, &b
      invoke func, args[0], &b
    end

    def shutdown
      if @instance != nil
        @instance.destroy
        @instance = nil
      end
      @srp.close
      @srp = nil 
    end

    private


    # attempt to find the ServiceRunner binary, a part of the BrowserPlus
    # SDK. (http://browserplus.yahoo.com)
    def findServiceRunner
      candidates = []

      # first use SERVICERUNNER_PATH if present
      if ENV.has_key? 'SERVICERUNNER_PATH'
        candidates.push(ENV['SERVICERUNNER_PATH'])
      end

      # next use BPSDK_PATH env var if present
      if ENV.has_key? 'BPSDK_PATH'
        candidates.push File.join(ENV['BPSDK_PATH'], "bin", "ServiceRunner.exe")
        candidates.push File.join(ENV['BPSDK_PATH'], "bin", "ServiceRunner")
      end
      
      # finally, try relative to this repo 
      srBase = File.join(File.dirname(__FILE__), "..", "..", "bin")
      candidates.push File.join(srBase, "ServiceRunner.exe")
      candidates.push File.join(srBase, "ServiceRunner")

      candidates.each { |p|
        return p if File.executable? p
      }
      nil
    end

    include ProcessController
  end
  
  class Instance
    # private!!
    def initialize p, n
      @iid = n
      @srp = p
    end

    def invoke func, args, &cb
      args = Hash.new if args == nil
      args = JSON.generate(args).gsub("'", "\\'")
      cmd = "inv #{func.to_s}"
      cmd += " '#{args}'" if args != "null"
      cmd += "\n"
      # always select the current instance
      @srp.syswrite "select #{@iid}\n"
      @srp.syswrite cmd
      while i = getmsg(@srp, 4.0)
        # skip info messages
        next if i['type'] == "info"
        # invoke passed in block for callbacks?
        if i['type'] == "callback"        
          cb.call(i['msg']) if cb != nil
          i = nil
          next
        end
        break
      end
      raise i['msg'] if i && i['type'] == 'error' && i['msg']
      raise "invocation failure" if i == nil || i['type'] != 'results'
      i['msg']
    end

    def destroy
      @srp.syswrite "destroy #{@iid}\n"
    end

    def method_missing func, *args, &cb
      invoke func, args[0], &cb
    end
    private
    include ProcessController
  end

  def BrowserPlus.run path, downloadPath = nil, distroServer = nil, logfile = nil, debugService = false, allocateUri = nil, &block
    s = BrowserPlus::Service.new(path, downloadPath, distroServer, nil, logfile, debugService, allocateUri)
    block.call(s)
    s.shutdown
  end

  def BrowserPlus.runProvider path, providerPath, logfile = nil, debugService = false, allocateUri = nil, &block
    s = BrowserPlus::Service.new(path, nil, nil, providerPath, logfile, debugService, allocateUri)
    block.call(s)
    s.shutdown
  end
end
