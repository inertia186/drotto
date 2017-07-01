module DrOtto
  class BounceJob
    include Chain
    
    def initialize(limit)
      @limit = limit
      @limit ||= 200
      response = api.get_account_history(account_name, -@limit, @limit)
      @transactions = response.result
    end
    
    def perform(pretend = false)
      block_num = head_block
      end_block_num = head_block - base_block_span
      totals = {}
      transaction = Radiator::Transaction.new(chain_options.merge(wif: active_wif))
      
      @transactions.each do |index, tx|
        break if tx.block >= end_block_num
        type = tx['op'].first
        next unless type == 'transfer'
        
        id = tx.trx_id
        op = tx['op'].last
        from = op.from
        to = op.to
        amount = op.amount
        memo = op.memo
        timestamp = op.timestamp
          
        next unless to == account_name
        
        author, permlink = parse_slug(memo) rescue [nil, nil]
        next if author.nil? || permlink.nil?
        next unless can_vote?(author, permlink)
        next unless comment(author, permlink).author == author
        next if voted?(author, permlink)
        next unless shall_bounce?(tx)
        next if bounced?(id)
        
        totals[amount.split(' ').last] ||= 0
        totals[amount.split(' ').last] += amount.split(' ').first.to_f
        warning "Need to bounce #{amount} (original memo: #{memo})"
        
        transaction.operations << bounce(from, amount, id)
      end
      
      totals.each do |k, v|
        warning "Need to bounce total: #{v} #{k}"
      end
      
      return true if transaction.operations.size == 0
        
      response = transaction.process(!pretend)
      
      return true if pretend
      
      if !!response && !!response.error
        message = response.error.message
        
        if message.to_s =~ /missing required active authority/
          error "Failed transfer: Check active key."
          
          return false
        end
      end
      
      response
    end
    
    def bounce(from, amount, id)
      {
        type: :transfer,
        from: account_name,
        to: from,
        amount: amount,
        memo: "Unable to accept bid.  (ID:#{id})"
      }
    end
    
    def bounced?(id_to_check)
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
          debug "Already bounced: #{id_to_check}"
          return true
        end
      end
      
      false
    end
    
    # Bounce a transfer if it hasn't aready been bounced, unless it's too old
    # to process.
    def shall_bounce?(tx)
      id_to_bounce = tx.trx_id
      memo = tx['op'].last['memo']
      timestamp = Time.parse(tx.timestamp + 'Z')
      @newest_timestamp ||= @transactions.map do |tx|
        Time.parse(tx.last.timestamp + 'Z')
      end.max
      @oldest_timestamp ||= @transactions.map do |tx|
        Time.parse(tx.last.timestamp + 'Z')
      end.min
      
      if (timestamp - @oldest_timestamp) < 1000
        debug "Too old to bounce."
        return false
      end
      
      debug "Checking if #{id_to_bounce} is in memo history."
      
      !bounced?(id_to_bounce)
    end
  end
end