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
      bid = {
        from: 'from',
        author: 'author',
        permlink: 'permlink',
        parent_permlink: 'parent_permlink',
        parent_author: 'parent_author',
        amount: '2.000 SBD',
        timestamp: 'timestamp',
        trx_id: 'id'
      }
      
      bids = [bid, bid, bid]
      
      assert_equal bids, vote(bids)
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
        vote([bid])
      end
    end
    
    def test_voted?
      refute voted?('inertia', 'machintosh-napintosh')
    end
  end
end