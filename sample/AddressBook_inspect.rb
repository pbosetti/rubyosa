# Print all the contacts your Address Book contains.
# Thanks to Stefan Saasen.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

def print_person(pe)                 
  puts pe.name
  puts "\tE-Mail: " + pe.emails.map{|email| email.value}.join(", ") \
     unless pe.emails.size < 1   
  puts "\tAddresses: " + pe.addresses.map{|a| a.formatted_address}\
     .join(", ") unless pe.addresses.size < 1
end                          

ab = OSA.app('Address Book')
ab.people.each do |pe|
  print_person pe
end 
