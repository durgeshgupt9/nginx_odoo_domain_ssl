from odoo import models, fields, api
from odoo.http import request

class UserLoginLog(models.Model):
    _name = "user.login.log"
    _description = "User Login Log"
    _order = "login_time desc"

    user_id = fields.Many2one("res.users", string="User", readonly=True)
    ip_address = fields.Char(string="IP Address", readonly=True)
    user_agent = fields.Char(string="User Agent", readonly=True)
    login_time = fields.Datetime(string="Login Time", default=fields.Datetime.now, readonly=True)

    @api.model
    def create_log_entry(self, user):
        if not request:
            return
        self.create({
            "user_id": user.id,
            "ip_address": request.httprequest.remote_addr,
            "user_agent": request.httprequest.headers.get("User-Agent"),
        })
