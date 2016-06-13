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

def check_repo(github, pagerduty, repo, warn_time)
  develop = github.branch(repo, "develop")
  master = github.branch(repo, "master")

  master_last = get_last(master)
  develop_last = get_last(develop)

  return if master_last > develop_last

  # Time since last merged to develop
  time_since_merge = ((Time.now - develop_last) / 60).to_i

  if time_since_merge > warn_time
    puts "#{repo} bad! code is #{time_since_merge} minutes old and not released."
    pagerduty.trigger("#{repo} has unreleased commits for #{time_since_merge} mintues.", incident_key: develop['commit']['sha'])
  else
    puts "#{repo} ok, was released after #{time_since_merge.abs} minutes"
  end
end

repos.each do |repo|
  begin
    check_repo(github, pagerduty, repo, warn_time)
  rescue Octokit::NotFound => e
    puts "#{repo} -- could not find. #{e}"
  end
end
