# Periodically set your iChat status to the output of uptime(1). 

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

app = OSA.app('iChat')
previous_status_message = app.status_message
trap('INT') { app.status_message = previous_status_message; exit 0 }
while true
    u = `uptime`
    hours = u.scan(/^\s*(\d+:\d+)\s/).to_s + ' hours'
    days = u.scan(/\d+\sdays/).to_s
    app.status_message = "OSX up #{days} #{hours}"
    sleep 5
end
