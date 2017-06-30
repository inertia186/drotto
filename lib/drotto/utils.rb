require 'rdiscount'

module DrOtto
  require 'drotto/config'
  
  module Utils
    include Config
    
    def info(msg)
      ap msg
    end
    
    def debug(msg)
      ap msg
    end
    
    def parse_slug(slug)
      slug = slug.split('@').last
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
        merged = merged.gsub("${#{k}}", v.to_s)
      end

      case options[:markup]
      when :html then RDiscount.new(merged).to_html
      when :markdown then merged
      end
    end
  end
end