# Print all the contacts your Address Book contains.
# Thanks to Stefan Saasen.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

OSA.utf8_strings = true

def print_person(pe)                 
  puts pe.name
  unless pe.emails.size < 1
    puts "\tE-Mail: " + pe.emails.map { |email| 
      email.value 
    }.join(', ')
  end
  formatted_addresses = pe.addresses.map { |a|
    # Some malformed addresses can't be formatted and the address book
    # will therefore return an application-level error, that we handle there.
    ('(' + a.label + ') ' + a.formatted_address rescue nil)
  }.compact.map { |a|
    "\t\t" + a.gsub(/\n/, ' ').strip.squeeze(' ')
  }
  unless formatted_addresses.size < 1
    puts "\tAddresses:\n" + formatted_addresses.join("\n")
  end
end                          

ab = OSA.app('Address Book')
ab.people.each do |pe|
  print_person pe
end 
