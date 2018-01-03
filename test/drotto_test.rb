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
          flag_prefix: '!!!',
          reserve_vote_weight: '0.00 %',
          minimum_bid: '2.000 SBD',
          max_effective_weight: '90.00 %',
          alternative_assets: 'STEEM',
          blacklist: 'mikethemug',
          no_bounce: 'bittrex poloniex openledger',
          no_comment: 'bittrex poloniex openledger',
          no_comment_fee: '0.00 %'
        }, chain_options: {
          chain: 'steem',
          url: 'https://api.steemit.com',
          fallback_urls: ['https://api.steemit.com']
        }
      )
      DrOtto.app_key :drotto
      DrOtto.agent_id AGENT_ID
    end
    
    def test_defaults
      # Since we have added support for Golos, this tests the config to make
      # sure it still picks up the default values if they have not been
      # set.  Delegation allows account_name and voter_account_name to be equal.
      
      assert_equal DrOtto.account_name, DrOtto.voter_account_name, 'expect account_name == voter_account_name'
      assert_equal DrOtto.account_name, DrOtto.voting_power_account_name, 'expect account_name == voting_power_account_name'
      assert_equal DrOtto.posting_wif, DrOtto.voting_wif, 'expect posting_wif == voting_wif'
    end
    
    def test_block_span
      assert DrOtto.block_span
    end
    
    def test_backoff
      assert DrOtto.backoff
    end
    
    def test_find_bids
      VCR.use_cassette('find_bids', record: VCR_RECORD_MODE) do
        assert DrOtto.find_bids(0)
      end
    end
  end
end
