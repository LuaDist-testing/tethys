-- This is the configurations for the UnixAlias user_manager plugin
-- Append that to your config file if you need to use this plugin
user_manager.plugin = "tethys2.plugins.user_manager.UnixAlias"

-- List of hosts this server will handle mails for
user_manager.unixalias.hosts = {
        ["foo.org"] = true,
        ["bar.com"] = true,
}
-- The unix alias file containing mail aliases
user_manager.unixalias.alias_file = "/etc/mail/aliases"
-- The unix passwd file containing the users
user_manager.unixalias.users_file = "/etc/passwd"
