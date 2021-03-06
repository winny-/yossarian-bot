#  -*- coding: utf-8 -*-
#  channel_moderator.rb
#  Author: William Woodruff
#  ------------------------
#  A Cinch plugin that grabs moderates channels for yossarian-bot.
#  ------------------------
#  This code is licensed by William Woodruff under the MIT License.
#  http://opensource.org/licenses/MIT

require 'yaml'

require_relative '../yossarian_plugin'

class ChannelModerator < YossarianPlugin
	include Cinch::Plugin
	use_auth silent: false
	use_opped silent: false

	def initialize(*args)
		super
		@rules_file = File.expand_path(File.join(File.dirname(__FILE__), @bot.config.server, 'rules.yml'))
		@rules = Hash.new { |h, k| h[k] = [] }
		@warned = Hash.new { |h, k| h[k] = [] }
	end

	def sync_rules_file
		File.open(@rules_file, "w+") do |file|
			file.write @rules.to_yaml
		end
	end

	def usage
		'!moderator <commands> - Configure channel moderation (admin required). See !help for a link to moderator commands.'
	end

	def match?(cmd)
		cmd =~ /^(!)?moderator/
	end

	listen_to :connect, method: :initialize_rules

	def initialize_rules(m)
		if File.exist?(@rules_file)
			@rules = YAML::load_file(@rules_file)
			@rules.default_proc = Proc.new { |h, k| h[k] = [] }
		else
			FileUtils.mkdir_p File.dirname(@rules_file)
		end
	end

	match /moderator add \/(.+)\//, method: :moderator_add_rule, strip_colors: true

	def moderator_add_rule(m, regex)
		regex = Regexp.new(regex, Regexp::IGNORECASE)

		@rules[m.channel.to_s] << regex
		sync_rules_file

		m.reply "Added /#{regex}/ as a rule.", true
	end

	match /moderator del \/(.+)\//, method: :moderator_del_rule, strip_colors: true

	def moderator_del_rule(m, regex)
		regex = Regexp.new(regex, Regexp::IGNORECASE)

		if @rules[m.channel.to_s].include?(regex)
			@rules[m.channel.to_s].delete(regex)
			sync_rules_file

			m.reply "Deleted /#{regex}/ from the rules.", true
		else
			m.reply "No such rule to delete.", true
		end
	end

	match /moderator show/, method: :moderator_show_rules, strip_colors: true

	def moderator_show_rules(m)
		rules = @rules[m.channel.to_s].map { |r| "/#{r}/" }.join(', ')
		m.reply "Current channel rules: #{rules}"
	end

	listen_to :channel

	def listen(m)
		channel = m.channel.to_s

		if @rules.key?(channel) && Regexp.union(@rules[channel]).match(m.message) && @bot.admins.exclude?(m.user.nick)
			if @warned[channel].exclude?(m.user.nick)
				@warned[channel] << m.user.nick
				m.channel.kick m.user, "First rule violation."
			else
				@warned[channel].delete(m.user.nick)
				m.channel.ban m.user
				m.channel.kick m.user, "Second rule violation."
			end
		end
	end
end
