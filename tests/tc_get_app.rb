require 'test/unit'
require 'rbosa'

class TC_GetApp < Test::Unit::TestCase
    def setup
        @itunes = OSA.app(:name => 'iTunes')
    end

    def test_by_name
        assert_equal('iTunes', @itunes.name)
        assert_equal('iTunes', OSA.app('iTunes', {}).name)
        assert_raises(RuntimeError) { OSA.app(:name => 'SomethingThatDoesNotExist') }
    end

    def test_by_bundle_id
        app = OSA.app(:bundle_id => 'com.apple.iTunes')
        assert_equal(@itunes, app)
        assert_equal(@itunes.sdef, app.sdef)
        assert_raises(RuntimeError) { OSA.app(:bundle_id => 'com.apple.vaporware') }
    end
   
    def test_by_signature
        app = OSA.app(:signature => 'hook')
        assert_equal(@itunes, app)
        assert_equal(@itunes.sdef, app.sdef)
        assert_raises(RuntimeError) { OSA.app(:signature => 'XXXX') }
    end
    
    def test_by_path
        app = OSA.app(:path => '/Applications/iTunes.app')
        assert_equal(@itunes, app)
        assert_equal(@itunes.sdef, app.sdef)
        assert_raises(RuntimeError) { OSA.app(:path => '/Does/Not/Exist.app') }
    end

    def test_invalid_args
        assert_raises(ArgumentError) { OSA.app() }
        assert_raises(ArgumentError) { OSA.app(:foo => 123) }
        assert_raises(ArgumentError) { OSA.app(:name => 'iTunes', :foo => 123) }
        assert_raises(ArgumentError) { OSA.app(1, 2, 3) }
        assert_raises(ArgumentError) { OSA.app(42, 42) }
        assert_raises(ArgumentError) { OSA.app('iTunes', 42) }
        assert_raises(ArgumentError) { OSA.app(42, {}) }
    end
end
