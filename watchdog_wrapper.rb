require 'karmap'
# require 'byebug'

Karma.configuration do |config|
  config.user =                   'pulsarplatform'
  config.project_name =           'KWyBdGULPgnv4W9zMHLS8QBE'
  config.karma_project_id =       'fake'
  config.karma_user_id =          'fake'
  config.aws_access_key_id =      'fake'
  config.aws_secret_access_key =  'fake'
  config.services =               []
  config.log_folder =             'log'
end

# byebug

Karma::Watchdog.run
