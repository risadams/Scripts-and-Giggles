#!/usr/bin/env ruby

## Emit a desktop notification with the given title and description.
## If no notification system is available, print an error message and exit
## Example: 
##  run_some_long_running_process ; notify 'all done'

require 'date'
require 'json'

def exec(*args)
  begin
    pid = spawn(*args)
  rescue Errno::ENOENT
    return false
  end
  return Process.wait2(pid)[1].exited?
end

def notify(title, description)
  return if exec('notify-send', '--expire-time=5000', title, description)

  js = "
  var app = Application.currentApplication()
  app.includeStandardAdditions = true
  app.displayNotification(#{JSON.generate(description)}, {
    withTitle: #{JSON.generate(title)},
  })
  "
  return if exec('osascript', '-l', 'JavaScript', '-e', js)

  $stderr.puts("can't send notifications")
  exit(1)
end

title = ARGV[0] || "Notification"
description = ARGV[1] || DateTime.now.iso8601

notify(title, description)