module AS
  def self.do_as(str)
    File.open('/tmp/foo.as', 'w') { |f| f.puts(str) }
    result = `osascript /tmp/foo.as`.chomp
    File.unlink('/tmp/foo.as')
    raise "error when executing osascript for '#{str}'" unless $?.success?
    result
  end
end
