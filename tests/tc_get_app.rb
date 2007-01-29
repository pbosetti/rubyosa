require 'test/unit'
require 'rbosa'

class TC_GetApp < Test::Unit::TestCase
    def setup
        @itunes = OSA.app(:by_name => 'iTunes')
    end

    def test_by_name
        assert_equal('iTunes', @itunes.name)
        assert_raises(RuntimeError) { OSA.app(:by_name => 'SomethingThatDoesNotExist') }
    end

    def test_by_bundle_id
        app = OSA.app(:by_bundle_id => 'com.apple.iTunes')
        assert_equal(@itunes, app)
        assert_equal(@itunes.sdef, app.sdef)
        assert_raises(RuntimeError) { OSA.app(:by_bundle_id => 'com.apple.vaporware') }
    end
   
    def test_by_signature
        app = OSA.app(:by_signature => 'hook')
        assert_equal(@itunes, app)
        assert_equal(@itunes.sdef, app.sdef)
        assert_raises(RuntimeError) { OSA.app(:by_signature => 'XXXX') }
    end
    
    def test_by_path
        app = OSA.app(:by_path => '/Applications/iTunes.app')
        assert_equal(@itunes, app)
        assert_equal(@itunes.sdef, app.sdef)
        assert_raises(RuntimeError) { OSA.app(:by_path => '/Does/Not/Exist.app') }
    end

    def test_invalid_args
        assert_raises(ArgumentError) { OSA.app() }
        assert_raises(ArgumentError) { OSA.app(:foo => 123) }
        assert_raises(ArgumentError) { OSA.app(:by_name => 'iTunes', :foo => 123) }
    end
end
