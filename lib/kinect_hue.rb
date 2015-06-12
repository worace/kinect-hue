require "json"
require "redis"
require "hue"
require "pry"

class KinectHue
  attr_reader :left_hand, :right_hand, :redis, :hue
  def initialize
    @redis = Redis.new
    @hue = Hue::Client.new
    @left_hand = {"skel" => "left_hand", "x" => 0.0, "y" => 0.0, "z" => 0.0}
    @right_hand = {"skel" => "right_hand", "x" => 0.0, "y" => 0.0, "z" => 0.0}
  end

  def position_updated(position)
    if position["skel"] == "left_hand" && moved?(position)
      # y ranges 0 - 480 (applet size currently; might switch this to overall size eventually)
      # hue ranges 0 - 64k; set hue to proportional value of left hand along x-y xcale
      new_hue = ((position["y"] / 480) * 65535) % 65535
      start = Time.now
      hue.lights.each { |l| l.set_state(hue: new_hue.to_i) }
      puts "set hue #{new_hue} in #{Time.now - start} seconds"
    end
  end

  def moved?(position)
    prev = instance_variable_get("@#{position["skel"]}")
    instance_variable_set("@#{position["skel"]}", position)
    #puts "position: #{position} vs prev: #{prev}"
    #puts "diff is #{(prev["y"] - position["y"]).abs}"
    (prev["y"] - position["y"]).abs > 20
  end

  def run
    received = 0
    puts "Subbing to redis channel"
    redis.subscribe("kinect") do |on|
      on.message do |channel, msg|
        position_updated(JSON.parse(msg))
      end
      received += 1
      puts "received: #{received}" if received % 50 == 0
    end
  end


  #client.lights.each { |l| l.set_state({hue: 40000}) }
  #client.lights.each { |l| l.set_state({brightness: 0}) }
end

if __FILE__ == $0
  KinectHue.new.run
end
