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
      ENV['DROTTO_BLOCK_MODE'] || config[:drotto][:block_mode]
    end
    
    def account_name
      ENV['DROTTO_ACCOUNT_NAME'] || config[:drotto][:account_name]
    end
    
    def posting_wif
      ENV['DROTTO_POSTING_WIF'] || config[:drotto][:posting_wif]
    end
    
    def active_wif
      ENV['DROTTO_ACTIVE_WIF'] || config[:drotto][:active_wif]
    end
    
    def min_effective_weight
      ((ENV['DROTTO_MIN_EFFECTIVE_WEIGHT'] || config[:drotto][:min_effective_weight]).to_f * 100).to_i
    end
    
    def batch_vote_weight
      (ENV['DROTTO_BATCH_VOTE_WEIGHT'] || (config[:drotto][:batch_vote_weight]).to_f * 100).to_i
    end
    
    def reserve_vote_weight
      ((ENV['DROTTO_RESERVE_VOTE_WEIGHT'] || config[:drotto][:reserve_vote_weight]).to_f * 100).to_i
    end
    
    def minimum_bid
      ENV['DROTTO_MINIMUM_BID'] || config[:drotto][:minimum_bid]
    end
    
    def minimum_bid_amount
      minimum_bid.split(' ').first.to_f
    end
    
    def minimum_bid_asset
      minimum_bid.split(' ').last
    end
    
    def blacklist
      (ENV['DROTTO_BLACKLIST'] || config[:drotto][:blacklist]).to_s.downcase.split(' ')
    end
    
    def chain_options
      chain_options = config[:chain_options].merge(DEFAULT_CHAIN_OPTIONS)
      
      chain = ENV['DROTTO_CHAIN_OPTIONS_CHAIN']
      chain_options = chain_options.merge(chain: chain.to_s) if !!chain
      url = ENV['DROTTO_CHAIN_OPTIONS_URL']
      chain_options = chain_options.merge(url: url) if !!url
      
      chain_options.dup
    end
    
    def base_block_span
      [1, (MAX_BASE_BLOCK_SPAN * (batch_vote_weight / 10000.0)).to_i].max
    end
    
    def logger
      DEFAULT_LOGGER
    end
  end
end
