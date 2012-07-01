#!/bin/sh

export PORT=7070
export HUBOT_IRC_SERVER='irc.freenode.net'
export HUBOT_IRC_ROOMS='#ehgtest'
export HUBOT_IRC_NICK='pearb0t'
export HUBOT_IRC_UNFLOOD=urgh

sh bin/hubot -a irc -n pearb0t
