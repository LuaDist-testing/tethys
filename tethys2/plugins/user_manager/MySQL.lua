module(..., package.seeall)

local oo = require "loop.simple"
local Plugin = require 'tethys2.plugins.user_manager.Plugin'
local SQL = require('tethys2.util.SQL')
require'config'

new = oo.class({}, Plugin.class)
MySQL = new
class = new

MySQL.schemas =
{
	tAccount = [[
CREATE TABLE tAccount (
        acc_i_id        INT UNSIGNED NOT NULL auto_increment,
        acc_s_name      VARCHAR(64) NOT NULL,
        acc_s_host      VARCHAR(100) NOT NULL,
        acc_e_active    ENUM('yes', 'no') NOT NULL DEFAULT 'yes',
        acc_s_pass      VARCHAR(64),

        acc_e_type      ENUM('account', 'alias', 'deposit', 'forward') NOT NULL DEFAULT 'account',
        acc_s_param     TEXT,

        PRIMARY KEY (acc_i_id),
        UNIQUE KEY  (acc_s_name, acc_s_host)
);
	]],
	tHost = [[
CREATE TABLE tHost (
        hst_i_id        INT UNSIGNED NOT NULL AUTO_INCREMENT,

        hst_s_host      VARCHAR(100) NOT NULL,
        hst_e_default   ENUM('bounce','account') NOT NULL DEFAULT 'bounce',
        hst_s_account   VARCHAR(100),

        PRIMARY KEY     (hst_i_id),
        UNIQUE KEY      (hst_s_host)
);
	]],
}

function MySQL:getUser(account, host)
	local data = self.con:selectOneRow(string.format("SELECT acc_s_name AS account, acc_s_host AS host, acc_e_type AS type, acc_s_param AS param FROM tAccount WHERE acc_s_name=%s AND acc_s_host=%s AND acc_e_active='yes'", self.con:quote(account), self.con:quote(host)))
	-- No such account here, let's try for the host default account, if allowed
	if not data then
		data = self.con:selectOneRow(string.format("SELECT acc_s_name AS account, acc_s_host AS host, acc_e_type AS type, acc_s_param AS param FROM tHost INNER JOIN tAccount ON (acc_s_name=hst_s_account AND acc_s_host=hst_s_host) WHERE hst_e_default='account' AND hst_s_host=%s AND acc_e_active='yes'", self.con:quote(host)))
	end
	-- If no data yet use fallback account
	if not data then
		data = config.settings.user_manager.failsafe_user
	end
	return data
end

function MySQL:getRelayHost(host)
	local data = self.con:selectOneRow(string.format("SELECT hst_s_host AS host FROM tHost WHERE hst_s_host=%s", self.con:quote(host)))
	return data
end

function MySQL:authUser(account, host, pass)
	local row = self.con:selectOneRow(string.format("SELECT acc_e_type AS type FROM tAccount WHERE acc_s_name=%s AND acc_s_host=%s AND acc_s_pass=%s AND acc_e_type='account' AND acc_e_active='yes'", self.con:quote(account), self.con:quote(host), self.con:quote(pass)))
	if not row then return false end
	if row.type == "account" then return true end
end

function MySQL:init(server)
	oo.superclass(MySQL).init(self, server)
end

function MySQL:initPlugin(server)
	self.server = server
	self.con = SQL.new(config.settings.user_manager.mysql)

	local created = self.con:loadTables(self.schemas)
	if created.tHost then self.con:execute(("INSERT INTO tHost (hst_s_host,hst_e_default,hst_s_account) VALUES (%s,'bounce',NULL)"):format(self.con:quote(config.settings.bind.reply_host))) end
	if created.tAccount then self.con:execute(("INSERT INTO tAccount (acc_s_name,acc_s_host,acc_e_active,acc_s_pass,acc_e_type,acc_s_param) VALUES ('postmaster',%s,'yes',NULL,'account',NULL)"):format(self.con:quote(config.settings.bind.reply_host))) end
end
