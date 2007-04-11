# Creates a new Photoshop document with a given title and size.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

app = OSA.app('Adobe Photoshop CS2')
app.settings.ruler_units = OSA::AdobePhotoshopCS2::E440::PIXEL_UNITS

app.make(OSA::AdobePhotoshopCS2::Document, nil, :with_properties => {
	:name => 'Ruby Rocks',
  :width => 500,
  :height => 500
})
