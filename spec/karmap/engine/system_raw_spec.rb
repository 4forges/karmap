# encoding: UTF-8

require 'spec_helper'

describe Karma::Engine::SystemRaw do

  before(:all) { Karma.engine = "system_raw" }

  let(:engine) { Karma::Engine::SystemRaw.new }
  let(:service) { TestService.new }
  let(:service2) { MockService.new }
  let(:watchdog) { Karma::Watchdog.new }

  before(:each) { engine.remove_service(service) }
  before(:each) { engine.remove_service(service2) }

  context 'watchdog' do

    before(:each) { allow_any_instance_of(Karma::Engine::SystemRaw).to receive(:start_service).and_return(true) }

    it 'exports self' do
    end

    it 'discovers and exports service' do
    end

  end

  context 'manage service instances' do

    after(:each) do
      status = engine.show_all_services
      status.values.each do |s|
        engine.stop_service(s.pid)
        sleep(1)
      end
    end

    it 'engine starts service instance' do
      engine.start_service(service)
      wait_for {engine.show_service(service)}.to_not be_empty
      status = engine.show_service(service)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000')
      expect(status.values[0].name).to eq('karma-spec-test-service')
      expect(status.values[0].port).to eq(33000)
      puts status.values[0].inspect
      expect(status.values[0].status).to eq('running')
      expect(status.values[0].pid).to be > 1
    end

    it 'engine stops service instance' do
      engine.start_service(service)
      wait_for {engine.show_service(service)}.to_not be_empty
      status = engine.show_service(service)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000')
      expect(status.values[0].status).to eq('running')
      pid = status.values[0].pid

      engine.stop_service(pid)
      wait_for{engine.show_service(service)}.to be_empty
      status = engine.show_service(service)
      expect(status.size).to eq(0)
    end

    it 'engine restarts service instance' do
      engine.start_service(service)
      wait_for {engine.show_service(service)}.to_not be_empty
      status = engine.show_service(service)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000')
      expect(status.values[0].status).to eq('running')
      old_pid = status.values[0].pid

      engine.restart_service(old_pid, { service: service })
      wait_for {engine.show_service(service)}.to_not be_empty
      status = engine.show_service(service)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000')
      expect(status.values[0].status).to eq('running')
      new_pid = status.values[0].pid

      expect(new_pid).to_not eq(old_pid)
    end

  end


end
