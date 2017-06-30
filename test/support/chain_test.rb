require 'test_helper'

module DrOtto
  class ChainTest < DrOtto::Test
    include Chain
    
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
    end
    
    def test_comment
      assert comment('inertia', 'machintosh-napintosh')
      
      # c.cov: memoization
      assert comment('inertia', 'machintosh-napintosh')
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
      
      bids = vote([bid1, bid2, bid3])
      assert_equal 1, bids.size
      assert_equal expected_stacked_bid[:from], bids.first[:from]
      assert_equal expected_stacked_bid[:author], bids.first[:author]
      assert_equal expected_stacked_bid[:permlink], bids.first[:permlink]
      assert_equal expected_stacked_bid[:parent_permlink], bids.first[:parent_permlink]
      assert_equal expected_stacked_bid[:amount], bids.first[:amount]
      assert_equal expected_stacked_bid[:timestamp], bids.first[:timestamp]
      assert_equal expected_stacked_bid[:trx_id], bids.first[:trx_id]
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
      
      refute_nil vote([bid])
    end
    
    def test_voted?
      refute voted?('inertia', 'macintosh-napintosh')
    end
    
    def test_can_vote?
      refute can_vote?('inertia', 'macintosh-napintosh')
    end
  end
end