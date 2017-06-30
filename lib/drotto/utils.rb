require 'rdiscount'

module DrOtto
  require 'drotto/config'
  
  module Utils
    include Config
    
    def build_logging_output(key, msg, detail)
      output = {key => msg}
      output[:backtrace] = detail.backtrace if defined? detail.backtrace
      output
    end
    
    def info(msg, detail = nil)
      output = build_logging_output :INF, msg, detail
      ap(output, {multiline: !!(defined? detail.backtrace), color: {string: :green}})
    end
    
    def warning(msg, detail = nil)
      output = build_logging_output :WRN, msg, detail
      ap(output, {multiline: !!(defined? detail.backtrace), color: {string: :yellow}})
    end
    
    def error(msg, detail = nil)
      output = build_logging_output :ERR, msg, detail
      ap(output, {multiline: !!(defined? detail.backtrace), color: {string: :red}})
    end
    
    def debug(msg, detail = nil)
      output = build_logging_output :DBG, msg, detail
      ap(output, {multiline: !!(defined? detail.backtrace), color: {string: :yellowish}})
    end
    
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