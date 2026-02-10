###############################################################################
# How to use this file:
#
# This file contains examples for setting overrides for different purposes.
# Copy this file to personal.py in this directory and change your settings.
# If you add a new setting, consider updating this file with sample configurations.
###############################################################################

# -----------------------------------------------------------------------------
# Features
# -----------------------------------------------------------------------------

###
# Test locally in dev using the Chatitive / Essential production client. You will need to get credentials
# https://roverdotcom.atlassian.net/wiki/spaces/TECH/pages/716015781/Chatitive+Essential
#
# ESSENTIAL_CLIENT='production'
# ESSENTIAL_SID = '...'
# ESSENTIAL_TOKEN = '...'
###

###
# Enable initial review of messages using the misconduct tool
#
# ENABLE_MISCONDUCT_MESSAGE_REVIEW = True
###

###
# Test with the Zendesk sandbox by requesting access to the Zendesk sandbox in
#   ServiceNow, then uncomment the following setting
# https://roverdotcom.atlassian.net/wiki/spaces/TECH/pages/716736909/Zendesk+Rover#Zendesk@Rover-Testingwiththesandbox
#
# ZDESK_CLIENT = "common.zendesk.production.Zendesk"
###


# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------

###
# Override these in order to get rover_url_base() to return a URL of your choosing.
#   This is useful for setting up a tunnel with, e.g., forwardhq.com, ngrok.io, etc.
# https://roverdotcom.atlassian.net/wiki/spaces/TECH/pages/316899651/Forward+formerly+Showoff.io
#
# URI_SCHEME = 'https'
# URI_AUTHORITY = 'yoursubdomain.ngrok.io'
# URI_AUTHORITY_SHORT = URI_AUTHORITY
# ALLOWED_HOSTS.append(URI_AUTHORITY)
###


# -----------------------------------------------------------------------------
# Debugging & Profiling
# -----------------------------------------------------------------------------

###
# Change the panels in Django Debug Toolbar
# https://roverdotcom.atlassian.net/wiki/spaces/TECH/pages/398622822/Debugging+With+Django+Debug+Toolbar
# https://django-debug-toolbar.readthedocs.io/en/stable/panels.html#panels
#
# DEBUG_TOOLBAR_PANELS = [
#     'debug_toolbar.panels.versions.VersionsPanel',
#     '...',
# ]
###

###
# Force all Celery tasks to run asynchronously in worker containers rather than synchronously in the web container
# https://roverdotcom.atlassian.net/wiki/spaces/TECH/pages/838142896/Celery+Task+Best+Practices#CeleryTaskBestPractices-LocalDevelopment
#
# CELERY_TASK_ALWAYS_EAGER = False
###

###
# Send statsd (DataDog) metrics to the console
# https://roverdotcom.atlassian.net/wiki/spaces/TECH/pages/714573912/Introduction+to+Metrics+and+Instrumentation#IntroductiontoMetricsandInstrumentation-TestingMetricsinDevelopment
#
# ENABLE_STATSD_LOGGING = True
###

###
# Send statsd metrics to the Datadog dev organization
# https://roverdotcom.atlassian.net/wiki/spaces/TECH/pages/1120964125/Local+Development+of+Metrics+Dashboards+and+Monitors
#
# STATSD_CLIENT = 'systems.datadog.statsd.ThreadStatsD'
###

###
# Send slack messages to the console
#
# ENABLE_SLACK_LOGGING = True
###

###
# Avoid strange behavior due to replica lag when using the Production DB replica
# https://roverdotcom.atlassian.net/wiki/spaces/TECH/pages/395477248/The+Performance+Environment#ThePerformanceEnvironment-Overridedjangosettings
#
# REPLICA_DB_ALIAS = 'default'
###

###
# Send OpenTelemetry traces to the console
# https://docs.google.com/presentation/d/1sVkrDBRB3HecoUB2mvHeyOWmcUIALS3Q6_A5sDMseoA/edit#slide=id.g2676194d32b_0_121
#
# OTEL_EXPORTER = "console"
###

###
# Send OpenTelemetry traces to Jaeger
# https://roverdotcom.atlassian.net/wiki/x/swHd5Q
#
# OTEL_EXPORTER = "otlp"
# OTEL_EXPORTER_OTLP_ENDPOINT = "http://otel-collector:14318/v1/traces"
# HTTP endpoint (host port 14318 -> container port 4318)
# Or use gRPC endpoint: "http://otel-collector:14317"
# gRPC endpoint (host port 14317 -> container port 4317)
# ENABLE_QUERY_METRICS = True
# OTEL_DB_TRACING_ENABLED = True
###

###
# Enable dev tooling tracking debug mode. This will set a debug property on all events, which can be used to filter
# them out.
#
# DEV_TOOLING_TRACKING_DEBUG = True
###

# -----------------------------------------------------------------------------
# Stripe Integration Settings (Required for Payments Team)
# -----------------------------------------------------------------------------

# Enable Stripe integration client to make API calls to the Stripe test environment
# This is useful for testing checkout flows locally
# https://roverdotcom.atlassian.net/wiki/spaces/TECH/pages/647201928/Payments+Onboarding+Resources#Setup-and-Access
ENABLE_STRIPE_INTEGRATION_CLIENT = True

# Use Avalara sandbox client for tax calculations in development
AVALARA_CLIENT = "sandbox"
