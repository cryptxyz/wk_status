#!/usr/bin/env ruby
# frozen_string_literal: true

# <xbar.title>wk_status</xbar.title>
# <xbar.version>1.0</xbar.version>
# <xbar.author.github>cryptxyz</xbar.author.github>
# <xbar.desc>Shows due reviews and other useful info : )</xbar.desc>
# <xbar.dependencies>ruby</xbar.dependencies>
# <xbar.abouturl>https://github.com/cryptxyz/wk_status</xbar.abouturl>

# preferences
# <xbar.var>boolean(VAR_SHOW_STAGES=true): Show stages</xbar.var>
# <xbar.var>boolean(VAR_SHOW_LEVEL=true): Show level and total items</xbar.var>
# <xbar.var>boolean(VAR_SHOW_USER_INFO=true): Show user info</xbar.var>
# <xbar.var>string(VAR_API_TOKEN="api_token"): Your WaniKani API v2 Token</xbar.var>

require 'net/http'
require 'json'
require 'date'

WK = 'https://api.wanikani.com/v2/'

class WaniKani
  attr_accessor :reviews, :reviews_at, :lessons, :user, :subscription, :level, :max_level, :srs_stage, :assignments

  def initialize
    @assignments = []
    @study_materials = []
    @reviews = 0
    @srs_stage = [[], [], [], [], []]
    @progress = {}
  end

  def get_stage_index(srs_stage)
    case srs_stage
    when (1..4)
      0
    when (5..6)
      1
    else
      srs_stage - 5
    end
  end

  # getting stuff out of the fetch method so rubocop leaves me alone
  def add_level(srs_stage, id)
    raise 'unexpected srs_stage' if srs_stage.negative? || srs_stage > 9
    return if srs_stage.zero?

    stage = get_stage_index( srs_stage )
    return if @srs_stage[stage].include? id

    @srs_stage[stage] << id
  end

  # same rubocop stuff again
  def parse_user(user)
    @user = user['data']['username']
    @subscription = user['data']['subscription']['type'].to_s
    @level = user['data']['level']
    @max_level = user['data']['subscription']['max_level_granted']
  end

  def fetch
    if ENV['VAR_API_TOKEN'].nil? || (ENV['VAR_API_TOKEN'] == 'api_token') || (ENV['VAR_API_TOKEN'] == '')
      puts '!WK! | color=red'
      puts '---'
      puts 'Please set your WaniKani API token in the xbar application. | color=red'
      exit(0)
    end

    assignments = get_api("#{WK}assignments")
    loop do
      @assignments << assignments
      break if assignments['pages']['next_url'].nil?

      assignments = get_api(assignments['pages']['next_url'])
    end

    @assignments.each do |as|
      as['data'].each do |obj|
        add_level obj['data']['srs_stage'], obj['data']['subject_id']
      end
    end

    user = get_api("#{WK}user")

    parse_user user

    summary = get_api("#{WK}summary")

    reviews = summary['data']['reviews']

    reviews.each do |review|
      available_at = DateTime.parse review['available_at']
      @reviews += review['subject_ids'].size unless available_at >= DateTime.now
    end

    @lessons = summary['data']['lessons'][0]['subject_ids'].size
  end

  def get_api(str)
    wk = URI(str)

    Net::HTTP.start(wk.host, wk.port, use_ssl: true) do |https|
      req = Net::HTTP::Get.new wk
      req['Authorization'] = "Bearer #{ENV['VAR_API_TOKEN']}"
      res = https.request(req)
      unless res.is_a? Net::HTTPSuccess
        puts '!WK! | color=red'
        puts '---'
        case res
        when Net::HTTPUnauthorized
          puts "#{res.message}, please check your API token | color=red"
        when Net::HTTPServerError
          puts "#{res.message}, please try again later? | color=red"
        else
          puts res.message
        end
        exit(0)
      end
      wk = JSON.parse(res.body)
    end

    wk
  end
end

def print_stages(wk)
  return if ENV['VAR_SHOW_STAGES'].nil?
  return unless ENV['VAR_SHOW_STAGES'] == 'true'

  puts '---'
  puts "apprentice #{wk.srs_stage[0].size} | color=#dd0093"
  puts "guru #{wk.srs_stage[1].size} | color=#882d9e"
  puts "master #{wk.srs_stage[2].size} | color=#294ddb"
  puts "enlightened #{wk.srs_stage[3].size} | color=#0093dd"
  puts "burned #{wk.srs_stage[4].size} | color=#fbc042"
end

def print_user_info(wk)
  return if ENV['VAR_SHOW_USER_INFO'].nil?
  return unless ENV['VAR_SHOW_USER_INFO'] == 'true'

  puts '---'
  puts "username #{wk.user}"
  puts "subscription #{wk.subscription}"
end

def print_level(wk)
  return if ENV['VAR_SHOW_LEVEL'].nil?
  return unless ENV['VAR_SHOW_LEVEL'] == 'true'

  puts '---'
  learned = 0
  wk.srs_stage.each { |v| learned += v.size }
  puts "total items #{learned}/#{learned + wk.lessons}"
  puts "level #{wk.level}/#{wk.max_level}"
end

def main
  wk = WaniKani.new
  wk.fetch

  puts wk.reviews
  puts '---'
  puts "reviews #{wk.reviews} | href='https://wanikani.com/review/start' | key=shift+r"
  puts "lessons #{wk.lessons} | href='https://wanikani.com/lesson/start' | key=shift+l"
  print_stages wk
  print_level wk
  print_user_info wk
end

main