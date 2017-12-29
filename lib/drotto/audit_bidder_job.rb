require 'steem_api'
require 'golos_cloud'

module DrOtto
  class AuditBidderJob
    include Config
    
    def initialize
      app_key DrOtto.app_key
      agent_id DrOtto.agent_id
    end
    
    def perform(options = {})
      unless ['steem', 'golos'].include? chain_options[:chain]
        warning "Audit data not available for #{chain_options[:chain]}.  Showing STEEM usage instead."
      end
      
      account_name = options[:account_name] || account_name
      bidder = options[:bidder] || '%'
      symbol = options[:symbol] || minimum_bid_asset
      days_ago = (options[:days] || '7').to_f.days.ago.utc
      
      transfers = all_transfers.where(amount_symbol: symbol).
        where('timestamp > ?', days_ago)
      bids = transfers.where(to: account_name).
        where('[TxTransfers].[from] LIKE ?', bidder)
      bounces = transfers.where(from: account_name).
        where('[TxTransfers].[to] LIKE ?', bidder).
        where("memo LIKE '%ID:%'")

      bids_sum = bids.sum(:amount)

      puts "Bids by #{bidder}: #{bids.count} (#{bids_sum} #{symbol} in total)"
      ap bids.group('CAST(timestamp AS DATE)').order('cast_timestamp_as_date').sum(:amount)

      bounces_sum = bounces.sum(:amount)

      puts "Bounces to #{bidder}: #{bounces.count} (#{bounces_sum} #{symbol} in total)"
      ap bounces.group('CAST(timestamp AS DATE)').order('cast_timestamp_as_date').sum(:amount)

      elapsed = (Time.now.utc - days_ago).to_f / 60 / 60 / 24
      net_sum = bids_sum - bounces_sum
      puts "Net: #{net_sum} #{symbol} (#{'%.3f' % (net_sum / elapsed)} #{symbol} per day)"
    end
    
    def all_transfers
      if chain_options[:chain] == 'steem'
        SteemApi::Tx::Transfer
      elsif chain_options[:chain] == 'golos'
        GolosCloud::Tx::Transfer
      end
    end
  end
end
