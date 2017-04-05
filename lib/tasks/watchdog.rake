namespace :watchdog do
  desc 'Start watchdog service after deploy'
  task start:  :environment do
    #Karma::Watchdog.export
  end
end
