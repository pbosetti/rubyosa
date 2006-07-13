# Periodically set your iChat status to the output of uptime(1). 

require 'rbosa'

app = OSA.app_with_name('iChat')
previous_status_message = app.status_message
trap('INT') { app.status_message = previous_status_message; exit 0 }
while true 
    app.status_message = `uptime`.strip 
    sleep 5
end
