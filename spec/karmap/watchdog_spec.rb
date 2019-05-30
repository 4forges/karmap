# frozen_string_literal: true

require 'spec_helper'

describe Karma::Watchdog do
  let(:watchdog) { Karma::Watchdog.new }

  before(:each) do
    Karma.reset_engine_instance
    Karma.engine = 'systemd'
  end
  # before(:each) { allow_any_instance_of(Karma::Engine::Systemd).to receive(:start_service).and_return(true) }

  it 'services to register_services' do
    expect(Karma.service_classes).to eq([TestService, MockService])
  end

  it 'handles process command message' do
    watchdog.send(:register_services)

    msg = Karma::Messages::ProcessCommandMessage.new(
      service: 'TestService',
      command: 'start'
    )
    expect(watchdog).to receive(:handle_process_command).with(an_instance_of(Karma::Messages::ProcessCommandMessage))
    watchdog.send(:handle_message, msg.to_message)
  end

  it 'handles process config update message' do
    watchdog.send(:register_services)

    msg = Karma::Messages::ProcessConfigUpdateMessage.new(
      service: 'TestService',
      memory_max: 'foo',
      cpu_quota: 'foo',
      min_running: 'foo',
      max_running: 'foo',
      auto_restart: 'foo',
      auto_start: 'foo',
      sleep_time: 'foo',
      log_level: 'foo',
      num_threads: 'foo'
    )
    expect(watchdog).to receive(:handle_process_config_update).with(an_instance_of(Karma::Messages::ProcessConfigUpdateMessage))
    watchdog.send(:handle_message, msg.to_message)
  end
end
