require 'test/unit'
require 'rbosa'

class TC_GetApp < Test::Unit::TestCase
    def setup
        @itunes = OSA.app_with_name('iTunes')
    end

    def test_with_name
        assert_equal('iTunes', @itunes.name)
        assert_raises(RuntimeError) { OSA.app_with_name('SomethingThatDoesNotExist') }
    end

    def test_with_bundle_id
        app = OSA.app_with_bundle_id('com.apple.iTunes')
        assert_equal(@itunes, app)
        assert_raises(RuntimeError) { OSA.app_with_bundle_id('com.apple.vaporware') }
    end
   
    def test_with_signature
        app = OSA.app_with_signature('hook')
        assert_equal(@itunes, app)
        assert_raises(RuntimeError) { OSA.app_with_signature('XXXX') }
    end
    
    def test_with_path
        app = OSA.app_with_path('/Applications/iTunes.app')
        assert_equal(@itunes, app)
        assert_raises(RuntimeError) { OSA.app_with_path('/Does/Not/Exist.app') }
    end
end
