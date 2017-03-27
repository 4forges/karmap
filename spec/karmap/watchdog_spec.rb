# encoding: UTF-8

require 'spec_helper'

describe Karma::Watchdog do

  let(:watchdog) { Karma::Watchdog.new }

  before(:each) { allow_any_instance_of(Karma::Engine::Systemd).to receive(:start_service).and_return(true) }

  it 'handles process command message' do
    watchdog.send(:register)

    msg = Karma::Messages::ProcessCommandMessage.new(
      service: 'TestService',
      command: 'start'
    )
    expect(watchdog).to receive(:handle_process_command).with(an_instance_of(Karma::Messages::ProcessCommandMessage))
    watchdog.send(:handle_message, msg.to_message)
  end

  it 'handles process config update message' do
    watchdog.send(:register)

    msg = Karma::Messages::ProcessConfigUpdateMessage.new(
      service: 'TestService',
      memory_max: 'foo',
      cpu_quota: 'foo',
      min_running: 'foo',
      max_running: 'foo',
      auto_restart: 'foo',
      auto_start: 'foo',
    )
    expect(watchdog).to receive(:handle_process_config_update).with(an_instance_of(Karma::Messages::ProcessConfigUpdateMessage))
    watchdog.send(:handle_message, msg.to_message)
  end

  it 'handles thread config update message' do
    watchdog.send(:register)

    msg = Karma::Messages::ThreadConfigUpdateMessage.new(
      service: 'TestService',
      log_level: 'foo',
      num_threads: 'foo',
    )
    expect(watchdog).to receive(:handle_thread_config_update).with(an_instance_of(Karma::Messages::ThreadConfigUpdateMessage))
    watchdog.send(:handle_message, msg.to_message)
  end

end
