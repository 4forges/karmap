namespace :watchdog do

  task :init do
    on roles(:app), in: :parallel do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, 'exec bin/rails runner Karma::Watchdog.export'
        end
      end
    end
  end

  task :start_all do
    on roles(:app), in: :parallel do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, 'exec bin/rails runner Karma::Watchdog.start_all_services'
        end
      end
    end
  end

  task :stop_all do
    on roles(:app), in: :parallel do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, 'exec bin/rails runner Karma::Watchdog.stop_all_services'
        end
      end
    end
  end

end
