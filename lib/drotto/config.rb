module DrOtto
  module Config
    MAX_BASE_BLOCK_SPAN = 2880
    
    DEFAULT_LOGGER = Logger.new('drotto.log')
    
    DEFAULT_CHAIN_OPTIONS = {
      logger: DEFAULT_LOGGER
    }
    
    @@override_config = nil
    
    def override_config(override_config)
      @@override_config = override_config
    end
    
    def config
      return @@override_config if !!@@override_config
      
      config_yml = 'config.yml'
      config = if File.exist?(config_yml)
        YAML.load_file(config_yml)
      else
        raise "Create a file: #{config_yml}"
      end
    end
    
    def block_mode
      config[:drotto][:block_mode]
    end
    
    def account_name
      config[:drotto][:account_name]
    end
    
    def posting_wif
      config[:drotto][:posting_wif]
    end
    
    def active_wif
      config[:drotto][:active_wif]
    end
    
    def batch_vote_weight
      (config[:drotto][:batch_vote_weight].to_f * 100).to_i
    end
    
    def reserve_vote_weight
      (config[:drotto][:reserve_vote_weight].to_f * 100).to_i
    end
    
    def minimum_bid
      config[:drotto][:minimum_bid]
    end
    
    def minimum_bid_amount
      minimum_bid.split(' ').first.to_f
    end
    
    def minimum_bid_asset
      minimum_bid.split(' ').last
    end
    
    def chain_options
      config[:chain_options].dup.merge(DEFAULT_CHAIN_OPTIONS)
    end
    
    def base_block_span
      [1, (MAX_BASE_BLOCK_SPAN * (batch_vote_weight / 10000.0)).to_i].max
    end
    
    def logger
      DEFAULT_LOGGER
    end
  end
end