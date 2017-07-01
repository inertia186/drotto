require 'rdiscount'

module DrOtto
  require 'drotto/config'
  
  module Utils
    include Config
    
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
      
      semaphore.synchronize do
        ap(output, {multiline: output.size > 1, color: {string: color}})
      end
    end
    
    def info(msg, detail = nil); console(:INF, msg, detail); end
    def warning(msg, detail = nil); console(:WRN, msg, detail); end
    def error(msg, detail = nil); console(:ERR, msg, detail); end
    def debug(msg, detail = nil); console(:DBG, msg, detail); end
    
    def parse_slug(slug)
      slug = slug.downcase.split('@').last
      author_name = slug.split('/')[0]
      permlink = slug.split('/')[1..-1].join('/')
      permlink = permlink.split('?')[0]
        
      [author_name, permlink]
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
      when :html then RDiscount.new(merged).to_html
      when :markdown then merged
      end
    end
  end
end