require 'test_helper'

module DrOtto
  class DrOttoTest < DrOtto::Test
    def test_report
      vcr_cassette('report') do
        job = BounceJob.new(200)
        assert job.perform(pretend: true)
      end
    end
    
    def test_report_today
      vcr_cassette('report_today') do
        job = BounceJob.new('report_today')
        assert job.perform(pretend: true)
      end
    end
    
    def test_stream
      count = 10
      
      vcr_cassette('stream') do
        job = BounceJob.new(200)
        assert_equal count, job.stream(count)
      end
    end
    
    def test_bounce
      vcr_cassette('bounce') do
        job = BounceJob.new(200)
        assert job.bounce('from', 'amount', 'id')
      end
    end
    
    def test_bounced?
      vcr_cassette('bounced') do
        job = BounceJob.new(200)
        refute job.bounced?('id')
      end
    end
    
    def test_force_bounce
      vcr_cassette('force_bounce') do
        job = BounceJob.new(200)
        assert job.force_bounce!('7e501f74e1bdd8dae9cdd2030b74ffbe5cc83615')
      end
    end
    
    def test_force_bounce_invalid
      vcr_cassette('bounce_invalid') do
        job = BounceJob.new(200)
        assert job.force_bounce!('WRONG')
      end
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
