require 'radiator'
require 'awesome_print'
require 'yaml'
require 'lru_redux'
# require 'pry'

Bundler.require

defined? Thread.report_on_exception and Thread.report_on_exception = true

module DrOtto
  require 'drotto/version'
  require 'drotto/chain'
  require 'drotto/bounce_job'
  require 'drotto/usage_job'
  require 'drotto/audit_bidder_job'
  
  include Chain
  
  extend self
  
  BLOCK_OVERLAP = 45 # for overlap between votes
  
  ERROR_LEVEL_VOTING_POWER_FAILED_SANITY_CHECK = 1
  ERROR_LEVEL_VOTING_POWER_OK = 0
  ERROR_LEVEL_VOTING_POWER_HUNG = -1
  ERROR_LEVEL_VOTING_POWER_FATAL = -2
  
  STEEM_ENGINE_OP_ID = 'ssc-mainnet1'
    
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
      drotto_info "Looking for new bids to #{account_name}; using account history; current time: #{time} ..."
      drotto_info "Total transfers to check: #{job.transfer_ids.size}."
      
      job.transfer_ids.each do |trx_id|
        process_bid(job: job, id: trx_id, bids: bids)
      end
    else
      drotto_info "Looking for new bids to #{account_name}; starting at block #{starting_block}; current time: #{time} ..."
      drotto_info "Last block in this timeframe is: #{block_num} (#{block_num - starting_block} blocks)."
      
      loop do
        begin
          api.get_blocks(starting_block..block_num) do |block, number|
            unless defined? block.transaction_ids
              # Happens on Golos, see: https://github.com/GolosChain/golos/issues/281
              drotto_error "Blockchain does not provide transaction ids in blocks, giving up."
              return -1
            end
              
            starting_block = number
            timestamp = block.timestamp
            block.transactions.each_with_index do |tx, index|
              trx_id = block.transaction_ids[index]
              process_bid(job: job, id: trx_id, tx: tx, timestamp: timestamp, bids: bids)
            end
          end
        rescue => e
          drotto_warning "Retrying at block: #{starting_block} (#{e})", e
          reset_api
          sleep backoff
          redo
        end
        
        break
      end
    end
    
    result = if bids.size == 0
      drotto_info 'No bids collected.'
      {}
    else
      drotto_info "Bids collected.  Ready to vote.  Processing bids: #{bids.size}"
      vote(bids)
    end
    
    elapsed = (Time.now.utc - time).to_i
    drotto_info "Bidding closed for current timeframe at block #{block_num}, took #{elapsed} seconds to run."
    result.merge(elapsed: elapsed)
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
      memo = op.memo.strip
      
      next unless to == account_name
      
      author, permlink = parse_slug(memo) rescue [nil, nil]
      next if author.nil? || permlink.nil?
      permlink = normalize_permlink permlink
      next if vote_cache_hit?(author, permlink)
      next if bounce_cache_hit?(id)
      comment = find_comment(author, permlink)
      next if comment.nil?
      
      next unless can_vote?(comment)
      next if too_old?(comment)
      next if voted?(comment)
      next unless accepted_asset?(amount)
      next if amount.split(' ').first.to_f < minimum_bid_amount
      next if job.bounced?(id)
      
      if no_vote_comment_fee > 0 && no_vote_comment.include?(from)
        a, asset = amount.split(' ')
        a = a.to_f
        fee = a * (no_vote_comment_fee / 10000.0)
        amount = "#{('%.3f' % (a - fee))} #{asset}"
        drotto_info "Bid from #{from} for #{amount} (fee: #{fee} #{asset})."
      else
        drotto_info "Bid from #{from} for #{amount}."
      end
      
      invert_vote_weight = if flag_prefix.nil?
        false
      else
        memo =~ /^#{flag_prefix}.*/
      end
      
      bids << {
        from: from,
        author: author,
        permlink: permlink,
        parent_permlink: comment.parent_permlink,
        parent_author: comment.parent_author,
        amount: amount,
        timestamp: timestamp,
        invert_vote_weight: invert_vote_weight,
        trx_id: id
      }
    end
  end
  
  # Only sends transfers after voting is done and only for successful bids.
  def send_vote_memos(memo_ops, bids = nil)
    custom_json_op = if !!bids && bids.any?
      if steem_engine_reward.any?
        steem_engine_rewards = bids.map do |bid|
          quantity = [bid[:amount]].flatten[0].split(' ').first.to_f
          
          next unless quantity.round(steem_engine_reward[:precision]) > 0.0
          
          {
            contractName: 'tokens',
            contractAction: 'transfer',
            contractPayload: {
              symbol: steem_engine_reward[:symbol],
              to: [bid[:from]].flatten[0],
              quantity: "%.#{steem_engine_reward[:precision]}f" % quantity
            }
          }
        end
        
        {
          type: :custom_json,
          id: STEEM_ENGINE_OP_ID,
          required_auths: [account_name],
          required_posting_auths: [],
          json: steem_engine_rewards.to_json
        }
      else
        bids = bids.map do |bid|
          transformed_bid = {
            trx_id: bid[:trx_id],
            author: bid[:author],
            permlink: bid[:permlink]
          }
          
          if bid[:from].size > 1
            transformed_bid[:from] = bid[:from]
          else
            transformed_bid[:from] = bid[:from][0]
          end
          
          if bid[:amount].size > 1
            transformed_bid[:amount] = bid[:amount]
          else
            transformed_bid[:amount] = bid[:amount][0]
          end

          if !!bid[:invert_vote_weight] && bid[:invert_vote_weight].include?(true)
            transformed_bid[:invert_vote_weight] = true
          end
          
          transformed_bid[:timestamp] = bid[:timestamp] if !!bid[:timestamp]
          
          transformed_bid
        end
        
        {
          type: :custom_json,
          id: :drotto,
          required_auths: [account_name],
          required_posting_auths: [],
          json: {
            bids: bids
          }.to_json
        }
      end
    end
    
    if (!!memo_ops && memo_ops.any?) || (!!bids && bids.any?)
      begin
        # Due to steemd implementation, we must use a separate transaction
        # for transfer ops.
        #
        # See: https://github.com/steemit/steem/blob/a6c807f02e37a2efdf6620616c35b184c36d8d4d/libraries/protocol/include/steem/protocol/transaction_util.hpp#L32-L35
        memo_tx = Radiator::Transaction.new(chain_options.merge(wif: active_wif))
        memo_tx.operations = memo_ops if !!memo_ops && memo_ops.any?
        
        # After HF21, don't just skip the op, split it into up to 5.
        # https://steemit.com/steemitblog/@steemitblog/hf21-recommendation-raising-custom-json-limit
        memo_tx.operations << custom_json_op if !!custom_json_op && custom_json_op[:json].size < 2000
        
        if memo_tx.operations.any?
          response = memo_tx.process(true)
          
          if !!response && !!response.error
            drotto_error response.error['message']
          elsif !!response
            drotto_info response
          end
        else
          drotto_warning "No transfer memos."
        end
      rescue => e
        drotto_warning "Unable to send transfer memos: #{e}", e
      end
    end
  end
  
  def join_threads(threads)
    unless threads.nil?
      loop do
        alive = threads.map do |thread|
          thread if thread.alive?
        end.compact
        
        if alive.size > 0
          drotto_info "Still voting: #{alive.size}"
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
    result = find_bids(offset)
    elapsed = result[:elapsed]
    join_threads(result[:bids].values)
    send_vote_memos(result[:memo_ops], result[:bids].keys) if enable_vote_memo?
  end
  
  def run
    loop do
      if current_voting_power < 100.0
        sleep 60
        redo
      end
      
      offset = (base_block_span * 2.10).to_i
      result = find_bids(offset)
      elapsed = result[:elapsed]
      
      if elapsed == -1
        sleep 60
      else
        join_threads(result[:bids].values)
      end
      
      send_vote_memos(result[:memo_ops], result[:bids].keys) if enable_vote_memo?
    end
  end
  
  def state
    error_state = nil
    voting_power = current_voting_power
    
    begin
      error_state = if voting_power < 90.0
        drotto_error 'Current voting power has failed sanity check.'
        
        ERROR_LEVEL_VOTING_POWER_FAILED_SANITY_CHECK
      elsif voting_power == 100.0
        ERROR_LEVEL_VOTING_POWER_HUNG
      else
        error_state = ERROR_LEVEL_VOTING_POWER_OK
      end
    rescue => e
      drotto_error "Unable to check current state: #{e}", backtrace: e.backtrace
      
      error_state = ERROR_LEVEL_VOTING_POWER_FATAL
    ensure
      exit(error_state)
    end
  end
  
  def usage(options = {})
    UsageJob.new.perform(options)
  end
  
  def audit_bidder(options = {})
    AuditBidderJob.new.perform(options)
  end
end
