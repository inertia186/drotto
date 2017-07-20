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
  
  def find_bids(offset = BLOCK_OVERLAP)
    block_num = head_block
    time = block_time
    starting_block = block_num - block_span(offset)
    bids = []
    
    info "Looking for new bids to #{account_name}; starting at block #{starting_block}; current time: #{time} ..."
    info "Last block in this timeframe is: #{block_num} (#{block_num - starting_block} blocks)."
    
    loop do
      begin
        job = BounceJob.new('today')
        
        api.get_blocks(starting_block..block_num) do |block, number|
          starting_block = number
          
          block.transactions.each_with_index do |tx, index|
            process_bid(block, tx, index, job, bids)
          end
        end
      rescue => e
        warning "Retrying at block: #{starting_block} (#{e})", e
        reset_api
        sleep backoff
        redo
      end
      
      break
    end
    
    if bids.size == 0
      info 'No bids collected.'
    else
      info "Bids collected.  Ready to vote.  Processing bids: #{bids.size}"
      result = vote(bids)
      @threads = result.values
    end
    
    elapsed = (Time.now.utc - time).to_i
    info "Bidding closed for current timeframe at block #{block_num}, took #{elapsed} seconds to run."
    elapsed
  end
  
  def process_bid(block, tx, index, job, bids)
    timestamp = block.timestamp
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
      comment = find_comment(author, permlink)
      next if comment.nil?
      
      next unless can_vote?(comment)
      next if voted?(comment)
      next unless amount =~ / #{minimum_bid_asset}$/
      next if amount.split(' ').first.to_f < minimum_bid_amount
      next if job.bounced?(id)
      
      info "Bid from #{from} for #{amount}."
      
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
  
  def join_threads
    unless @threads.nil?
      loop do
        alive = @threads.map do |thread|
          thread if thread.alive?
        end.compact
        
        if alive.size > 0
          info "Still voting: #{alive.size}"
          sleep Random.rand(3..20) # stagger procssing
        else
          break
        end
      end
    end
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
  
  def bounce_stream
    BounceJob.new.stream
  end
  
  def manual_bounce(trx_id)
    BounceJob.new.manual_bounce!(trx_id)
  end
  
  def run_once
    return if current_voting_power < 100.0
    
    offset = (base_block_span * 0.10).to_i
    elapsed = find_bids(offset)
    join_threads
  end
  
  def run
    loop do
      if current_voting_power < 100.0
        sleep 60
        redo
      end
      
      offset = (base_block_span * 0.10).to_i
      elapsed = find_bids(offset)
      join_threads
    end
  end
  
  def state
    current_voting_power
  end
end
