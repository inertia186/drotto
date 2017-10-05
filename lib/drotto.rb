require 'krang'
require 'awesome_print'
require 'yaml'
# require 'pry'

Bundler.require

module DrOtto
  require 'drotto/version'
  require 'drotto/chain'
  require 'drotto/bounce_job'
  require 'drotto/usage_job'
  
  include Chain
  
  extend self
  
  app_key :drotto
  agent_id AGENT_ID
  
  BLOCK_OVERLAP = 45 # for overlap between votes
  
  def block_span(offset = BLOCK_OVERLAP)
    base_block_span + offset
  end
  
  def find_bids(offset = BLOCK_OVERLAP)
    block_num = head_block
    time = block_time
    starting_block = block_num - block_span(offset)
    bids = []
    job = BounceJob.new('today', starting_block)
    
    if job.transfer_ids.any?
      info "Looking for new bids to #{account_name}; using account history; current time: #{time} ..."
      info "Total transfers to check: #{job.transfer_ids.size}."
      
      job.transfer_ids.each do |trx_id|
        process_bid(job: job, id: trx_id, bids: bids)
      end
    else
      info "Looking for new bids to #{account_name}; starting at block #{starting_block}; current time: #{time} ..."
      info "Last block in this timeframe is: #{block_num} (#{block_num - starting_block} blocks)."
      
      loop do
        begin
          api.get_blocks(starting_block..block_num) do |block, number|
            starting_block = number
            timestamp = block.timestamp
            block.transactions.each_with_index do |tx, index|
              trx_id = block.transaction_ids[index]
              process_bid(job: job, id: trx_id, tx: tx, timestamp: timestamp, bids: bids)
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
  
  def process_bid(options = {})
    job = options[:job]
    id = options[:id]
    tx = options[:tx] || job.transfer(id)
    timestamp = options[:timestamp]
    bids = options[:bids]
    
    ops = !!tx.op ? [tx.op] : tx.operations
    
    ops.each do |type, op|
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
      next if too_old?(comment)
      next if voted?(comment)
      next unless amount =~ / #{minimum_bid_asset}$/
      next if amount.split(' ').first.to_f < minimum_bid_amount
      next if job.bounced?(id)
      
      if no_comment_fee > 0 && no_comment.include?(from)
        a, asset = amount.split(' ')
        a = a.to_f
        fee = a * (no_comment_fee / 10000.0)
        amount = "#{('%.3f' % (a - fee))} #{asset}"
        info "Bid from #{from} for #{amount} (fee: #{fee} #{asset})."
      else
        info "Bid from #{from} for #{amount}."
      end
      
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
    BounceJob.new.force_bounce!(trx_id)
  end
  
  def run_once
    return if current_voting_power < 100.0
    
    offset = (base_block_span * 2.10).to_i
    elapsed = find_bids(offset)
    join_threads
  end
  
  def run
    loop do
      if current_voting_power < 100.0
        sleep 60
        redo
      end
      
      offset = (base_block_span * 2.10).to_i
      elapsed = find_bids(offset)
      join_threads
    end
  end
  
  def state
    current_voting_power
  end
  
  def usage(options = {})
    UsageJob.new.perform(options)
  end
end
