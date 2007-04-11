Gem::Specification.new do |s|
    s.name = 'rubyosa'
    s.version = '0.4.0'
    s.date = '2007-04-11'
    s.summary = 'A Ruby/AppleEvent bridge.'
    s.email = 'lsansonetti@apple.com'
    s.homepage = 'http://rubyosa.rubyforge.org'
    s.rubyforge_project = 'rubyosa'
    s.description = "RubyOSA is a bridge that connects Ruby to the Apple Event Manager, automatically populating the API according to the target application's scriptable definition."
    s.has_rdoc = false
    s.authors = ['Laurent Sansonetti']
    s.files = ['README', 'COPYRIGHT', 'AUTHORS', 'extconf.rb', 'src/rbosa.c', 'src/rbosa.h', 'src/rbosa_conv.c', 'src/rbosa_sdef.c', 'src/rbosa_err.c', 'src/lib/rbosa.rb', 'src/lib/rbosa_properties.rb', 'sample/Finder/show_desktop.rb', 'sample/iChat/uptime.rb', 'sample/iTunes/control.rb', 'sample/iTunes/fade_volume.rb', 'sample/iTunes/inspect.rb', 'sample/QuickTime/play_all.rb', 'sample/misc/sdef.rb', 'sample/BBEdit/unix_script.rb', 'sample/TextEdit/hello_world.rb', 'sample/iChat/image.rb', 'sample/iTunes/artwork.rb', 'sample/Mail/get_selected_mail.rb', 'sample/AddressBook/inspect.rb', 'sample/iTunes/tag_genre_lastfm.rb', 'data/rubyosa/rdoc_html.rb', 'sample/Photoshop/new_doc.rb', 'sample/Photoshop/new_doc_with_text.rb', 'sample/iTunes/name_that_tune.rb']
    s.extensions = ['extconf.rb']
    s.executables = ['rdoc-osa']
    s.add_dependency('libxml-ruby', ['>= 0.3.8'])
end
