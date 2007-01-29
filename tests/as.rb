require 'osx/foundation'
module AS
  def self.do_as(str)
    as = OSX::NSAppleScript.alloc.initWithSource(str)
    ok = as.compileAndReturnError(nil)
    raise "error when compiling '#{str}'" unless ok
    desc = as.executeAndReturnError(nil)
    raise "error when executing '#{str}'" unless desc
    desc.stringValue.to_s
  end
end
