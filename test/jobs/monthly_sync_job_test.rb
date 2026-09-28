require "test_helper"

class MonthlySyncJobTest < ActiveJob::TestCase
  test "spawns background process for import:monthly_sync" do
    spawn_args = nil
    detach_pid = nil

    Process.define_singleton_method(:spawn) do |*args, **kwargs|
      spawn_args = args
      12345
    end

    Process.define_singleton_method(:detach) do |pid|
      detach_pid = pid
    end

    begin
      MonthlySyncJob.perform_now
    ensure
      class << Process
        remove_method :spawn rescue nil
        remove_method :detach rescue nil
      end
    end

    assert_equal 12345, detach_pid
    assert_includes spawn_args, "import:monthly_sync"
  end
end
