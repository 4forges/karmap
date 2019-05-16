# frozen_string_literal: true

require 'spec_helper'

describe Karma::Engine::Systemd do
  let(:watchdog) { Karma::Watchdog.new }

  before(:each) do
    Karma.reset_engine_instance
    Karma.engine = 'systemd'
  end

  context 'watchdog' do
    # before(:each) { allow_any_instance_of(Karma::Engine::Systemd).to receive(:start_service).and_return(true) }

    it 'exports self' do
      Karma::Watchdog.export

      expect(File.file?("#{Karma.engine_instance.location}/karma-spec-watchdog.target")).to be_truthy
      expect(File.file?("#{Karma.engine_instance.location}/karma-spec-watchdog@.service")).to be_truthy
      expect(File.directory?("#{Karma.engine_instance.location}/karma-spec-watchdog.target.wants")).to be_truthy
      expect(File.symlink?("#{Karma.engine_instance.location}/karma-spec-watchdog.target.wants/karma-spec-watchdog@#{Karma.watchdog_port}.service")).to be_truthy
    end

    it 'discovers and exports service' do
      watchdog.send(:register_services)

      expect(File.file?("#{Karma.engine_instance.location}/karma-spec-test-service.target")).to be_truthy
      expect(File.file?("#{Karma.engine_instance.location}/karma-spec-test-service@.service")).to be_truthy
      expect(File.directory?("#{Karma.engine_instance.location}/karma-spec-test-service.target.wants")).to be_truthy
      expect(File.symlink?("#{Karma.engine_instance.location}/karma-spec-test-service.target.wants/karma-spec-test-service@33000.service")).to be_truthy
    end
  end

  context 'template exports' do
    before(:each) { allow_any_instance_of(Karma::Engine::Systemd).to receive(:work_directory).and_return('/tmp/app') }
    before(:each) { Karma.engine_instance.remove_service(TestService) }
    before(:each) { Karma.engine_instance.remove_service(MockService) }

    it "exports TestService to filesystem" do
      Karma.engine_instance.export_service(TestService)

      expect(File.read("#{Karma.engine_instance.location}/karma-spec.target").strip).to                 eq(example_export_file("systemd/karma-spec.target").strip)
      expect(File.read("#{Karma.engine_instance.location}/karma-spec-test-service.target").strip).to    eq(example_export_file("systemd/karma-spec-test-service.target").strip)
      # expect(File.read("#{Karma.engine_instance.location}/karma-spec-test-service@.service").strip).to  eq(example_export_file("systemd/karma-spec-test-service@.service").strip)

      expect(File.directory?("#{Karma.engine_instance.location}/karma-spec-test-service.target.wants")).to be_truthy
      expect(File.symlink?("#{Karma.engine_instance.location}/karma-spec-test-service.target.wants/karma-spec-test-service@33000.service")).to be_truthy
    end

    it "exports MockService to filesystem" do
      Karma.engine_instance.export_service(MockService)

      expect(File.read("#{Karma.engine_instance.location}/karma-spec.target").strip).to                eq(example_export_file("systemd/karma-spec.target").strip)
      expect(File.read("#{Karma.engine_instance.location}/karma-spec-mock-service.target").strip).to    eq(example_export_file("systemd/karma-spec-mock-service.target").strip)
      # expect(File.read("#{Karma.engine_instance.location}/karma-spec-mock-service@.service").strip).to  eq(example_export_file("systemd/karma-spec-mock-service@.service").strip)

      expect(File.directory?("#{Karma.engine_instance.location}/karma-spec-mock-service.target.wants")).to be_truthy
      expect(File.symlink?("#{Karma.engine_instance.location}/karma-spec-mock-service.target.wants/karma-spec-mock-service@33100.service")).to be_truthy
    end

    it "cleans up if exporting into an existing dir" do
      expect(FileUtils).to receive(:rm).with("#{Karma.engine_instance.location}/karma-spec-test-service@.service").at_least(1).times
      expect(FileUtils).to receive(:rm).with("#{Karma.engine_instance.location}/karma-spec-test-service.target").at_least(1).times

      Karma.engine_instance.export_service(TestService)
      Karma.engine_instance.export_service(TestService)
    end

    it 'create missing instance symlink' do
      Karma.engine_instance.export_service(TestService)

      TestService.max_running(TestService.config_max_running + 1)
      Karma.engine_instance.export_service(TestService)

      instances_dir = "#{TestService.full_name}.target.wants"
      instances = Dir["#{Karma.engine_instance.location}/#{instances_dir}/*"].sort
      expect(instances.size).to eq(TestService.config_max_running)

      # reset
      TestService.max_running(TestService.config_max_running - 1)
      Karma.engine_instance.export_service(TestService)
    end

    it 'delete extra instance symlink' do
      Karma.engine_instance.export_service(TestService)

      TestService.max_running(TestService.config_max_running - 1)
      Karma.engine_instance.export_service(TestService)

      instances_dir = "#{TestService.full_name}.target.wants"
      instances = Dir["#{Karma.engine_instance.location}/#{instances_dir}/*"].sort
      expect(instances.size).to eq(TestService.config_max_running)

      # reset
      TestService.max_running(TestService.config_max_running + 1)
      Karma.engine_instance.export_service(TestService)
    end

    it 'delete single service' do
      Karma.engine_instance.export_service(TestService)
      Karma.engine_instance.export_service(MockService)

      expect(File.file?("#{Karma.engine_instance.location}/karma-spec-test-service.target")).to be_truthy
      expect(File.file?("#{Karma.engine_instance.location}/karma-spec-test-service@.service")).to be_truthy
      expect(File.directory?("#{Karma.engine_instance.location}/karma-spec-test-service.target.wants")).to be_truthy
      expect(File.symlink?("#{Karma.engine_instance.location}/karma-spec-test-service.target.wants/karma-spec-test-service@33000.service")).to be_truthy

      expect(File.file?("#{Karma.engine_instance.location}/karma-spec-mock-service.target")).to be_truthy
      expect(File.file?("#{Karma.engine_instance.location}/karma-spec-mock-service@.service")).to be_truthy
      expect(File.directory?("#{Karma.engine_instance.location}/karma-spec-mock-service.target.wants")).to be_truthy
      expect(File.symlink?("#{Karma.engine_instance.location}/karma-spec-mock-service.target.wants/karma-spec-mock-service@33100.service")).to be_truthy

      Karma.engine_instance.remove_service(MockService)

      expect(File.file?("#{Karma.engine_instance.location}/karma-spec-test-service.target")).to be_truthy
      expect(File.file?("#{Karma.engine_instance.location}/karma-spec-test-service@.service")).to be_truthy
      expect(File.directory?("#{Karma.engine_instance.location}/karma-spec-test-service.target.wants")).to be_truthy
      expect(File.symlink?("#{Karma.engine_instance.location}/karma-spec-test-service.target.wants/karma-spec-test-service@33000.service")).to be_truthy

      expect(File.file?("#{Karma.engine_instance.location}/karma-spec-mock-service.target")).to be_falsey
      expect(File.file?("#{Karma.engine_instance.location}/karma-spec-mock-service@.service")).to be_falsey
      expect(File.directory?("#{Karma.engine_instance.location}/karma-spec-mock-service.target.wants")).to be_falsey
      expect(File.symlink?("#{Karma.engine_instance.location}/karma-spec-mock-service.target.wants/karma-spec-mock-service@33100.service")).to be_falsey
    end
  end

  context 'manage service instances' do
    before(:each) { Karma.engine_instance.export_service(TestService) }
    after(:each) do
      status = Karma.engine_instance.show_all_services
      status.values.each do |s|
        Karma.engine_instance.stop_service(s.pid)
      end
    end
    after(:each) { Karma.engine_instance.remove_service(TestService) }

    it 'check engine instance' do
      expect(Karma.engine_instance.class).to eq(Karma::Engine::Systemd)
    end

    it 'engine starts service instance' do
      Karma.engine_instance.start_service(TestService)
      status = Karma.engine_instance.show_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000.service')
      expect(status.values[0].name).to eq('karma-spec-test-service')
      expect(status.values[0].port).to eq(33000)
      expect(status.values[0].status).to eq('running')
      expect(status.values[0].pid).to be > 1
      expect(TestService.running_instances_count).to eq(1)
    end

    it 'engine stops service instance' do
      Karma.engine_instance.start_service(TestService)
      status = Karma.engine_instance.show_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000.service')
      expect(status.values[0].status).to eq('running')
      expect(TestService.running_instances_count).to eq(1)

      pid = status.values[0].pid

      Karma.engine_instance.stop_service(pid)
      status = Karma.engine_instance.show_service(TestService)
      expect(status.size).to eq(0)
      expect(TestService.running_instances_count).to eq(0)
    end

    it 'engine restarts service instance' do
      Karma.engine_instance.start_service(TestService)
      status = Karma.engine_instance.show_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000.service')
      expect(status.values[0].status).to eq('running')
      expect(TestService.running_instances_count).to eq(1)

      old_pid = status.values[0].pid

      Karma.engine_instance.restart_service(old_pid)
      status = Karma.engine_instance.show_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000.service')
      expect(status.values[0].status).to eq('running')
      expect(TestService.running_instances_count).to eq(1)

      new_pid = status.values[0].pid

      expect(new_pid).to_not eq(old_pid)
    end

    # we are waiting to have more luck!
    it 'engine shows service log' do
      Karma.engine_instance.start_service(TestService)
      log = Karma.engine_instance.show_service_log(TestService)
      expect(log.size).to be > 1
    end
  end
end
