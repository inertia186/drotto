require 'test_helper'

module DrOtto
  class DrOttoTest < DrOtto::Test
    include Config
    
    def setup
      override_config(
        drotto: {
          block_mode: 'irreversible',
          account_name: 'social',
          posting_wif: '5JrvPrQeBBvCRdjv29iDvkwn3EQYZ9jqfAHzrCyUvfbEbRkrYFC',
          active_wif: '5JrvPrQeBBvCRdjv29iDvkwn3EQYZ9jqfAHzrCyUvfbEbRkrYFC',
          batch_vote_weight: '3.13 %',
          minimum_bid: '2.000 SBD'
        }, chain_options: {
          chain: 'steem',
          url: 'https://steemd.steemit.com'
        }
      )
      
      @job = BounceJob.new(200)
    end
    
    def test_report
      assert @job.perform(pretend: true)
    end
    
    def test_stream
      count = 10
      assert_equal count, @job.stream(count)
    end
  end
end