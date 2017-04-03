namespace :watchdog do

  desc 'Start watchdog service'
  task start: :environment do
    Karma::Watchdog.export
  end

  desc 'Start watchdog service after deploy'
  task :deploy do
    if defined?(Rails)
      Rake::Task[:environment].invoke
    end
  end

end
