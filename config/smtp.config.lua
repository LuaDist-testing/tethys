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
tethys = "/usr/local/share/tethys2/"

-- If set to false the processes will run in foreground in the terminal
daemon.daemonize = true
daemon.pid_file = "/var/run/tethys2-%s.pid"

-- Listen on which host/port (use 0.0.0.0 as host to listen on all interfaces)
bind.host = "localhost"
bind.port = 25
-- Which hostname to use for various replies(this should identify the mail server)
bind.reply_host = "net-core.org"

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

-- Which default deposit plugin to use, and its configuration
-- (note that deposit plugins can be set on a per user base if the users manager plugin allows it)
deposit.plugin = "tethys2.plugins.deposit.DiskSpool"
-- Which spool type(mailbox format) to use for the DiskSpool
deposit.spool_type = "tethys2.util.Maildir"
-- There all the mails will be stored in a tree like: $HOST/$ACCOUNT/.maildir/
deposit.spool_path = "/var/tethys/domains/"
-- Outgoing mails end up there while waiting for the sender process to send them
deposit.relay_maildir = "/var/tethys/relay-maildir/"

-- Sender process keeps trying to send mails every 4 hours, 4 times
sender.retries = 4
sender.retries_time = 4 * 60 * 60

-- Who sends error messages for this server
mail_error.from = "postmaster@net-core.org"


---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Do not forget to at least add a user_manager plugin (see other files)
-- in this directory
---------------------------------------------------------------------------
---------------------------------------------------------------------------
---------------------------------------------------------------------------
