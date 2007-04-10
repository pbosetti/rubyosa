# Plays a track of your iTunes library at random and asks you to guess the name of the track.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

OSA.app('iTunes') # initialize the constants

class OSA::ITunes::Application
  
  def library_source
    sources.find {|s| s.kind == OSA::ITunes::ESRC::LIBRARY }
  end
  
  def library
    library_source.playlists.find {|p| p.name == 'Library' }
  end
  
  def party_shuffle
    library_source.playlists.find {|p| p.special_kind == OSA::ITunes::ESPK::PARTY_SHUFFLE }
  end

end

class OSA::ITunes::Playlist
  
  def random_track
    tracks[rand * tracks.size]
  end
  
end

class OSA::ITunes::Track

  def to_s
    "#{artist} - #{name}"
  end

end


class NameThatTune
  attr_accessor :score
  
  def initialize
    @itunes = OSA.app('iTunes')
  end

  def finish
    puts "Thanks for playing! Score: #{score}"
    exit
  end

  def start
    @score = 0
    while true
      @itunes.party_shuffle.play
      @itunes.next_track
  
      options = generate_options
      options.each_with_index { |track, i| puts "#{i+1} - #{track}" }

      selected = gets.to_i
  
      finish if selected == 0
  
      if correct?(options, selected)
        points = calculate_points_for_correct_choice
        puts "Correct! #{points} points"
        self.score += points
      else
        puts "Sorry! That was #{@itunes.current_track}"
      end
    end
  end
  
  private
  
  def correct?(options, selected)
    options[selected-1] == @itunes.current_track
  end
  
  def calculate_points_for_correct_choice
    points = (@itunes.player_position > 10 ? 1 : 10 - @itunes.player_position) * 1000
    points += (@itunes.current_track.played_count > 10 ? 1 : 10 - @itunes.current_track.played_count) * 100
    points.to_i
  end
  
  def generate_options(count = 5)
    options = []
    options << @itunes.current_track
    (count - 1).times {|i| options << @itunes.library.random_track }
    options = options.sort_by { rand }
  end
  
end

NameThatTune.new.start
