# Release Police

This service can be used to periodically checks a list of repos and if the delta between the last commit on develop and master is too far apart, will make a pagerduty alert. We run it at Rainforest to make sure we don't have releases sitting around for long periods.

## Configuring

If running on Heroku, you'll need to set the environment variables listed in ``.env_sample``. You need a github key (that can read your repos), a pagerduty key, to set a time (we use 120, for 2 hours), plus a list of repo's to monitor.