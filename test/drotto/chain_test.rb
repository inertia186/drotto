require 'test_helper'

module DrOtto
  class ChainTest < DrOtto::Test
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
    
    def test_reset_api
      assert_nil DrOtto.reset_api
    end
    
    def test_backoff
      assert DrOtto.backoff
    end
    
    def test_reset_properties
      assert_nil DrOtto.reset_properties
    end
    
    def test_properties
      VCR.use_cassette('properties', record: VCR_RECORD_MODE) do
        assert DrOtto.properties
      end
    end
    
    def test_properties_timeout
      VCR.use_cassette('properties_timeout', record: VCR_RECORD_MODE) do
        assert DrOtto.properties
        
        Delorean.jump 31 do
          assert DrOtto.properties
        end
      end
    end
    
    def test_comment
      VCR.use_cassette('comment', record: VCR_RECORD_MODE) do
        refute_nil DrOtto.find_comment('inertia', 'macintosh-napintosh')
      end
    end
    
    def test_comment_bogus
      VCR.use_cassette('comment_bogus', record: VCR_RECORD_MODE) do
        assert_nil DrOtto.find_comment('bogus', 'bogus')
      end
    end
    
    def test_vote
      bid1 = {
        from: 'from',
        author: 'author',
        permlink: 'permlink',
        parent_permlink: 'parent_permlink',
        parent_author: 'parent_author',
        amount: '2.000 SBD',
        timestamp: 'timestamp',
        trx_id: 'id'
      }
      
      bid2 = {
        from: 'from',
        author: 'author',
        permlink: 'permlink',
        parent_permlink: 'parent_permlink',
        parent_author: 'parent_author',
        amount: '0.200 SBD',
        timestamp: 'timestamp',
        trx_id: 'id'
      }
      
      bid3 = {
        from: 'from',
        author: 'author',
        permlink: 'permlink',
        parent_permlink: 'parent_permlink',
        parent_author: 'parent_author',
        amount: '0.020 SBD',
        timestamp: 'timestamp',
        trx_id: 'id'
      }
      
      expected_stacked_bid = {
        from: ['from', 'from', 'from'],
        author: 'author',
        permlink: 'permlink',
        parent_permlink: 'parent_permlink',
        parent_author: 'parent_author',
        amount: ['2.000 SBD', '0.200 SBD', '0.020 SBD'],
        timestamp: 'timestamp',
        trx_id: 'id'
      }
      
      VCR.use_cassette('vote', record: VCR_RECORD_MODE) do
        result = DrOtto.vote([bid1, bid2, bid3])
        bids = result.keys
        result.values.map { |thread| thread.join(1000) }
        assert_equal 1, bids.size
        assert_equal expected_stacked_bid[:from], bids.first[:from]
        assert_equal expected_stacked_bid[:author], bids.first[:author]
        assert_equal expected_stacked_bid[:permlink], bids.first[:permlink]
        assert_equal expected_stacked_bid[:parent_permlink], bids.first[:parent_permlink]
        assert_equal expected_stacked_bid[:amount], bids.first[:amount]
        assert_equal expected_stacked_bid[:timestamp], bids.first[:timestamp]
        assert_equal expected_stacked_bid[:trx_id], bids.first[:trx_id]
      end
    end
    
    def test_vote_invalid
      bid = {
        from: '',
        author: '',
        permlink: '',
        parent_permlink: '',
        parent_author: '',
        amount: '',
        timestamp: '',
        trx_id: ''
      }
      
      assert_raises FloatDomainError do
        VCR.use_cassette('vote_invalid', record: VCR_RECORD_MODE) do
          refute_nil DrOtto.vote([bid])
        end
      end
    end
    
    def test_vote_for_anonymous_bid
      bid = {
        from: 'bittrex',
        author: 'author',
        permlink: 'permlink',
        parent_permlink: 'parent_permlink',
        parent_author: 'parent_author',
        amount: '2.000 SBD',
        timestamp: 'timestamp',
        trx_id: 'id'
      }
      
      VCR.use_cassette('vote_for_anonymous_bid', record: VCR_RECORD_MODE) do
        result = DrOtto.vote([bid])
        bids = result.keys
        result.values.map { |thread| thread.join(1000) }
        assert_equal 1, bids.size
      end
    end
    
    def test_vote_with_base_asset
      bid = {
        from: 'from',
        author: 'author',
        permlink: 'permlink',
        parent_permlink: 'parent_permlink',
        parent_author: 'parent_author',
        amount: '2.000 STEEM',
        timestamp: 'timestamp',
        trx_id: 'id'
      }
      
      VCR.use_cassette('vote_with_base_asset', record: VCR_RECORD_MODE) do
        result = DrOtto.vote([bid])
        bids = result.keys
        result.values.map { |thread| thread.join(1000) }
        assert_equal 1, bids.size, 'expect base asset bid to be accepted at market rate'
        assert_equal 'SBD', bids.last[:amount].last.split(' ').last, 'expect base asset bid to evaluate as debt asset'
      end
    end
    
    
    def test_flag_with_base_asset
      bid = {
        from: 'from',
        author: 'author',
        permlink: 'permlink',
        parent_permlink: 'parent_permlink',
        parent_author: 'parent_author',
        amount: '2.000 STEEM',
        timestamp: 'timestamp',
        invert_vote_weight: true,
        trx_id: 'id'
      }
      
      VCR.use_cassette('flag_with_base_asset', record: VCR_RECORD_MODE) do
        result = DrOtto.vote([bid])
        bids = result.keys
        result.values.map { |thread| thread.join(1000) }
        assert_equal 1, bids.size, 'expect base asset bid to be accepted at market rate'
        assert_equal 'SBD', bids.last[:amount].last.split(' ').last, 'expect base asset bid to evaluate as debt asset'
        assert_equal true, bids.last[:invert_vote_weight].last, 'expect invert_vote_weight flag to be set'
      end
    end
    
    def test_voted?
      VCR.use_cassette('voted', record: VCR_RECORD_MODE) do
        comment = DrOtto.find_comment('inertia', 'macintosh-napintosh')
        refute DrOtto.voted?(comment)
      end
    end
    
    def test_can_vote?
      VCR.use_cassette('can_vote', record: VCR_RECORD_MODE) do
        comment = DrOtto.find_comment('inertia', 'macintosh-napintosh')
        assert DrOtto.can_vote?(comment)
      end
    end
    
    def test_too_old?
      VCR.use_cassette('too_old', record: VCR_RECORD_MODE) do
        comment = DrOtto.find_comment('inertia', 'macintosh-napintosh')
        assert DrOtto.too_old?(comment)
      end
    end
    
    def test_current_voting_power
      VCR.use_cassette('current_voting_power', record: VCR_RECORD_MODE) do
        assert DrOtto.current_voting_power
      end
    end
  end
end