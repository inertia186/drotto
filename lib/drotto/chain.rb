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
    
    def voting_in_progress?
      response = nil
      with_api do |api|
        response = api.get_accounts([account_name])
      end
      
      account = response.result.first
      
      last_vote_time = Time.parse(account.last_vote_time + 'Z')
      elapsed = Time.now.utc - last_vote_time
      
      elapsed < 300
    end
    
    def voted?(comment)
      return false if comment.nil?
      voters = comment.active_votes
      
      if voters.map(&:voter).include? account_name
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
      # First, we need a total of all bids for this batch.  This will be used to
      # figure out how much each bid is allocated.
      total = bids.map { |bid| bid[:amount].split(' ').first.to_f }.reduce(0, :+)
      result = {}
      
      # Vote stacking is where multiple bids are created for the same post.  Any
      # number of transfers from any number of accounts can bid on the same
      # post.
      stacked_bids = {}
      
      bids.each do |bid|
        stacked_bids[bid[:author] => bid[:permlink]] ||= {}
        stacked_bid = stacked_bids[bid[:author] => bid[:permlink]]
        
        if stacked_bid.empty?
          stacked_bid[:trx_id] = bid[:trx_id]
          stacked_bid[:from] = [bid[:from]]
          stacked_bid[:amount] = [bid[:amount]]
          stacked_bid[:author] = bid[:author]
          stacked_bid[:permlink] = bid[:permlink]
          stacked_bid[:parent_permlink] = bid[:parent_permlink]
          stacked_bid[:parent_author] = bid[:parent_author]
          stacked_bid[:permlink] = bid[:permlink]
          stacked_bid[:timestamp] = bid[:timestamp]
        else
          stacked_bid[:from] << bid[:from]
          stacked_bid[:amount] << bid[:amount]
        end
      end
      
      bids = stacked_bids.values.sort_by do |b|
        b[:amount].map do |a|
          a.split(' ').first.to_f
        end.reduce(0, :+)
      end.reverse
      
      start = Time.now.utc.to_i
      total_weight = reserve_vote_weight
      
      # Initial pass to remove bids that don't meet the criteria.  Doing this in
      # a separate pass speeds up processing when, for example, there are spam
      # bids with very low impact.
      bids = bids.map do |bid|
        amount = bid[:amount].map{ |a| a.split(' ').first.to_f }.reduce(0, :+)
        coeff = (amount.to_f / total.to_f)
        effective_weight = (weight = batch_vote_weight * coeff).to_i.abs
        
        if effective_weight < min_effective_weight
          # Bid didn't meet min_effective_weight, remove it from the total so it
          # doesn't impact everybody else's bids in the same batch.
          debug "Removing bid from #{bid[:from].join(', ')}, effective_weight too low: #{effective_weight}"
          total -= amount.to_f
          next
        end
        
        bid # This bid is accepted.
      end.compact
      
      # Final pass, actual voting.
      bids.each do |bid|
        amount = bid[:amount].map{ |a| a.split(' ').first.to_f }.reduce(0, :+)
        coeff = (amount.to_f / total.to_f)
        effective_weight = (weight = batch_vote_weight * coeff).to_i
        
        total_weight += effective_weight
        break if total_weight > batch_vote_weight.abs
        
        debug "Total: #{total}; amount: #{amount};"
        debug "total_weight: #{total_weight}; effective_weight: #{effective_weight}; reserve_vote_weight: #{reserve_vote_weight}"
            
        # We are using asynchronous voting because sometimes the blockchain
        # rejects votes that happen too quickly.
        thread = Thread.new do
          from = bid[:from]
          author = bid[:author]
          permlink = bid[:permlink]
          parent_permlink = bid[:parent_permlink]
          parent_author = bid[:parent_author]
          timestamp = bid[:timestamp]
            
          debug "Voting for #{author}/#{permlink} with a coefficnent of #{coeff}."
        
          loop do
            elapsed = Time.now.utc.to_i - start
            break if (base_block_span * 3) < elapsed
            
            vote = {
              type: :vote,
              voter: account_name,
              author: author,
              permlink: permlink,
              weight: effective_weight
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
            
            tx = Radiator::Transaction.new(chain_options.merge(wif: posting_wif))
            tx.operations << vote
            tx.operations << comment unless (no_comment & from).any?
            
            response = nil
            
            begin
              sleep Random.rand(3..20) # stagger procssing
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
              elsif message.to_s =~ /signature is not canonical/
                warning "Retrying vote/comment: signature was not canonical (bug in Radiator?)"
                redo
              end
            end

            if response.nil? || !!response.error
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
            
            info response unless response.nil?
            
            break
          end
        end
        
        result[bid] = thread
      end
      
      result
    end
    
    def current_voting_power
      response = nil
      with_api do |api|
        response = api.get_accounts([account_name])
      end
      
      account = response.result.first
      voting_power = account.voting_power / 100.0
      last_vote_time = Time.parse(account.last_vote_time + 'Z')
      voting_elapse = Time.now.utc - last_vote_time
      current_voting_power = voting_power + (voting_elapse * VOTE_RECHARGE_PER_SEC)
      current_voting_power = [100.0, current_voting_power].min
      diff = current_voting_power - voting_power
      recharge = ((100.0 - current_voting_power) / VOTE_RECHARGE_PER_SEC) / 60
      
      debug "Remaining voting power: #{('%.2f' % current_voting_power)} % (recharged #{('%.2f' % diff)} % since last vote)"
      
      if voting_elapse > 0 && recharge > 0
        debug "Last vote: #{voting_elapse.to_i / 60} minutes ago; #{('%.1f' % recharge)} minutes remain until 100.00 %"
      else
        if voting_elapse > 0
          debug "Last vote: #{voting_elapse.to_i / 60} minutes ago; #{('%.1f' % recharge.abs)} minutes of recharge power unused in 100.00 %"
        end
      end
      
      current_voting_power
    end
  end
end
