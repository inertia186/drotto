require 'test_helper'

module DrOtto
  class UtilsTest < DrOtto::Test
    def test_trace
      assert_nil DrOtto.trace "trace"
    end
    
    def test_debug
      assert_nil DrOtto.debug "debug"
    end
    
    def test_info
      assert_nil DrOtto.info "info"
    end
    
    def test_info_detail
      assert_nil DrOtto.info("info", Exception.new)
    end
    
    def test_warning
      assert_nil DrOtto.warning "warning"
    end
    
    def test_error
      assert_nil DrOtto.error "error"
    end
    
    def test_unknown_type
      assert_nil DrOtto.console(:BOGUS, "unknown_type")
    end
    
    def test_parse_slug
      author, permlink = DrOtto.parse_slug '@author/permlink'
      
      assert_equal 'author', author
      assert_equal 'permlink', permlink
    end
    
    def test_parse_slug_to_comment
      url = 'https://steemit.com/chainbb-general/@howtostartablog/the-joke-is-always-in-the-comments-8-sbd-contest#@btcvenom/re-howtostartablog-the-joke-is-always-in-the-comments-8-sbd-contest-20170624t115213474z'
      author, permlink = DrOtto.parse_slug url
      
      assert_equal 'btcvenom', author
      assert_equal 're-howtostartablog-the-joke-is-always-in-the-comments-8-sbd-contest-20170624t115213474z', permlink
    end
    
    def test_merge
      merge_options = {
        markup: :html,
        content_type: 'content_type',
        vote_weight_percent: 'vote_weight_percent',
        vote_type: 'vote_type',
        account_name: 'account_name',
        from: ['foo', 'bar']
      }
      
      expected_merge = "<p>This content_type has received a vote_weight_percent % vote_type from @account_name thanks to: @foo, @bar.</p>\n"
      assert_equal expected_merge, DrOtto.merge(merge_options)
    end
    
    def test_merge_markdown
      merge_options = {
        markup: :markdown,
        content_type: 'content_type',
        vote_weight_percent: 'vote_weight_percent',
        vote_type: 'vote_type',
        account_name: 'account_name',
        from: ['foo', 'bar']
      }
      
      expected_merge = "This content_type has received a vote_weight_percent % vote_type from @account_name thanks to: @foo, @bar.\n"
      assert_equal expected_merge, DrOtto.merge(merge_options)
    end
    
    def test_merge_nil
      refute DrOtto.merge
    end
  end
end