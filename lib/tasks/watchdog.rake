namespace :watchdog do
  desc 'Initialize and start watchdog service after deploy'
  task init: :environment do
    on roles(:app), in: :parallel do
      puts "======================================================================================"
      Karma::Watchdog.export
    end
  end
end
