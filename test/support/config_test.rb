require 'test_helper'

module DrOtto
  class ConfigTest < DrOtto::Test
    include Config
    
    def test_minimum_bid_amount
      assert minimum_bid_amount
    end
    
    def test_minimum_bid_asset
      assert minimum_bid_asset
    end
  end
end
