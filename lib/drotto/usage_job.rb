require 'steem_api'
require 'golos_cloud'

module DrOtto
  class UsageJob
    include Config
    
    def initialize
      app_key DrOtto.app_key
      agent_id DrOtto.agent_id
    end
    
    def perform(options = {})
      unless ['steem', 'golos'].include? chain_options[:chain]
        warning "Usage data not available for #{chain_options[:chain]}.  Showing STEEM usage instead."
      end
      
      a = options[:account_name] || account_name
      d = (options[:days] || '30').to_i
      publish = options[:publish] || false
      
      transfers = all_transfers.where(to: a)
      transfers = transfers.where('timestamp > ?', d.days.ago)
      
      bids = transfers.where('memo LIKE ?', '%@%') # looking for valid memos
      bids = bids.group(:from)
      bid_sums = bids.sum(:amount)
      bid_counts = bids.count
      
      refunds = all_transfers.where(from: a).where('memo LIKE ?', '%ID:%')
      refunds = refunds.where('timestamp > ?', d.days.ago)
      refunds = refunds.group(:to)
      refund_sums = refunds.sum(:amount)
      refund_counts = refunds.count
      
      total_amounts = 0
      total_bids = 0
      total_refunds = 0
      
      totals = bid_sums.map do |name, amount|
        if refund_sums[name].nil?
          amt = amount
        elsif (amount = amount - refund_sums[name]) > 0
          amt = amount
        else
          # Note, amounts that are zero or less might mean that refunds were
          # sent back for invalid memos.
          next
        end
        
        [name, amt]
      end.compact.sort_by { |v| v.last }.reverse.to_h
      
      totals.each do |name, amount|
        accepted_bids = bid_counts[name].to_i - refund_counts[name].to_i
        refunds = refund_counts[name].to_i
        
        total_amounts += amount
        total_bids += accepted_bids
        total_refunds += refunds
        
        totals[name] = {
          accepted_bids: accepted_bids.to_s,
          refunds: refunds.to_s,
          amount: '%.3f' % amount
        }
      end
      
      has_refunds = totals.values.map do |v|
        v[:refunds].to_f
      end.reduce(0, :+) > 0
      
      max_name_size = (['Name'.size] + totals.map { |v| v.first.size }).max
      max_amount_size = (['Amount'.size] + totals.map { |v| v.last[:amount].size }).max
      max_accepted_bids_size = (['Accepted Bids'.size] + totals.map { |v| v.last[:accepted_bids].size }).max
      
      if has_refunds
        max_refunds_size = (['Refunds'.size] + totals.map { |v| v.last[:refunds].size }).max
      end
      
      print "| #{'Name'.rjust(max_name_size)} "
      print "| #{'Amount'.rjust(max_amount_size)} "
      print "| #{'Accepted Bids'.rjust(max_accepted_bids_size)} "
      
      if has_refunds 
        print "| #{'Refunds'.rjust(max_refunds_size)} "
      end
      
      print "|\n"
      print "|-#{'-' * max_name_size}-"
      print "|-#{'-' * max_amount_size}-"
      print "|-#{'-' * max_accepted_bids_size}-"
      
      if has_refunds
        print "|-#{'-' * max_refunds_size}-"
      end
      
      print "|\n"
      
      totals.each do |name, data|
        print "| #{name.rjust(max_name_size)} "
        print "| #{data[:amount].rjust(max_amount_size)} "
        print "| #{data[:accepted_bids].rjust(max_accepted_bids_size)} "
        
        if has_refunds
          print "| #{data[:refunds].rjust(max_refunds_size)} "
        end
        
        print"|\n"
      end
      
      print "| #{'=' * max_name_size} "
      print "| #{'=' * max_amount_size} "
      print "| #{'=' * max_accepted_bids_size} "
      
      if has_refunds
        print "| #{'=' * max_refunds_size} "
      end
      
      print"|\n"
      
      print "| #{'TOTAL'.rjust(max_name_size)} "
      print "| #{('%.3f' % total_amounts).rjust(max_amount_size)} "
      print "| #{total_bids.to_s.rjust(max_accepted_bids_size)} "
      
      if has_refunds
        print "| #{total_refunds.to_s.rjust(max_refunds_size)} "
      end
      
      print "|\n"
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