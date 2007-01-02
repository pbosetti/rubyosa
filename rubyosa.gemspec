Gem::Specification.new do |s|
    s.name = 'rubyosa'
    s.version = '0.2.0'
    s.date = '2007-01-02'
    s.summary = 'A Ruby/AppleEvent bridge.'
    s.email = 'lsansonetti@apple.com'
    s.homepage = 'http://rubyosa.rubyforge.org'
    s.rubyforge_project = 'rubyosa'
    s.description = "RubyOSA is a bridge that connects Ruby to the Apple Event Manager, automatically populating the API according to the target application's scriptable definition."
    s.has_rdoc = false
    s.authors = ['Laurent Sansonetti']
    s.files = ['README', 'COPYRIGHT', 'AUTHORS', 'extconf.rb', 'src/rbosa.c', 'src/rbosa.h', 'src/rbosa_conv.c', 'src/rbosa_sdef.c', 'src/lib/rbosa.rb', 'sample/Finder_show_desktop.rb', 'sample/iChat_uptime.rb', 'sample/iTunes_control.rb', 'sample/iTunes_fade_volume.rb', 'sample/iTunes_inspect.rb', 'sample/QT_playall.rb', 'sample/sdef.rb', 'sample/BBEdit_unix_script.rb', 'sample/TextEdit_hello_world.rb', 'sample/iChat_image.rb', 'sample/iTunes_artwork.rb']
    s.extensions = ['extconf.rb']
    s.executables = ['rdoc-osa']
    s.add_dependency('libxml-ruby', ['>= 0.3.8'])
end
