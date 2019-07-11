module DrOtto
  module Config
    MAX_BASE_BLOCK_SPAN = 2880
    
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
    
    def agent_id(agent_id = nil)
      @agent_id = agent_id unless agent_id.nil?
      @agent_id || Krang::AGENT_ID
    end
    
    def default_value(key)
      ENV["DROTTO_#{key.to_s.upcase}"]
    end
    
    def block_mode
      default_value(:blockmode) || config[:drotto][:block_mode]
    end
    
    def chain_options
      @default_chain_options ||= {
        logger: logger
      }
      
      chain_options = config[:chain_options].merge(@default_chain_options)
      
      chain = default_value(:chain_options_chain)
      chain_options = chain_options.merge(chain: chain.to_s) if !!chain
      url = default_value(:chain_options_url)
      chain_options = chain_options.merge(url: url) if !!url
      
      chain_options.dup
    end
    
    def steem_engine_chain_options
      default_value(:steem_engine_chain_options) || config[:steem_engine_chain_options]
    end
    
    def logger
      @default_logger ||= Logger.new("drotto.log")
    end
    
    def block_mode
      default_value(:drotto_block_mode) || config[:drotto][:block_mode]
    end
    
    def account_name
      default_value(:drotto_account_name) || config[:drotto][:account_name]
    end
    
    def voter_account_name
      default_value(:drotto_voter_account_name) || config[:drotto][:voter_account_name] || account_name
    end
    
    def voting_power_account_name
      default_value(:drotto_voting_power_account_name) || config[:drotto][:voting_power_account_name] || voter_account_name
    end
    
    def posting_wif
      default_value(:drotto_posting_wif) || config[:drotto][:posting_wif]
    end
    
    def voting_wif
      default_value(:drotto_voting_wif) || config[:drotto][:voting_wif] || posting_wif
    end
    
    def active_wif
      default_value(:drotto_active_wif) || config[:drotto][:active_wif]
    end
    
    def max_age
      (default_value(:drotto_max_age) || config[:drotto][:max_age] || 7200).to_i 
    end
    
    def min_effective_weight
      ((default_value(:drotto_min_effective_weight) || config[:drotto][:min_effective_weight]).to_f * 100).to_i
    end
    
    def max_effective_weight
      ((default_value(:drotto_max_effective_weight) || config[:drotto][:max_effective_weight]).to_f * 100).to_i
    end
    
    def batch_vote_weight
      (default_value(:drotto_batch_vote_weight) || (config[:drotto][:batch_vote_weight]).to_f * 100).to_i
    end
    
    def flag_prefix
      default_value(:flag_prefix) || config[:drotto][:flag_prefix]
    end
    
    def reserve_vote_weight
      ((default_value(:drotto_reserve_vote_weight) || config[:drotto][:reserve_vote_weight]).to_f * 100).to_i
    end
    
    def minimum_bid
      default_value(:drotto_minimum_bid) || config[:drotto][:minimum_bid]
    end
    
    def minimum_bid_amount
      minimum_bid.split(' ').first.to_f
    end
    
    def minimum_bid_asset
      minimum_bid.split(' ').last
    end
    
    def bounce_below_minimum_bid?
      (default_value(:drotto_bounce_below_minimum_bid) || config[:drotto][:bounce_below_minimum_bid]).to_s == 'true'
    end
    
    def alternative_assets
      (default_value(:drotto_alternative_assets) || config[:drotto][:alternative_assets] || '').split(' ')
    end
    
    def allow_comment_bids
      (default_value(:allow_comment_bids) || config[:drotto][:allow_comment_bids]).to_s == 'true'
    end
    
    def ignore_asset
      default_value(:ignore_asset) || config[:drotto][:ignore_asset]
    end
    
    def blacklist
      (default_value(:drotto_blacklist) || config[:drotto][:blacklist]).to_s.downcase.split(' ')
    end
    
    def no_bounce
      (default_value(:drotto_no_bounce) || config[:drotto][:no_bounce]).to_s.downcase.split(' ')
    end
    
    def enable_vote_comment?
      (default_value(:drotto_enable_vote_comment) || config[:drotto][:enable_vote_comment]).to_s == 'true'
    end
    
    def no_vote_comment
      (default_value(:drotto_no_vote_comment) || config[:drotto][:no_vote_comment]).to_s.downcase.split(' ')
    end
    
    def no_vote_comment_fee
      ((default_value(:drotto_no_vote_comment_fee) || config[:drotto][:no_vote_comment_fee]).to_f * 100).to_i
    end
    
    def enable_vote_memo?
      (default_value(:drotto_enable_vote_memo) || config[:drotto][:enable_vote_memo]).to_s == 'true'
    end
    
    def steem_engine_reward
      default_value(:drotto_steem_engine_reward) || config[:drotto][:steem_engine_reward] || {}
    end
    
    def auto_bounce_on_lockout
      (default_value(:drotto_auto_bounce_on_lockout) || config[:drotto][:auto_bounce_on_lockout]).to_s == 'true'
    end
    
    def bounce_memo
      default_value(:bounce_memo) || config[:drotto][:bounce_memo] || 'Unable to accept bid.'
    end
    
    def base_block_span
      [1, (MAX_BASE_BLOCK_SPAN * (batch_vote_weight.abs / 10000.0)).to_i].max
    end
  end
end
