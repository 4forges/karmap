namespace :watchdog do
  desc 'Start watchdog service after deploy'
  task :start do
    Karma::Watchdog.export
  end
end