require 'discordrb'
require 'dotenv/load'
require 'httparty'
require 'json'
require 'async'
require 'date'

Dotenv.load

TOKEN = ENV['BOT_TOKEN']

bot = Discordrb::Commands::CommandBot.new(
  token: TOKEN,
  prefix: '!',
  intents: [:message_content]
)

class APISearch
  attr_reader :query, :mode

  def initialize(query, mode)
    @query = query
    @mode = mode
  end

  def select_options
    [
      { label: "ScriptBlox", value: "scriptblox", description: "Search scripts from ScriptBlox API" },
      { label: "Rscripts", value: "rscripts", description: "Search scripts from Rscripts API" }
    ]
  end

  def search_api(api, interaction)
    case api
    when "scriptblox"
      interaction.respond("Searching ScriptBlox API...")
      search_scriptblox(interaction)
    when "rscripts"
      interaction.respond("Searching Rscripts API...")
      search_rscripts(interaction)
    end
  end

  def search_scriptblox(interaction)
    page = 1
    api_url = "https://scriptblox.com/api/script/search?q=#{query}&mode=#{mode}&page=#{page}"
    response = HTTParty.get(api_url)

    if response.success?
      scripts = response['result']['scripts']
      if scripts.empty?
        interaction.respond("No scripts found for: `#{query}` in mode `#{mode}`.")
      else
        interaction.respond("Fetching data...")
        display_scripts(interaction, scripts, page, response['result']['totalPages'], 'scriptblox')
      end
    else
      interaction.respond("An error occurred: #{response.message}")
    end
  end

  def search_rscripts(interaction)
    page = 1
    not_paid = mode == 'paid' ? 'false' : 'true'
    api_url = "https://rscripts.net/api/scripts?q=#{query}&page=#{page}&notPaid=#{not_paid}"
    response = HTTParty.get(api_url)

    if response.success?
      scripts = response['scripts']
      if scripts.empty?
        interaction.respond("No scripts found for: `#{query}` in mode `#{mode}`.")
      else
        interaction.respond("Fetching data...")
        display_scripts(interaction, scripts, page, response['info']['maxPages'], 'rscripts')
      end
    else
      interaction.respond("An error occurred: #{response.message}")
    end
  end

  def display_scripts(interaction, scripts, page, total_pages, api)
    script = scripts[page - 1]
    embed = create_embed(script, page, total_pages, api)
    interaction.respond(embed: embed)
  end

  def create_embed(script, page, total_pages, api)
    Discordrb::Webhooks::Embed.new do |embed|
      if api == 'scriptblox'
        embed.title = "[SB] #{script['title']}"
        embed.add_field(name: "Game", value: "[#{script['game']['name']}](https://www.roblox.com/games/#{script['game']['gameId']})", inline: true)
        embed.add_field(name: "Verified", value: script['verified'] ? '✅ Verified' : '❌ Not Verified', inline: true)
        embed.add_field(name: "Script Type", value: script['scriptType'] == 'free' ? 'Free' : '💲 Paid', inline: true)
        embed.add_field(name: "Views", value: "👁️ #{script['views']}", inline: true)
      elsif api == 'rscripts'
        embed.title = "[RS] #{script['title']}"
        embed.add_field(name: "Views", value: script['views'].to_s, inline: true)
      end
    end
  end
end

bot.command(:search) do |event, query, mode = 'free'|
  if query
    search = APISearch.new(query, mode)
    search.search_api('scriptblox', event)
  else
    event.respond "Please provide a search query."
  end
end

bot.run
