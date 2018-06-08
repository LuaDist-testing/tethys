-- This is the configurations for the MySQL user_manager plugin
-- Append that to your config file if you need to use this pluging
user_manager.plugin = "tethys2.plugins.user_manager.MySQL"
user_manager.mysql.host = "localhost"
user_manager.mysql.user = "tethys"
user_manager.mysql.pass = "mypassword"
user_manager.mysql.base = "tethys"
