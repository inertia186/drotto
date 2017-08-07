require 'test_helper'

module DrOtto
  class DrOttoTest < DrOtto::Test
    def test_report
      job = BounceJob.new(200)
      assert job.perform(pretend: true)
    end
    
    def test_report_today
      job = BounceJob.new('today')
      
      assert job.perform(pretend: true)
    end
    
    def test_stream
      count = 10
      job = BounceJob.new(200)
      assert_equal count, job.stream(count)
    end
    
    def test_bounce
      job = BounceJob.new(200)
      assert job.bounce('from', 'amount', 'id')
    end
    
    def test_bounced?
      job = BounceJob.new(200)
      refute job.bounced?('id')
    end
    
    def test_force_bounce
      job = BounceJob.new(200)
      assert job.force_bounce!('7e501f74e1bdd8dae9cdd2030b74ffbe5cc83615')
    end
    
    def test_force_bounce_invalid
      job = BounceJob.new(200)
      assert job.force_bounce!('WRONG')
    end
    
    def test_bid_stacking_no_bounce
      # Multiple bids for the same slug should stack into one bid.  There should
      # be no bounce for any of the bids that went into the stack.
    end
    
    # def test_shall_bounce?
    #   Struct.new("Transaction", :trx_id, :op)
    #   
    #   job = BounceJob.new(200)
    #   refute job.shall_bounce?(tx)
    # end
  end
end