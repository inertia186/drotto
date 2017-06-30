require 'radiator'
require 'awesome_print'
require 'yaml'
# require 'pry'

Bundler.require

module DrOtto
  require 'drotto/version'
  require 'drotto/chain'
  require 'drotto/bounce_job'
  
  include Chain
  
  extend self
  
  BLOCK_OVERLAP = 45 # for overlap between votes
  
  def block_span(offset = BLOCK_OVERLAP)
    base_block_span + offset
  end
  
  def backoff
    2
  end

  def find_bids(offset)
    block_num = head_block
    time = block_time
    starting_block = block_num - block_span(offset)
    bids = []
    
    info "Looking for new bids starting at block #{starting_block} (current time: #{time}) ..."
    
    loop do
      begin
        job = BounceJob.new(10000)
        
        api.get_blocks(starting_block..block_num) do |block, number|
          starting_block = number
          timestamp = block.timestamp
          
          block.transactions.each_with_index do |tx, index|
            id = block['transaction_ids'][index]
              
            tx.operations.each do |type, op|
              next unless type == 'transfer'
              
              from = op.from
              to = op.to
              amount = op.amount
              memo = op.memo
              
              next unless to == account_name
              
              author, permlink = parse_slug(memo) rescue [nil, nil]
              next if author.nil? || permlink.nil?
              next if voted?(author, permlink)
              next unless amount =~ / #{minimum_bid_asset}$/
              next if amount.split(' ').first.to_f < minimum_bid_amount
              next if job.bounced?(id)
              
              info "Bid from #{from} for #{amount}."
              
              comment = comment(author, permlink)
              
              bids << {
                from: from,
                author: author,
                permlink: permlink,
                parent_permlink: comment.parent_permlink,
                parent_author: comment.parent_author,
                amount: amount,
                timestamp: timestamp,
                trx_id: id
              }
            end
          end
        end
      rescue => e
        info "Retrying at block: #{starting_block} (#{e})"
        info e.backtrace
        sleep backoff
        redo
      end
      
      break
    end
    
    if bids.size == 0
      info 'No bids collected.'
    else
      info "Bids collected.  Ready to vote for:"
      vote(bids)
    end
    
    elapsed = (Time.now.utc - time).to_i
    info "Bidding closed for current timeframe, took #{elapsed} seconds to run."
    elapsed
  end
  
  def bounce_once(limit = nil, options = {})
    BounceJob.new(limit).perform(!!options[:pretend])
  end
  
  def bounce(limit = nil)
    loop do
      BounceJob.new(limit).perform
      sleep 3
    end
  end
  
  def run
    elapsed = 0
    loop do
      offset = [elapsed / 3, base_block_span].min
      elapsed = find_bids(offset)
      sleep (base_block_span * 3) - elapsed
    end
  end
end
