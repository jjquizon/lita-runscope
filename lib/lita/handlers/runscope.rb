module Lita
  module Handlers
    require 'multi_json'
    require 'time'
    class Runscope < Handler
      route(/.+(test run \*FAILED\*.)+\s+/,
        :respond_to_error,
        command: false,
        help: { "...test run FAILED." => "Replies with '... needs your attention ...'" }
      )

      def respond_to_error(response)
        sender = response.user.name
        team = parse_team(response)
        list_of_team_members = contacts(team)
        if report_error?(team, sender)
          contact_team_members(list_of_team_members, response, team, sender)
        end
      end

      def report_error?(team, sender)
        return true unless File.exists?('log.txt')
        log_last_20 = File.readlines("log.txt").last(20).reverse

        last_error = log_last_20.select do |entry|
          json = MultiJson.load(entry)
          json["team"] == team && json["sender"] == sender
        end.first
        return true if last_error.nil?

        last_error = MultiJson.load(last_error)

        if last_error["team"] != team || last_error["sender"] != sender
          return false
        elsif Time.now - Time.parse(last_error["time"]) < 600
          return false
        else
          return true
        end
      end

      def parse_team(response)
        match_string = response.match_data.to_s
        team = /\w+(:)/.match(match_string).to_s
        team[0..-2]
      end

      def contacts(team)
        Contacts.all[team]
      end

      def get_user_ids
        http_response = http.get(
        "https://slack.com/api/users.list",
        token: ENV["BR_LITA_SLACK_TOKEN"]
        )

        data = MultiJson.load(http_response.body)
        data["members"].map do |member|
          {
            name: member["name"],
            id: member["id"]
          }
        end
      end

      def user_ids
        @user_ids ||= get_user_ids
      end

      # note: bots can't Direct message
      def contact_team_members(contact_list, response, team, sender)
        message_string = team + " needs your attention "
        contacts = contact_list.split(",")
        contacts.each do |contact|
          user = user_ids.find { |user| user[:name] == contact }
          message_string.concat(" <@#{user[:id]}>")
        end
        write_error_to_file(sender, team)
        response.reply(message_string)
      end

      def write_error_to_file(sender, team)
        data = {
          sender: sender,
          team: team,
          time: Time.now
        }
        json = MultiJson.dump(data)
        open('log.txt', 'a') { |f| f << json + "\n" }
      end

    end

    Lita.register_handler(Runscope)
  end
end
