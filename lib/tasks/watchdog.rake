namespace :watchdog do
  desc 'Initialize and start watchdog service after deploy'
  task init:  :environment do
    Karma::Watchdog.export
  end
end
