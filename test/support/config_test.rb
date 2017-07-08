require 'test_helper'

module DrOtto
  class ConfigTest < DrOtto::Test
    include Config
    
    def setup
      override_config(
        drotto: {
          block_mode: 'irreversible',
          account_name: 'social',
          posting_wif: '5JrvPrQeBBvCRdjv29iDvkwn3EQYZ9jqfAHzrCyUvfbEbRkrYFC',
          active_wif: '5JrvPrQeBBvCRdjv29iDvkwn3EQYZ9jqfAHzrCyUvfbEbRkrYFC',
          batch_vote_weight: '3.13 %',
          reserve_vote_weight: '0.01 %',
          minimum_bid: '2.000 SBD'
        }, chain_options: {
          chain: 'steem',
          url: 'https://steemd.steemit.com'
        }
      )
    end

    def test_reserve_vote_weight
      assert_equal 1, reserve_vote_weight
    end
    
    def test_minimum_bid_amount
      assert minimum_bid_amount
    end
    
    def test_minimum_bid_asset
      assert minimum_bid_asset
    end
  end
end
