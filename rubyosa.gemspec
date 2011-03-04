Gem::Specification.new do |s|
    s.name = 'rubyosa19'
    s.version = '0.5.4'
    s.date = '2011-03-03'
    s.summary = 'A Ruby/AppleEvent bridge.'
    s.email = 'p4010@me.com'
    s.homepage = 'http://github.com/pbosetti/rubyosa'
    s.rubyforge_project = 'rubyosa'
    s.description = "RubyOSA is a bridge that connects Ruby to the Apple Event Manager, automatically populating the API according to the target application's scriptable definition. This version is 1.9.2 compatible!"
    s.has_rdoc = false
    s.authors = ['Laurent Sansonetti', 'Paolo Bosetti (adapting for 1.9)']
    s.files = ['README.markdown', 'COPYRIGHT', 'AUTHORS', 'extconf.rb', 'src/rbosa.c', 'src/rbosa.h', 'src/rbosa_conv.c', 'src/rbosa_sdef.c', 'src/rbosa_err.c', 'src/lib/rbosa.rb', 'src/lib/rbosa_properties.rb', 'sample/Finder/show_desktop.rb', 'sample/iChat/uptime.rb', 'sample/iTunes/control.rb', 'sample/iTunes/fade_volume.rb', 'sample/iTunes/inspect.rb', 'sample/QuickTime/play_all.rb', 'sample/misc/sdef.rb', 'sample/BBEdit/unix_script.rb', 'sample/TextEdit/hello_world.rb', 'sample/iChat/image.rb', 'sample/iTunes/artwork.rb', 'sample/Mail/get_selected_mail.rb', 'sample/AddressBook/inspect.rb', 'sample/iTunes/tag_genre_lastfm.rb', 'data/rubyosa/rdoc_html.rb', 'sample/Photoshop/new_doc.rb', 'sample/Photoshop/new_doc_with_text.rb', 'sample/iTunes/name_that_tune.rb']
    s.extensions = ['extconf.rb']
    s.executables = ['rdoc-osa']
    s.add_dependency('libxml-ruby', ['>= 1.1.3'])
end
