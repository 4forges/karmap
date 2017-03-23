require './spec/karmap/models/test_service'

Karma.logger = Logger.new($stdout)
Karma.configuration do |config|
  config.user = 'extendi'
  config.project_name = 'karmat'
  config.karma_project_id = 'DPPQCWCPh6P4nYEQvK7EB39L'
  config.karma_user_id = 'bc74ed7c0ec9aacf3513f3692d09a578'
  config.aws_access_key_id = 'AKIAIU4ZJVPJ6JGQEDQQ'
  config.aws_secret_access_key = '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'
  config.services = [TestService]
  config.log_folder = 'spec/log'
end

TestService.new.run
