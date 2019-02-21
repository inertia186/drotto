require 'rdiscount'

module DrOtto
  require 'drotto/config'
  
  module Utils
    include Config
    
    LOGGING_LEVELS = {
      ERR: 1, # error
      WRN: 2, # warn
      INF: 3, # info
      DBG: 4, # debug
      TRC: 5, # trace
    }
    
    def log_level
      level = ENV['LOG'].to_s.upcase.to_sym || :DBG
      LOGGING_LEVELS[level] || 4
    end
    
    def semaphore
       @semaphore ||= Mutex.new
    end
    
    def console(mode, msg, detail = nil)
      color = case mode
      when :INF then :green
      when :WRN then :yellow
      when :ERR then :red
      when :DBG then :yellowish
      else; :pale
      end
      
      output = {mode => msg}
      
      unless detail.nil?
        output[:detail] = detail
        output[:backtrace] = detail.backtrace rescue nil
      end
      
      multiline = if mode == :TRC
        true
      else
        output.size > 1
      end
      
      if log_level >= (LOGGING_LEVELS[mode] || 4)
        if logger.nil?
          # Using `warn` instead of `warning` to do low level warning.
          warn 'Warning: logger is nil (bad config?)'
        else
          case mode
          when :INF then logger.info msg
          when :WRN then logger.warn msg
          when :ERR then logger.error msg
          when :DBG then logger.debug msg
          else; logger.debug msg
          end
        end
        
        semaphore.synchronize do
          ap(output, {multiline: multiline, color: {string: color}})
        end
      end
    end
    
    def drotto_trace(msg, detail = nil); console(:TRC, msg, detail); end
    def drotto_debug(msg, detail = nil); console(:DBG, msg, detail); end
    def drotto_info(msg, detail = nil); console(:INF, msg, detail); end
    def drotto_warning(msg, detail = nil); console(:WRN, msg, detail); end
    def drotto_error(msg, detail = nil); console(:ERR, msg, detail); end
    
    def parse_slug(slug)
      slug = slug.downcase.split('@').last
      author_name = slug.split('/')[0]
      permlink = slug.split('/')[1..-1].join('/')
      permlink = permlink.split('?')[0]
        
      [author_name, permlink]
    end
    
    def normalize_permlink(permlink)
      permlink = permlink.sub(/\/$/, '')
      permlink = permlink.sub(/#comments$/, '')
    end
    
    def merge(options = {})
      comment_md = 'support/confirm.md'
      comment_body = if File.exist?(comment_md)
        File.read(comment_md)
      end

      raise "Cannot read #{template} template or template is empty." if comment_body.nil?

      merged = comment_body
      
      options.each do |k, v|
        merged = case k
        when :from
          merged.gsub("${#{k}}", [v].flatten.join(', @'))
        else; merged.gsub("${#{k}}", v.to_s)
        end
      end

      case options[:markup]
      when :none then merged.strip
      when :html then RDiscount.new(merged).to_html
      when :markdown then merged
      end
    end
  end
end
