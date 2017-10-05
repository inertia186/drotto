require 'test_helper'

module DrOtto
  class ChainTest < DrOtto::Test
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
      assert DrOtto.properties
    end
    
    def test_properties_timeout
      assert DrOtto.properties
      
      Delorean.jump 31 do
        assert DrOtto.properties
      end
    end
    
    def test_comment
      refute_nil DrOtto.find_comment('inertia', 'macintosh-napintosh')
    end
    
    def test_comment_bogus
      assert_nil DrOtto.find_comment('bogus', 'bogus')
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
        refute_nil DrOtto.vote([bid])
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
      
      result = DrOtto.vote([bid])
      bids = result.keys
      result.values.map { |thread| thread.join(1000) }
      assert_equal 1, bids.size
    end
    
    def test_voted?
      comment = DrOtto.find_comment('inertia', 'macintosh-napintosh')
      refute DrOtto.voted?(comment)
    end
    
    def test_can_vote?
      comment = DrOtto.find_comment('inertia', 'macintosh-napintosh')
      assert DrOtto.can_vote?(comment)
    end
    
    def test_too_old?
      comment = DrOtto.find_comment('inertia', 'macintosh-napintosh')
      assert DrOtto.too_old?(comment)
    end
    
    def test_current_voting_power
      assert DrOtto.current_voting_power
    end
  end
end