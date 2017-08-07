require 'test_helper'

module DrOtto
  class ConfigTest < DrOtto::Test
    def test_reserve_vote_weight
      DrOtto.semaphore do
        original_config = DrOtto.override_config
        DrOtto.override_config(drotto: { reserve_vote_weight: '0.01 %' })
        
        assert_equal 1, DrOtto.reserve_vote_weight
        
        DrOtto.override_config = original_config
      end
    end
    
    def test_minimum_bid_amount
      assert DrOtto.minimum_bid_amount
    end
    
    def test_minimum_bid_asset
      assert DrOtto.minimum_bid_asset
    end
    
    def test_no_bounce
      assert DrOtto.no_bounce
    end
    
    def test_no_comment_fee
      DrOtto.semaphore do
        original_config = DrOtto.override_config
        DrOtto.override_config.merge(drotto: { no_comment_fee: '1.00 %' })
        
        assert_equal 100, DrOtto.no_comment_fee
        
        DrOtto.override_config = original_config
      end
    end
  end
end
