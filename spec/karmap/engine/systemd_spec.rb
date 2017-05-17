# encoding: UTF-8

require 'spec_helper'

describe Karma::Engine::Systemd do

  let(:engine) { Karma::Engine::Systemd.new }
  let(:watchdog) { Karma::Watchdog.new }

  before(:each) { Karma.engine = 'systemd' }

  context 'watchdog' do

    before(:each) { allow_any_instance_of(Karma::Engine::Systemd).to receive(:start_service).and_return(true) }

    it 'exports self' do
      Karma::Watchdog.export

      expect(File.file?("#{engine.location}/karma-spec-watchdog.target")).to be_truthy
      expect(File.file?("#{engine.location}/karma-spec-watchdog@.service")).to be_truthy
      expect(File.directory?("#{engine.location}/karma-spec-watchdog.target.wants")).to be_truthy
      expect(File.symlink?("#{engine.location}/karma-spec-watchdog.target.wants/karma-spec-watchdog@#{Karma.watchdog_port}.service")).to be_truthy
    end

    it 'discovers and exports service' do
      watchdog.send(:register)

      expect(File.file?("#{engine.location}/karma-spec-test-service.target")).to be_truthy
      expect(File.file?("#{engine.location}/karma-spec-test-service@.service")).to be_truthy
      expect(File.directory?("#{engine.location}/karma-spec-test-service.target.wants")).to be_truthy
      expect(File.symlink?("#{engine.location}/karma-spec-test-service.target.wants/karma-spec-test-service@33000.service")).to be_truthy
    end

  end

  context 'template exports' do

    before(:each) { allow_any_instance_of(Karma::Engine::Systemd).to receive(:work_directory).and_return('/tmp/app') }
    after(:each) { engine.remove_service(TestService) }
    after(:each) { engine.remove_service(MockService) }

    it "exports TestService to filesystem" do
      engine.export_service(TestService)

      expect(File.read("#{engine.location}/karma-spec.target").strip).to                eq(example_export_file("systemd/karma-spec.target").strip)
      expect(File.read("#{engine.location}/karma-spec-test-service.target").strip).to    eq(example_export_file("systemd/karma-spec-test-service.target").strip)
      expect(File.read("#{engine.location}/karma-spec-test-service@.service").strip).to  eq(example_export_file("systemd/karma-spec-test-service@.service").strip)

      expect(File.directory?("#{engine.location}/karma-spec-test-service.target.wants")).to be_truthy
      expect(File.symlink?("#{engine.location}/karma-spec-test-service.target.wants/karma-spec-test-service@33000.service")).to be_truthy
    end

    it "exports MockService to filesystem" do
      engine.export_service(MockService)

      expect(File.read("#{engine.location}/karma-spec.target").strip).to                eq(example_export_file("systemd/karma-spec.target").strip)
      expect(File.read("#{engine.location}/karma-spec-mock-service.target").strip).to    eq(example_export_file("systemd/karma-spec-mock-service.target").strip)
      expect(File.read("#{engine.location}/karma-spec-mock-service@.service").strip).to  eq(example_export_file("systemd/karma-spec-mock-service@.service").strip)

      expect(File.directory?("#{engine.location}/karma-spec-mock-service.target.wants")).to be_truthy
      expect(File.symlink?("#{engine.location}/karma-spec-mock-service.target.wants/karma-spec-mock-service@33100.service")).to be_truthy
    end

    it "cleans up if exporting into an existing dir" do
      expect(FileUtils).to receive(:rm).with("#{engine.location}/karma-spec-test-service.target.wants/karma-spec-test-service@33000.service").at_least(1).times
      expect(FileUtils).to receive(:rm).with("#{engine.location}/karma-spec-test-service@.service").at_least(1).times
      expect(FileUtils).to receive(:rm).with("#{engine.location}/karma-spec-test-service.target").at_least(1).times

      engine.export_service(TestService)
      engine.export_service(TestService)
    end

    it 'create missing instance symlink' do
      engine.export_service(TestService)

      TestService.max_running(TestService.config_max_running + 1)

      engine.export_service(TestService)
      instances_dir = "#{TestService.full_name}.target.wants"
      instances = Dir["#{engine.location}/#{instances_dir}/*"].sort
      expect(instances.size).to eq(TestService.config_max_running)

      # reset
      TestService.max_running(TestService.config_max_running - 1)
    end

    it 'delete extra instance symlink' do
      engine.export_service(TestService)

      TestService.max_running(TestService.config_max_running - 1)

      engine.export_service(TestService)
      files = Dir["#{engine.location}/karma-spec-test-service.target.wants/*"]
      expect(files.size).to eq(TestService.config_max_running)

      # reset
      TestService.max_running(TestService.config_max_running + 1)
    end

    it 'delete single service' do
      engine.export_service(TestService)
      engine.export_service(MockService)

      expect(File.file?("#{engine.location}/karma-spec-test-service.target")).to be_truthy
      expect(File.file?("#{engine.location}/karma-spec-test-service@.service")).to be_truthy
      expect(File.directory?("#{engine.location}/karma-spec-test-service.target.wants")).to be_truthy
      expect(File.symlink?("#{engine.location}/karma-spec-test-service.target.wants/karma-spec-test-service@33000.service")).to be_truthy

      expect(File.file?("#{engine.location}/karma-spec-mock-service.target")).to be_truthy
      expect(File.file?("#{engine.location}/karma-spec-mock-service@.service")).to be_truthy
      expect(File.directory?("#{engine.location}/karma-spec-mock-service.target.wants")).to be_truthy
      expect(File.symlink?("#{engine.location}/karma-spec-mock-service.target.wants/karma-spec-mock-service@33100.service")).to be_truthy

      engine.remove_service(MockService)

      expect(File.file?("#{engine.location}/karma-spec-test-service.target")).to be_truthy
      expect(File.file?("#{engine.location}/karma-spec-test-service@.service")).to be_truthy
      expect(File.directory?("#{engine.location}/karma-spec-test-service.target.wants")).to be_truthy
      expect(File.symlink?("#{engine.location}/karma-spec-test-service.target.wants/karma-spec-test-service@33000.service")).to be_truthy

      expect(File.file?("#{engine.location}/karma-spec-mock-service.target")).to be_falsey
      expect(File.file?("#{engine.location}/karma-spec-mock-service@.service")).to be_falsey
      expect(File.directory?("#{engine.location}/karma-spec-mock-service.target.wants")).to be_falsey
      expect(File.symlink?("#{engine.location}/karma-spec-mock-service.target.wants/karma-spec-mock-service@33100.service")).to be_falsey
    end

  end

  context 'manage service instances' do

    before(:each) { engine.export_service(TestService) }
    after(:each) do
      status = engine.show_all_services
      status.values.each do |s|
        engine.stop_service(s.pid)
        sleep(2)
      end
    end
    after(:each) { engine.remove_service(TestService) }

    it 'engine starts service instance' do
      engine.start_service(TestService)
      wait_for {engine.show_service(TestService)}.to_not be_empty
      status = engine.show_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000.service')
      expect(status.values[0].name).to eq('karma-spec-test-service')
      expect(status.values[0].port).to eq(33000)
      expect(status.values[0].status).to eq('running')
      expect(status.values[0].pid).to be > 1
    end

    it 'engine stops service instance' do
      engine.start_service(TestService)
      wait_for {engine.show_service(TestService)}.to_not be_empty
      status = engine.show_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000.service')
      expect(status.values[0].status).to eq('running')
      pid = status.values[0].pid

      engine.stop_service(pid)
      wait_for{engine.show_service(TestService)}.to be_empty
      status = engine.show_service(TestService)
      expect(status.size).to eq(0)
    end

    it 'engine restarts service instance' do
      engine.start_service(TestService)
      wait_for {engine.show_service(TestService)}.to_not be_empty
      status = engine.show_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000.service')
      expect(status.values[0].status).to eq('running')
      old_pid = status.values[0].pid

      engine.restart_service(old_pid)
      wait_for {engine.show_service(TestService)}.to_not be_empty
      status = engine.show_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000.service')
      expect(status.values[0].status).to eq('running')
      new_pid = status.values[0].pid

      expect(new_pid).to_not eq(old_pid)
    end

    it 'engine shows service log' do
      engine.start_service(TestService)
      wait_for {engine.show_service(TestService)}.to_not be_empty
      log = engine.show_service_log(TestService)
      expect(log.size).to be > 1
    end

  end


end
