-- This is the configurations for the SpamAssassin filter plugin
-- Append that to your config file if you need to use this plugin
filter.spamassassin.host = "localhost"
filter.spamassassin.port = 783

-- Also add the plugin to the list of filters in filter.plugin
-- I.E:
-- filter.plugin= {
--        "tethys2.plugins.filter.SpamAssassin",
--        "tethys2.plugins.filter.MySQL",
--}
