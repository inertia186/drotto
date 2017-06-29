require 'test_helper'

module DrOtto
  class DrOttoTest < DrOtto::Test
    include Utils
    
    def setup
      override_config(
        drotto: {
          block_mode: 'irreversible',
          account_name: 'bittrex',
          posting_wif: '5JrvPrQeBBvCRdjv29iDvkwn3EQYZ9jqfAHzrCyUvfbEbRkrYFC',
          active_wif: '5JrvPrQeBBvCRdjv29iDvkwn3EQYZ9jqfAHzrCyUvfbEbRkrYFC',
          batch_vote_weight: '3.13 %',
          minimum_bid: '2.000 SBD'
        }, chain_options: {
          chain: 'steem',
          url: 'https://steemd.steemit.com'
        }
      )
    end
    
    def test_block_span
      assert DrOtto.block_span
    end
    
    def test_backoff
      assert DrOtto.backoff
    end
    
    def test_backoff
      assert DrOtto.find_bids
    end
  end
end
