module Karma
  class Railtie < ::Rails::Railtie
    rake_tasks do
      # https://stackoverflow.com/questions/11474658/what-is-the-path-to-load-a-rake-task-for-a-new-gem
      load 'tasks/watchdog.rake'
    end
  end
end

require 'karmap/railtie' if defined?(Rails)
