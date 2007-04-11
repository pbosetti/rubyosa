# Creates a new Photoshop document with a given title and size, and adds a text
# layer on it.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

app = OSA.app('Adobe Photoshop CS2')
app.settings.ruler_units = OSA::AdobePhotoshopCS2::E440::PIXEL_UNITS
app.instance_eval do
  def create_document(options = {})
    make(OSA::AdobePhotoshopCS2::Document, nil, :with_properties => {
       :name => 'Ruby Rocks',
       :width => 500,
       :height => 500
     }.merge(options))
  end

  def add_layer(name, kind)
    kinds = %w(NORMAL GRADIENTFILL PATTERNFILL TEXT SOLIDFILL)
    do_javascript %(  
      var doc = app.activeDocument;
      var layer = doc.artLayers.add();
      layer.name = "#{name || ''}";
      layer.kind = LayerKind.#{kinds.detect {|k| k.downcase == kind} || 'NORMAL'};
      )
    current_document.art_layers[0]
  end
end

app.create_document(:name => 'Schweet')
layer = app.add_layer('A text layer', 'text')
texto  = layer.text_object
texto.size = 40
texto.contents = "This is some text"
