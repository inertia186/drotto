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
      @transactions.each do |tx|
        type = tx.last['op'].first
        next unless type == 'transfer'
        
        id = tx.last.trx_id
        op = tx.last['op'].last
        from = op.from
        to = op.to
        amount = op.amount
        memo = op.memo
        timestamp = op.timestamp
          
        next unless to == account_name
        
        author, permlink = parse_slug(memo) rescue [nil, nil]
        next if author.nil? || permlink.nil?
        next unless comment(author, permlink).author == author
        next if voted?(author, permlink)
        next unless shall_bounce?(tx.last)
        next if bounced?(id)
        
        warning "Need to bounce #{amount} (original memo: #{memo})"
        
        bounce(from, amount, id) unless pretend
      end
    end
    
    def bounce(from, amount, id)
      thread = Thread.new do
        loop do
          transfer = {
            type: :transfer,
            from: account_name,
            to: from,
            amount: amount,
            memo: "Unable to accept bid.  (ID:#{id})"
          }
          
          tx = Radiator::Transaction.new(chain_options.merge(wif: active_wif))
          tx.operations << transfer
          
          response = tx.process(true)
          
          if !!response && !!response.error
            message = response.error.message
            if message.to_s =~ /missing required active authority/
              error "Failed transfer: Check active key."
              break
            end
          end
          
          break
        end
      end
    end
    
    def bounced?(id_to_check)
      @memos ||= @transactions.map do |tx|
        type = tx.last['op'].first
        next unless type == 'transfer'
        
        id = tx.last.trx_id
        op = tx.last['op'].last
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