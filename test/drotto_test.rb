require 'test_helper'

module DrOtto
  class DrOttoTest < DrOtto::Test
    def setup
      DrOtto.override_config(
        drotto: {
          block_mode: 'irreversible',
          account_name: 'bittrex',
          posting_wif: '5JrvPrQeBBvCRdjv29iDvkwn3EQYZ9jqfAHzrCyUvfbEbRkrYFC',
          active_wif: '5JrvPrQeBBvCRdjv29iDvkwn3EQYZ9jqfAHzrCyUvfbEbRkrYFC',
          batch_vote_weight: '3.13 %',
          reserve_vote_weight: '0.00 %',
          minimum_bid: '2.000 SBD',
          blacklist: 'mikethemug',
          no_bounce: 'bittrex poloniex openledger',
          no_comment: 'bittrex poloniex openledger',
          no_comment_fee: '0.00 %'
        }, chain_options: {
          chain: 'steem',
          url: 'https://steemd.steemit.com'
        }
      )
      DrOtto.app_key :drotto
      DrOtto.agent_id AGENT_ID
    end
    
    def test_block_span
      assert DrOtto.block_span
    end
    
    def test_backoff
      assert DrOtto.backoff
    end
    
    def test_backoff
      assert DrOtto.find_bids(0)
    end
  end
end
