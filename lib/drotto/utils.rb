require 'rdiscount'

module DrOtto
  require 'drotto/config'
  
  module Utils
    include Krang::Utils
    include Config
    
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
      when :html then RDiscount.new(merged).to_html
      when :markdown then merged
      end
    end
  end
end