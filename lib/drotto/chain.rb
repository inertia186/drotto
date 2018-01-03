module DrOtto
  require 'drotto/utils'
  
  VOTE_RECHARGE_PER_DAY = 20.0
  VOTE_RECHARGE_PER_HOUR = VOTE_RECHARGE_PER_DAY / 24
  VOTE_RECHARGE_PER_MINUTE = VOTE_RECHARGE_PER_HOUR / 60
  VOTE_RECHARGE_PER_SEC = VOTE_RECHARGE_PER_MINUTE / 60
  
  module Chain
    include Krang::Chain
    include Config
    include Utils
    
    def head_block
      case block_mode
      when 'head' then properties.head_block_number
      when 'irreversible' then properties.last_irreversible_block_num
      else; raise "Unknown block mode: #{block_mode}"
      end
    end
    
    # This method assumes that voting is in progress if current voting power has
    # reached 100 % or the latest vote cast is less than one minute ago.
    def voting_in_progress?
      return true if current_voting_power(log: false) == 100.0
        
      account = api.get_accounts([voter_account_name]) do |accounts|
        accounts.first
      end
      
      last_vote_time = Time.parse(account.last_vote_time + 'Z')
      elapsed = Time.now.utc - last_vote_time
      
      elapsed < 120
    end
    
    def voted?(comment)
      return false if comment.nil?
      voters = comment.active_votes
      
      if voters.map(&:voter).include? voter_account_name
        debug "Already voted for: #{comment.author}/#{comment.permlink} (id: #{comment.id})"
        true
      else
        # debug "No vote found for: #{comment.author}/#{comment.permlink} (id: #{comment.id})"
        false
      end
    end
    
    # Check to see if it's even possible to vote on a post.  Possible reasons
    # to return false include:
    #
    # * Already voted.
    # * Post does not exist.
    # * API temporarily cannot locate post.
    # * Post does not allow votes.
    # * Cashout time already passed.
    # * Cashout time is passed the threshold (to avoid 12-hour lock-out).
    # * Blacklisted.
    # * When comment (reply) bids are disabled.
    def can_vote?(comment)
      return false if comment.nil?
      return false if voted?(comment)
      return false if comment.author == ''
      return false if blacklist.include? comment.author
      return false unless comment.allow_votes
      
      if !allow_comment_bids && comment.parent_author != ''
        debug "Cannot vote for comment (slug: @#{comment.author}/#{comment.permlink})"
        return false
      end
      
      true
    end
    
    def too_old?(comment, options = {use_cashout_time: false})
      return false if comment.nil?
      
      use_cashout_time = options[:use_cashout_time] || false
      cashout_time = Time.parse(comment.cashout_time + 'Z')
      
      if use_cashout_time
        too_old = cashout_time < Time.now.utc
       
        debug "Cashout Time Passed: #{too_old} (slug: @#{comment.author}/#{comment.permlink})"
        
        too_old
      else
        created = Time.parse(comment.created + 'Z')
        too_old = Time.now.utc - created > (max_age * 60)
        cashout_hours_from_now = ((cashout_time - Time.now.utc) / 60.0 / 60.0)
        
        if cashout_hours_from_now < 0
          debug "Too old: #{too_old} (slug: @#{comment.author}/#{comment.permlink})"
        else
          debug "Too old: #{too_old} (slug: @#{comment.author}/#{comment.permlink}); hours remaining: #{('%.1f' % cashout_hours_from_now)}"
        end
        
        too_old
      end
    end
    
    def vote(bids)
      result = {}
      
      # Vote stacking is where multiple bids are created for the same post.  Any
      # number of transfers from any number of accounts can bid on the same
      # post.
      stacked_bids = {}
      
      # If we find a bid that qualifis as maximum, only this bid is processed in
      # the current window and all others are processed later.
      max_bid = nil
      
      bids.each do |bid|
        stacked_bids[bid[:author] => bid[:permlink]] ||= {}
        stacked_bid = stacked_bids[bid[:author] => bid[:permlink]]
        
        amount = if bid[:amount].split(' ').last == minimum_bid_asset
          bid[:amount]
        else
          a, amount_asset = bid[:amount].split(' ')
          a = a.to_f
          ratio = base_to_debt_ratio
          
          market_amount = case amount_asset
          when 'STEEM', 'GOLOS'
            "%.3f #{minimum_bid_asset}" % (a * ratio)
          when 'SBD', 'GBG'
            "%.3f #{minimum_bid_asset}" % (a / ratio)
          else
            error 'Unsupported asset for bid.', bid
            "0.000 #{minimum_bid_asset}"
          end
          
          info "Evaluating bid at #{bid[:amount]} as #{market_amount} (ratio: #{ratio})"
          
          market_amount
        end
        
        if stacked_bid.empty?
          stacked_bid[:trx_id] = bid[:trx_id]
          stacked_bid[:from] = [bid[:from]]
          stacked_bid[:amount] = [amount]
          stacked_bid[:invert_vote_weight] = [bid[:invert_vote_weight]]
          stacked_bid[:author] = bid[:author]
          stacked_bid[:permlink] = bid[:permlink]
          stacked_bid[:parent_permlink] = bid[:parent_permlink]
          stacked_bid[:parent_author] = bid[:parent_author]
          stacked_bid[:permlink] = bid[:permlink]
          stacked_bid[:timestamp] = bid[:timestamp]
        else
          stacked_bid[:from] << bid[:from]
          stacked_bid[:amount] << amount
          stacked_bid[:invert_vote_weight] << bid[:invert_vote_weight]
        end
      end
      
      bids = stacked_bids.values.sort_by do |b|
        b[:amount].map do |a|
          a.split(' ').first.to_f
        end.reduce(0, :+)
      end.reverse
      
      # First, we need a total of all bids for this batch.  This will be used to
      # figure out how much each bid is allocated.
      total = bids.map do |bid|
        bid[:amount].map do |a|
          a.split(' ').first.to_f
        end.reduce(0, :+)
      end.reduce(0, :+)
      
      start = Time.now.utc.to_i
      total_weight = reserve_vote_weight
      
      # Initial pass to remove bids that don't meet the criteria.  Doing this in
      # a separate pass speeds up processing when, for example, there are spam
      # bids with very low impact.
      bids = bids.map do |bid|
        amount = bid[:amount].map{ |a| a.split(' ').first.to_f }.reduce(0, :+)
        coeff = (amount.to_f / total.to_f)
        effective_weight = (weight = batch_vote_weight * coeff).to_i.abs
        
        if bid[:invert_vote_weight].uniq.size > 1
          info "Removing bid from #{bid[:from].join(', ')}, in-window-flag-war detected."
          total -= amount.to_f
          next
        end
        
        if effective_weight < min_effective_weight
          # Bid didn't meet min_effective_weight, remove it from the total so it
          # doesn't impact everybody else's bids in the same batch.
          info "Removing bid from #{bid[:from].join(', ')}, effective_weight too low: #{effective_weight}"
          total -= amount.to_f
          next
        end
        
        if max_effective_weight > 0.0 && effective_weight >= max_effective_weight
          # Setting this value only once, in order of bid receipt.
          info "Only processing bid from #{bid[:from].join(', ')}, effective_weight maximum found: #{effective_weight} (max_effective_weight: #{max_effective_weight})."
          
          max_bid ||= bid
        end
        
        bid # This bid is accepted.
      end.compact
      
      if !!max_bid
        # Max bid override now in effect; all other bids shall be rescinded.
        total = max_bid[:amount].map{ |a| a.split(' ').first.to_f }.reduce(0, :+)
  
        bids = [max_bid]
      end
      
      reset_vote_schedule
      
      # Final pass, actual voting.
      bids.each do |bid|
        amount = bid[:amount].map{ |a| a.split(' ').first.to_f }.reduce(0, :+)
        invert_vote_weight = bid[:invert_vote_weight].uniq.last
        coeff = (amount.to_f / total.to_f)
        effective_weight = (weight = batch_vote_weight * coeff).to_i
        weight = invert_vote_weight ? -weight : weight
        
        total_weight += effective_weight
        break if total_weight > batch_vote_weight.abs
        
        info "Total: #{total}; amount: #{amount};"
        info "total_weight: #{total_weight}; effective_weight: #{effective_weight}; reserve_vote_weight: #{reserve_vote_weight}"
        
        # We are using asynchronous voting because sometimes the blockchain
        # rejects votes that happen too quickly.
        thread = Thread.new do
          sleep vote_schedule
          
          # while vote_latch
          #   puts "Sleeping ..."
          #   sleep 3
          # end
          
          from = bid[:from]
          author = bid[:author]
          permlink = bid[:permlink]
          parent_permlink = bid[:parent_permlink]
          parent_author = bid[:parent_author]
          timestamp = bid[:timestamp]
            
          if invert_vote_weight
            info "Flagging #{author}/#{permlink} with a coefficnent of #{coeff}."
          else
            info "Voting for #{author}/#{permlink} with a coefficnent of #{coeff}."
          end
        
          loop do
            if BounceJob.new.bounced?(bid[:trx_id])
              warning "Bid was bounce just before voting: @#{author}/#{permlink}"
              break
            end
            
            elapsed = Time.now.utc.to_i - start
            break if (base_block_span * 3) < elapsed
            
            vote = {
              type: :vote,
              voter: account_name,
              author: author,
              permlink: permlink,
              weight: invert_vote_weight ? -effective_weight : effective_weight
            }
            
            merge_options = {
              markup: :html,
              content_type: parent_author == '' ? 'post' : 'comment',
              vote_weight_percent: ("%.2f" % (weight / 100)),
              vote_type: weight > 0 ? 'upvote' : 'downvote',
              account_name: account_name,
              from: from
            }
            
            comment = {
              type: :comment,
              parent_permlink: permlink,
              author: account_name,
              permlink: "re-#{author.gsub(/[^a-z0-9\-]+/, '-')}-#{permlink}-#{Time.now.utc.strftime('%Y%m%dt%H%M%S%Lz')}", # e.g.: 20170225t235138025z
              title: '',
              body: merge(merge_options),
              json_metadata: "{\"tags\":[\"#{parent_permlink}\"],\"app\":\"#{DrOtto::AGENT_ID}\"}",
              parent_author: author
            }
            
            voting_tx = nil
            tx = Radiator::Transaction.new(chain_options.merge(wif: posting_wif))
            tx.operations << vote
            tx.operations << comment unless (no_comment & from).any?
            
            if account_name != voter_account_name
              voting_tx = Radiator::Transaction.new(chain_options.merge(wif: voting_wif))
              voting_tx.operations << {
                type: :vote,
                voter: voter_account_name,
                author: author,
                permlink: permlink,
                weight: invert_vote_weight ? -effective_weight : effective_weight
              }
            end
            
            response = nil
            
            if !!voting_tx
              begin
                semaphore.synchronize do
                  response = voting_tx.process(true)
                end
              rescue => e
                warning "Unable to vote: #{e}", e
                break
              end
              
              if !!response && !!response.error
                message = response.error.message
                if message.to_s =~ /You have already voted in a similar way./
                  error "Failed vote: duplicate vote."
                  # break
                elsif message.to_s =~ /Can only vote once every 3 seconds./
                  warning "Retrying vote: voting too quickly."
                  sleep Random.rand(3..6) # stagger retry
                  redo
                elsif message.to_s =~ /Voting weight is too small, please accumulate more voting power or steem power./
                  error "Failed vote: voting weight too small"
                  break
                elsif message.to_s =~ /Vote weight cannot be 0/
                  error "Failed vote: vote weight cannot be zero."
                  break
                elsif message.to_s =~ /STEEMIT_UPVOTE_LOCKOUT_HF17/
                  error "Failed vote: upvote lockout (last twelve hours before payout)"
                  if auto_bounce_on_lockout && !(no_bounce.include?(from))
                    BounceJob.new.force_bounce!(bid[:trx_id])
                  end
                  break
                elsif message.to_s =~ /missing required posting authority/
                  error "Failed vote: Check posting key."
                  break
                elsif message.to_s =~ /unknown key/
                  error "Failed vote: unknown key (testing?)"
                  break
                elsif message.to_s =~ /tapos_block_summary/
                  warning "Retrying vote/comment: tapos_block_summary (?)"
                  redo
                elsif message.to_s =~ /now < trx.expiration/
                  warning "Retrying vote/comment: now < trx.expiration (?)"
                  redo
                elsif message.to_s =~ /transaction expiration exception/
                  warning "Retrying vote/comment: transaction expiration exception"
                  redo
                elsif message.to_s =~ /!check_max_block_age( _max_block_age ):/
                  warning "Retrying vote/comment: !check_max_block_age( _max_block_age ):"
                  redo
                elsif message.to_s =~ /signature is not canonical/
                  warning "Retrying vote/comment: signature was not canonical (bug in Radiator?)"
                  redo
                end
              end
            end
            
            info response unless response.nil?
            
            begin
              semaphore.synchronize do
                response = tx.process(true)
              end
            rescue => e
              warning "Unable to vote and comment, retrying with just vote: #{e}", e
            end
            
            if !!response && !!response.error
              message = response.error.message
              if message.to_s =~ /You have already voted in a similar way./
                error "Failed vote: duplicate vote."
                break
              elsif message.to_s =~ /You may only comment once every 20 seconds./
                warning "Retrying vote/comment: commenting too quickly."
                sleep Random.rand(20..40) # stagger retry
                redo
              elsif message.to_s =~ /Can only vote once every 3 seconds./
                warning "Retrying vote: voting too quickly."
                sleep Random.rand(3..6) # stagger retry
                redo
              elsif message.to_s =~ /STEEMIT_MAX_PERMLINK_LENGTH: permlink is too long/
                error "Failed comment: permlink too long; only vote"
                # just flunking comment
              elsif message.to_s =~ /Voting weight is too small, please accumulate more voting power or steem power./
                error "Failed vote: voting weight too small"
                break
              elsif message.to_s =~ /Vote weight cannot be 0/
                error "Failed vote: vote weight cannot be zero."
                break
              elsif message.to_s =~ /STEEMIT_UPVOTE_LOCKOUT_HF17/
                error "Failed vote: upvote lockout (last twelve hours before payout)"
                if auto_bounce_on_lockout && !(no_bounce.include?(from))
                  BounceJob.new.force_bounce!(bid[:trx_id])
                end
                break
              elsif message.to_s =~ /missing required posting authority/
                error "Failed vote: Check posting key."
                break
              elsif message.to_s =~ /unknown key/
                error "Failed vote: unknown key (testing?)"
                break
              elsif message.to_s =~ /tapos_block_summary/
                warning "Retrying vote/comment: tapos_block_summary (?)"
                redo
              elsif message.to_s =~ /now < trx.expiration/
                warning "Retrying vote/comment: now < trx.expiration (?)"
                redo
              elsif message.to_s =~ /transaction expiration exception/
                warning "Retrying vote/comment: transaction expiration exception"
                redo
              elsif message.to_s =~ /!check_max_block_age( _max_block_age ):/
                warning "Retrying vote/comment: !check_max_block_age( _max_block_age ):"
                redo
              elsif message.to_s =~ /signature is not canonical/
                warning "Retrying vote/comment: signature was not canonical (bug in Radiator?)"
                redo
              end
            end

            if response.nil? || !!response.error
              if !!response && !!response.result && !!response.result.trx_id
                warning "Problem while voting, but the transaction was found."
                response.delete(:error)
              else
                warning "Problem while voting.  Retrying with just vote: #{response}"
                tx.operations = [vote]
                
                begin
                  semaphore.synchronize do
                    response = tx.process(true)
                  end
                rescue => e
                  error "Unable to vote: #{e}", e
                end
              end
            end
            
            info response unless response.nil?
            
            block_nums = []
            block_nums << @last_broadcast_block.to_i if !!@last_broadcast_block
            block_nums << response.result.block_num.to_i if !!response.result
            @last_broadcast_block = block_nums.max
            
            break
          end
        end
        
        result[bid] = thread
      end
      
      result
    end
    
    def current_voting_power(options = {log: true})
      account = api.get_accounts([voting_power_account_name]) do |accounts|
        accounts.first
      end
      
      voting_power = account.voting_power / 100.0
      last_vote_time = Time.parse(account.last_vote_time + 'Z')
      voting_elapse = Time.now.utc - last_vote_time
      current_voting_power = voting_power + (voting_elapse * VOTE_RECHARGE_PER_SEC)
      current_voting_power = [100.0, current_voting_power].min
      diff = current_voting_power - voting_power
      recharge = ((100.0 - current_voting_power) / VOTE_RECHARGE_PER_SEC) / 60
      
      if !!options[:log]
        info "Remaining voting power: #{('%.2f' % current_voting_power)} % (recharged #{('%.2f' % diff)} % since last vote)"
      
        if voting_elapse > 0 && recharge > 0
          info "Last vote: #{voting_elapse.to_i / 60} minutes ago; #{('%.1f' % recharge)} minutes remain until 100.00 %"
        else
          if voting_elapse > 0
            info "Last vote: #{voting_elapse.to_i / 60} minutes ago; #{('%.1f' % recharge.abs)} minutes of recharge power unused in 100.00 %"
          end
        end
      end
      
      current_voting_power
    end
    
    def base_to_debt_ratio
      @last_base_to_debt_ratio = market_history_api.get_ticker do |ticker|
        latest = ticker.latest.to_f
        bid = ticker.highest_bid.to_f
        ask = ticker.lowest_ask.to_f
        [latest, bid, ask].reduce(0, :+) / 3.0
      end
    rescue => e
      warning "Unable to query market data.", e
      reset_market_history_api
    ensure
      @last_base_to_debt_ratio || 1.0
    end
    
    def reset_market_history_api
      @market_history_api = nil
    end
    
    def market_history_api
      @market_history_api ||= Radiator::MarketHistoryApi.new(chain_options)
    end
    
    def accepted_asset?(amount)
      ([minimum_bid_asset] + alternative_assets).include? amount.split(' ').last
    end
    
    def reset_vote_schedule
      @last_vote_schedule = nil
      @current_vote_schedule = nil
      @last_vote_schedule = nil
    end
    
    def vote_schedule
      @last_vote_schedule ||= 0.0
      @current_vote_schedule ||= 0.0
      @current_vote_schedule += 20.0
      @current_vote_schedule
    end
    
    def vote_latch
      reset_properties
      
      @last_broadcast_block.to_i + 7 > properties.head_block_number
    end
  end
end
