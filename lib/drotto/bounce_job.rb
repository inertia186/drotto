module DrOtto
  class BounceJob
    include Chain
    
    VIRTUAL_OP_TRANSACTION_ID = '0000000000000000000000000000000000000000'
    
    def initialize(limit = nil, starting_block = nil)
      @limit = limit
      @starting_block = starting_block
      
      override_config DrOtto.config
      app_key DrOtto.app_key
      agent_id DrOtto.agent_id
      init_transactions unless @limit.nil?
    end
    
    def init_transactions
      return unless @transactions.nil?
      
      response = nil
      
      limit = if @limit.to_i > 0
        @limit.to_i
      else
        max_limit
      end
      
      @transactions = []
      count = 0
      
      if limit <= max_limit
        response = api.get_account_history(account_name, -1, limit - 1)
        
        if !!response.error
          krang_error response.error
        else
          @transactions += response.result
        end
      else
        krang_warning "Requested limit is greater than api allows.  Paging in #{limit / max_limit} chunks, which might take a while."
        
        while (from = (limit - @transactions.size)) > 0
          response = api.get_account_history(account_name, from, [max_limit, limit].min - 1)
          
          if !!response.error
            krang_error response.error
            break
          end
            
          @transactions += response.result
        end
        
        @transactions = @transactions.uniq.reverse
      end
      
      krang_debug "Transactions found: #{@transactions.size}"
      
      @memos = nil
    end
    
    def perform(pretend = false)
      @memos_in_transaction = []
      
      if voting_in_progress? && !pretend
        krang_debug "Voting in progress, bounce suspended ..."
        sleep 120
        return
      end
      
      block_num = head_block
      end_block_num = head_block - (base_block_span * 2.2)
      totals = {}
      transaction = Radiator::Transaction.new(chain_options.merge(wif: active_wif))
      
      if @transactions.nil?
        krang_warning "Unable to read transactions for limit: #{@limit.inspect}"
        return
      end
      
      @transactions.each do |index, tx|
        if transaction.operations.size >= 100
          krang_warning "Soft transfer limit reached in this pass."
          break
        end
        
        case @limit
        when 'today'
          timestamp = Time.parse(tx.timestamp + 'Z')
          today = Time.now.utc - 86400
          next if timestamp < today
        end
      
        break if tx.block >= end_block_num
        type = tx['op'].first
        next unless type == 'transfer'
        
        id = tx.trx_id
        op = tx['op'].last
        from = op.from
        to = op.to
        amount = op.amount
        memo = op.memo.strip
        timestamp = op.timestamp
          
        next unless to == account_name
        
        if id.to_s.size == 0
          krang_warning "Empty id for transaction.", tx
          next
        end
        
        author, permlink = parse_slug(memo) rescue [nil, nil]
        next if author.nil? || permlink.nil?
        permlink = normalize_permlink permlink
        next if vote_cache_hit?(author, permlink)
        next if bounce_cache_hit?(id)
        comment = find_comment(author, permlink)
        next if comment.nil?
        
        next unless can_vote?(comment)
        next if too_old?(comment, use_cashout_time: true)
        next unless comment.author == author
        next if voted?(comment)
        next unless shall_bounce?(tx)
        next if bounced?(id)
        next if !bounce_below_minimum_bid? && below_minimum_bid?(amount)
      
        if ignored?(amount)
          krang_debug "Ignoring #{amount} (original memo: #{memo})"
          next
        end

        totals[amount.split(' ').last] ||= 0
        totals[amount.split(' ').last] += amount.split(' ').first.to_f
        krang_warning "Need to bounce #{amount} (original memo: #{memo})"
        @memos_in_transaction << memo
        
        transaction.operations << bounce(from, amount, id)
      end
      
      totals.each do |k, v|
        krang_info "Need to bounce total: #{v} #{k}"
      end
      
      return true if transaction.operations.size == 0
        
      response = transaction.process(!pretend)
      
      return true if pretend
      
      if !!response && !!response.error
        message = response.error.message
        
        if message.to_s =~ /missing required active authority/
          krang_error "Failed transfer: Check active key."
          
          return false
        else
          krang_error "Unable to bounce", response.error
        end
      else
        @memos_in_transaction.each do |memo|
          bounce_cache_file_append_cache_key memo
        end
      end
      
      response
    end
    
    # This method will look for transfers that must immediately bounce because
    # they've already been voted on, or various other criteria.  Basically, the
    # user sent a transfer that is invalid and can't possibly be processed in
    # a future timeframe.
    def stream(max_ops = -1)
      @limit ||= 200
      stream = Radiator::Stream.new(chain_options)
      count = 0
      
      krang_info "Streaming bids to #{account_name}; starting at block #{head_block}; current time: #{block_time} ..."
      
      loop do
        begin
          stream.blocks do |block, block_num|
            api.get_ops_in_block(block_num, false) do |ops, error|
              ops.each do |op_data|
                id = op_data.trx_id
                type, op = op_data.op
                
                count = count + 1
                return count if max_ops > 0 && max_ops <= count
                next unless type == 'transfer'
                needs_bounce = false
                
                from = op.from
                to = op.to
                amount = op.amount
                memo = op.memo.strip
                
                next unless to == account_name
                next if no_bounce.include? from
                next if ignored?(amount)
                next if !bounce_below_minimum_bid? && below_minimum_bid?(amount)
                
                author, permlink = parse_slug(memo) rescue [nil, nil]
                
                if author.nil? || permlink.nil?
                  krang_debug "Bad memo.  Original memo: #{memo}"
                  needs_bounce = true
                else
                  permlink = normalize_permlink permlink
                  comment = find_comment(author, permlink)
                end
                
                if comment.nil?
                  krang_debug "No such comment.  Original memo: #{memo}"
                  needs_bounce = true
                else
                  if too_old?(comment)
                    krang_debug "Cannot vote, too old.  Original memo: #{memo}"
                    needs_bounce = true
                  end
                  
                  if !allow_comment_bids && comment.parent_author != ''
                    krang_debug "Cannot vote for comment (slug: @#{comment.author}/#{comment.permlink})"
                    needs_bounce = true
                  end

                  if !!comment && comment.author != author
                    krang_debug "Sanity check failed.  Comment author not the author parsed.  Original memo: #{memo}"
                    needs_bounce = true
                  end
                end
                
                # If bids are accepted while voting is in progress, it's very
                # likely they will not stack if there is currently a bid in the
                # window.  It's better to just bounce everything until voting is
                # finished.
                if voting_in_progress?
                  @transactions = nil # dump
                  
                  if trx_ids_for_memo(author, permlink).size < 2
                    krang_debug "Voting is currently in progress, delaying bid until next window.  Original memo: #{memo}"
                  else
                    krang_debug "Cannot accept attempted stacked bid because voting is currently in progress.  Original memo: #{memo}"
                    needs_bounce = true
                  end
                end
                
                # Final check.  Don't bounce if already bounced.  This should only
                # happen under a race condition (rarely).  So we hold off dumping
                # the transactions in memory until we actually need to know.
                if needs_bounce
                  @transactions = nil # dump
                  
                  if bounced?(id)
                    needs_bounce = false
                  end
                  
                  # This is tricky.  On the one hand, we don't want to bounce a
                  # bid that just got a vote.  But on the other hand, we want
                  # to bounce bids that were rebid by accident, even if they
                  # got votes.  That's why the stream default is to only
                  # consider the last 200 operations.
                  
                  if already_voted?(author, permlink, use_api: true)
                    needs_bounce = false
                  end
                end
                
                if needs_bounce
                  transaction = Radiator::Transaction.new(chain_options.merge(wif: active_wif))
                  transaction.operations << bounce(from, amount, id)
                  response = transaction.process(true)
                  
                  if !!response && !!response.error
                    message = response.error.message
                    
                    if message.to_s =~ /missing required active authority/
                      krang_error "Failed transfer: Check active key."
                    else
                      krang_error "Unable to bounce", response.error
                    end
                  else
                    bounce_cache_file_append_cache_key memo
                    krang_info "Bounced #{amount} (original memo: #{memo})", response
                  end
                  
                  next
                end
                  
                krang_info "Allowing #{amount} (original memo: #{memo})"
              end
            end
          end
        rescue => e
          krang_warning e.inspect, e
          reset_api
          sleep backoff
        end
      end
    end
    
    def bounce(from, amount, id)
      {
        type: :transfer,
        from: account_name,
        to: from,
        amount: amount,
        memo: "#{bounce_memo}  (ID:#{id})"
      }
    end
    
    def ignored?(amount)
      ignore_asset == amount.split(' ').last
    end
    
    def below_minimum_bid?(amount)
      amount, asset = amount.split(' ')
      amount = amount.to_f
      minimum_amount, minimum_asset = minimum_bid.split(' ')
      minimum_amount = minimum_amount.to_f
      
      if asset == minimum_asset
        amount < minimum_amount
      else
        ratio = base_to_debt_ratio
        market_amount = case asset
        when 'STEEM', 'GOLOS' then amount * ratio
        when 'SBD', 'GBG' then amount / ratio
        else
          krang_error 'Unsupported asset for bid.', bid
          0.000
        end
        
        market_amount < minimum_amount
      end
    end
    
    def bounced?(id_to_check)
      return true if bounce_cache_hit?(id_to_check)
      
      init_transactions
      
      @memos ||= @transactions.map do |index, tx|
        type = tx['op'].first
        next unless type == 'transfer'
        
        id = tx.trx_id
        op = tx['op'].last
        f = op['from']
        m = op['memo']
        
        next unless f == account_name
        next if m.empty?
          
        m
      end.compact
      
      @memos.each do |memo|
        if memo =~ /.*\(ID:#{id_to_check}\)$/
          krang_debug "Already bounced: #{id_to_check}"
          bounce_cache_file_append_cache_key id_to_check
          return true
        end
      end
      
      false
    end
    
    # Bounce a transfer if it hasn't aready been bounced, unless it's too old
    # to process.
    def shall_bounce?(tx)
      return false if no_bounce.include? tx['op'].last['from']
      
      id_to_bounce = tx.trx_id
      
      return false if bounce_cache_hit?(id_to_bounce)
      
      memo = tx['op'].last['memo']
      timestamp = Time.parse(tx.timestamp + 'Z')
      @newest_timestamp ||= @transactions.map do |tx|
        Time.parse(tx.last.timestamp + 'Z')
      end.max
      @oldest_timestamp ||= @transactions.map do |tx|
        Time.parse(tx.last.timestamp + 'Z')
      end.min
      
      if (timestamp - @oldest_timestamp) < 1000
        krang_debug "Too old to bounce."
        return false
      end
      
      krang_debug "Checking if #{id_to_bounce} is in memo history."
      
      !bounced?(id_to_bounce)
    end
    
    # This bypasses the usual validations and issues a bounce for a transaction.
    def force_bounce!(trx_id)
      if trx_id.to_s.size == 0
        krang_warning "Empty transaction id."
        return
      end

      init_transactions
      
      return false if bounced?(trx_id)

      totals = {}
      transaction = Radiator::Transaction.new(chain_options.merge(wif: active_wif))
      
      @transactions.each do |index, tx|
        type = tx['op'].first
        next unless type == 'transfer'
        
        id = tx.trx_id
        next unless id == trx_id
        
        op = tx['op'].last
        from = op.from
        to = op.to
        amount = op.amount
        memo = op.memo.strip
        timestamp = op.timestamp
          
        next unless to == account_name
        
        if no_bounce.include? from
          krang_warning "Won't bounce #{from} (in no_bounce list)."
          next
        end
        
        author, permlink = parse_slug(memo) rescue [nil, nil]
        
        if author.nil? || permlink.nil?
          krang_warning "Could not find author or permlink with memo: #{memo}"
        else  
          permlink = normalize_permlink permlink
          comment = find_comment(author, permlink)
        end
        
        if comment.nil?
          krang_warning "Could not find comment with author and permlink: #{author}/#{permlink}"
        end
        
        unless comment.author == author
          krang_warning "Comment author and memo author do not match: #{comment.author} != #{author}"
        end
        
        totals[amount.split(' ').last] ||= 0
        totals[amount.split(' ').last] += amount.split(' ').first.to_f
        krang_warning "Need to bounce #{amount} (original memo: #{memo})"
        bounce_cache_file_append_cache_key memo
        
        transaction.operations << bounce(from, amount, id)
      end
      
      totals.each do |k, v|
        krang_info "Need to bounce total: #{v} #{k}"
      end
      
      return true if transaction.operations.size == 0
        
      response = transaction.process(true)
      
      if !!response && !!response.error
        message = response.error.message
        
        if message.to_s =~ /missing required active authority/
          krang_error "Failed transfer: Check active key."
          
          return false
        elsif message.to_s =~ /unknown key/
          krang_error "Failed vote: unknown key (testing?)"
          
          return false
        elsif message.to_s =~ /tapos_block_summary/
          krang_warning "Retrying vote/comment: tapos_block_summary (?)"
          
          return false
        elsif message.to_s =~ /now < trx.expiration/
          krang_warning "Retrying vote/comment: now < trx.expiration (?)"
          
          return false
        elsif message.to_s =~ /signature is not canonical/
          krang_warning "Retrying vote/comment: signature was not canonical (bug in Radiator?)"
          
          return false
        end
      end
      
      krang_info response unless response.nil?

      response
    end
    
    def already_voted?(author, permlink, options = {})
      return true if vote_cache_hit?(author, permlink)
      
      cache_key = "#{author}/#{permlink}"
      
      if !!options[:use_api]
        comment = find_comment(author, permlink)
        
        if comment.nil?
          krang_warning "Couldn't find @#{author}/#{permlink} with api."
          return true
        end
        
        voted = !!comment.active_votes.find { |v| v.voter == voter_account_name }
        
        vote_cache_file_append_cache_key cache_key if voted
        
        voted
      else
        @transactions.each do |index, trx|
          if trx.op[0] == 'vote' && trx.op[1].author == author && trx.op[1].permlink == permlink
            vote_cache_file_append_cache_key cache_key
            return true
          end
        end
        
        false
      end
    end
    
    # This will help located pending stacked bids.
    def trx_ids_for_memo(author, permlink)
      init_transactions if @transactions.nil?
      
      memo = "@#{author}/#{permlink}"
      trx_ids = @transactions.map do |index, trx|
        trx if trx.op[0] == 'transfer' && trx.op[1].memo.include?(memo)
      end.compact
      
      krang_debug "Transfers for memo #{memo}: #{trx_ids.size}"
      
      trx_ids
    end
    
    def transfer(trx_id)
      @transactions.each do |index, trx|
        return trx if trx_id == trx.trx_id
      end
    end
    
    def transfer_ids
      init_transactions
      
      @transfer_ids ||= @transactions.map do |index, trx|
        next if !!@starting_block && trx.block < @starting_block
        
        if trx.op[0] == 'transfer'
          slug = trx.op[1].memo.strip
          next if slug.nil?
          
          author, permlink = parse_slug(slug) rescue [nil, nil]
          next if author.nil? || permlink.nil?
          
          trx.trx_id unless already_voted?(author, permlink)
        end
      end.compact.uniq - [VIRTUAL_OP_TRANSACTION_ID]
    end
    
    def max_limit
      if chain_options[:chain] == 'golos'
        2000
      else
        10000
      end
    end
  end
end
