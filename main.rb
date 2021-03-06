require 'httparty'
require 'octokit'
require 'dotenv'
require 'pagerduty'
require 'awesome_print'
Dotenv.load

%w{GITHUB_TOKEN PAGERDUTY_SERVICE_KEY REPOS WARN_TIME_MINUTES}.each {|key| raise "Missing ENV #{key}" unless ENV.has_key?(key) }

github = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
pagerduty = Pagerduty.new(ENV['PAGERDUTY_SERVICE_KEY'])
repos = ENV['REPOS'].split(',')
warn_time = ENV['WARN_TIME_MINUTES'].to_i

def get_last(branch)
  branch['commit']['commit']['author']['date']
end

def incident_key(repo)
  "release-police-#{repo}"
end

def check_repo(github, pagerduty, repo, warn_time)
  develop = github.branch(repo, "develop")
  master = github.branch(repo, "master")

  master_last = get_last(master)
  develop_last = get_last(develop)

  if master_last > develop_last
    time_since_merge = ((develop_last - master_last) / 60).to_i
    puts "#{repo} ok, was released after #{time_since_merge.abs} minutes"
    incident = pagerduty.get_incident(incident_key(repo))
    incident.resolve unless incident.nil?
    return
  end

  # Time since last merged to develop
  time_since_merge = ((Time.now - develop_last) / 60).to_i

  if time_since_merge > warn_time
    puts "#{repo} bad! code is #{time_since_merge} minutes old and not released"
    pagerduty.trigger(
      "#{repo} has unreleased commits for #{time_since_merge} minutes",
      incident_key: incident_key(repo),
      contexts: [
        {
          'type': 'link',
          'text': 'Runbook',
          'href': 'https://github.com/rainforestapp/Rainforest/wiki/Release-Police:-XXX-has-unreleased-commits-for-YYY-minutes'
        }
      ]
    )
  end
end

puts "Checking: #{repos.join(", ")}"

repos.each do |repo|
  begin
    check_repo(github, pagerduty, repo, warn_time)
  rescue Octokit::NotFound => e
    puts "#{repo} -- could not find. #{e}"
  end
end
