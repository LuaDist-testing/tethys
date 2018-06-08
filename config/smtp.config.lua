--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- BASIC SETTINGS
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Where if Tethys installed (this should point to the directory containing tethys scripts)
-- In the example below the directory structure would be:
-- /usr/local/share/tethys/
-- |-- tethys
-- |   |-- core
-- |   |   |-- ...
-- |   |-- plugins
-- |   |   `-- ...
-- |   `-- ...
--
-- This is *NOT* needed if you installed using LuaRocks
tethys = "/opt/tethys2/"

-- Error and info logging, 0 = no logs at all, 1 = only errors, 2 = errors and infos, 3 = debug
log.level = 2

-- Maximun number of threads (lua coroutines) to use to answer smtp requests
-- Set to a number to use a limit, or nil to allow an unlimited number (dangerous)
max_threads = 300

-- Maximun time (in seconds) to keep a connection open
-- Set to a number to use a limit, or nil to allow an unlimited time
socket_timeout = 60

-- Number of simultaneous connections allowed for one source IP
-- Set to a number to use a limit, or nil to allow an unlimited time
max_connections_from_ip = 10

-- How to handle clients, either single process with lua threads(coroutine)
-- Or multi process (fork)
-- Set to either "coroutine" or "fork", leave as default if you do not know what it means
process_mode = "coroutine"

-- If set to false the processes will run in foreground in the terminal
daemon.daemonize = true
daemon.pid_file = "/var/run/tethys2-%s.pid"

-- Listen on which host/port (use 0.0.0.0 as host to listen on all interfaces)
bind.host = "0.0.0.0"
bind.port = 25
-- Which hostname to use for various replies(this should identify the mail server)
bind.reply_host = "mydomain.com"

-- Run the server as this user / group, this must be the ids, not the names
-- Uncommend those if you dont want your server to run as root(recommanded)
--bind.uid = 89
--bind.gid = 89

-- Max mail body size acceptable
max_data_size = 1024 * 1024 * 30 -- 30 MB

-- List of DISTANT ips that are allowed to relay mail without auth, if unsure leave it as the default
relay.allow_ip =
{
	["127.0.0.1"] = true,
}

-- Sender process keeps trying to send mails every 4 hours, 4 times
sender.retries = 4
sender.retries_time = 4 * 60 * 60

-- Who sends error messages for this server
mail_error.from = "postmaster@mydomain.com"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- DEPOSIT
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Which default deposit plugin to use, and its configuration
-- (note that deposit plugins can be set on a per user base if the users manager plugin allows it)
deposit.plugin = "tethys2.plugins.deposit.DiskSpool"
-- Which spool type(mailbox format) to use for the DiskSpool
deposit.spool_type = "tethys2.util.Maildir"
-- There all the mails will be stored in a tree like: $HOST/$ACCOUNT/.maildir/
deposit.spool_path = "/var/tethys/domains/"
-- Outgoing mails end up there while waiting for the sender process to send them
deposit.relay_maildir = "/var/tethys/relay-maildir/"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- FILTERS
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
filter.plugin = {
	"tethys2.plugins.filter.FixMail",
--	"tethys2.plugins.filter.SpamAssassin",
--	"tethys2.plugins.filter.MySQL",
}
-- Fix Mail
filter.fixmail.fix.date = true
filter.fixmail.fix.envelope = true

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- MISC PLUGINS STUFF
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
preload.plugins =
{
--        receiver = { "tethys2.plugins.user_manager.MySQL", },
}

---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- USER MANAGER PLUGIN (replace with others if you want)
---------------------------------------------------------------------------
---------------------------------------------------------------------------
user_manager.plugin = "tethys2.plugins.user_manager.UnixAlias"

-- List of hosts this server will handle mails for
user_manager.unixalias.hosts = {
        ["mydomain.com"] = true,
}
-- The unix alias file containing mail aliases
user_manager.unixalias.alias_file = "/etc/mail/aliases"
-- The unix passwd file containing the users
user_manager.unixalias.users_file = "/etc/passwd"

-- Default user account if the code returns an error, this allows to not lose the mail
user_manager.failsafe_user = { account="postmaster", host="mydomain.com", type="account" }
