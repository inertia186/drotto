module DrOtto
  require 'drotto/utils'
  
  module Chain
    include Utils
    
    def api
      @api ||= Radiator::Api.new(chain_options)
    end
    
    def reset_properties
      @properties = nil
      @latest_properties = nil
    end
    
    def properties
      if !@latest_properties.nil? && Time.now - @latest_properties > 30
        @properties = nil
        @latest_properties = nil
      end
      
      return @properties unless @properties.nil?
      
      response = api.get_dynamic_global_properties
      response.result.tap do |properties|
        @latest_properties = Time.parse(properties.time + 'Z')
        @properties = properties
      end
    end
    
    def head_block
      case block_mode
      when 'head' then properties.head_block_number
      when 'irreversible' then properties.last_irreversible_block_num
      else; raise "Unknown block mode: #{block_mode}"
      end
    end
    
    def block_time
      Time.parse(properties.time + 'Z')
    end
    
    def comment(author, permlink)
      @comments ||= {}
      
      @comments.delete(@comments.keys.sample) if @comments.size > 50
      
      if !!@comments[author => permlink]
        @comments[author => permlink]
      else
        response = api.get_content(author, permlink)
        @comments[author => permlink] = response.result
      end
    end
    
    def voted?(author, permlink)
      comment = comment(author, permlink)
      voters = comment.active_votes
      
      if voters.map(&:voter).include? account_name
        debug "Already voted for: #{author}/#{permlink}"
        true
      else
        false
      end
    end
    
    def vote(bids)
      total = bids.map { |bid| bid[:amount].split(' ').first.to_i }.reduce(0, :+)
      
      bids.each do |bid|
        from = bid[:from]
        amount = bid[:amount].split(' ').first.to_i
        author = bid[:author]
        permlink = bid[:permlink]
        parent_permlink = bid[:parent_permlink]
        parent_author = bid[:parent_author]
        timestamp = bid[:permlink]
        coeff = (amount.to_f / total.to_f)
        
        debug "Total: #{total}; amount: #{amount}"
        debug "Voting for #{author}/#{permlink} with a coefficnent of #{coeff}."
        
        vote = {
          type: :vote,
          voter: account_name,
          author: author,
          permlink: permlink,
          weight: (weight = batch_vote_weight * coeff).to_i
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
        tx.operations << comment
        
        response = nil
        
        begin
          response = tx.process(true)
        rescue => e
          info "Unable to vote and comment, retrying with just vote: #{e}"
        end
        
        if response.nil? || !!response.error
          info "Retrying with just vote: #{response}"
          tx.operations = [vote]
          
          begin
            response = tx.process(true)
          rescue => e
            info "Unable to vote: #{e}"
          end
        end
        
        info response unless response.nil?
      end
    end
  end
end

