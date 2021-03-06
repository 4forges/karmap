# frozen_string_literal: true

require 'spec_helper'

describe Karma::Engine::SystemRaw do
  let(:watchdog) { Karma::Watchdog.new }

  before(:each) do
    Karma.reset_engine_instance
    Karma.engine = 'system_raw'
  end
  after(:each) { Karma.engine_instance.remove_service(TestService) }

  context 'manage service instances', wait: { timeout: 500 } do
    let(:status) { Karma.engine_instance.show_service(TestService) }

    def stop_process(pid)
      Karma.engine_instance.stop_service(pid)
    end

    it 'check engine instance' do
      expect(Karma.engine_instance.class).to eq(Karma::Engine::SystemRaw)
    end

    it 'engine starts service instance' do
      pid = Karma.engine_instance.start_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000')
      expect(status.values[0].name).to eq('karma-spec-test-service')
      expect(status.values[0].port).to eq(33000)
      expect(status.values[0].status).to eq('running')
      expect(status.values[0].pid).to be > 1
      stop_process(pid)
    end

    it 'engine stops service instance' do
      Karma.engine_instance.start_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000')
      expect(status.values[0].status).to eq('running')
      pid = status.values[0].pid
      Karma.engine_instance.stop_service(pid)
      status = Karma.engine_instance.show_service(TestService)
      expect(status.size).to eq(0)
    end

    it 'engine restarts service instance' do
      Karma.engine_instance.start_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000')
      expect(status.values[0].status).to eq('running')
      old_pid = status.values[0].pid

      Karma.engine_instance.restart_service(old_pid, service: TestService)
      status = Karma.engine_instance.show_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000')
      expect(status.values[0].status).to eq('running')
      new_pid = status.values[0].pid

      expect(new_pid).to_not eq(old_pid)
      stop_process(status.values[0].pid)
    end
  end
end
