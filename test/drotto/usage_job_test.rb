require 'test_helper'

module DrOtto
  class UsageJobTest < DrOtto::Test
    def test_perform
      refute UsageJob.new.perform
    end
  end
end
