# Description:
#  Track pair programming pairs
#
# Dependencies:
#   "underscore": "1.3.3"
#   "cron": "0.3.3"
#
# Configuration:
#
# Commands:
#   hubot pair with <user> this <morning|afternoon> [on <task>] - sets up a pair
#   hubot cancel pair with <user> this <morning|afternoon> - cancels a pair
#
# Author:
#   ehg

cron_job = (require 'cron').CronJob
_        = require 'underscore'

module.exports = (robot) ->
  cache = []
  cron_morning   = '00 00 12 * * 2-6'
  cron_afternoon = '00 30 16 * * 2-6'
  #cron_afternoon = '*/1 * * * * *'
  cron_clear_cache   = '00 00 06 * * 2-6'
  channel = '#ScraperWikians'

  robot.brain.on 'loaded', ->
    if robot.brain.data.pears
      cache = robot.brain.data.pears

  nagger = (time) ->
    for pair in cache
      if pair.time == time and not pair.asked_if_paired
        pairer = robot.userForName pair.pairer
        pairee = robot.userForName pair.pairee
        delete pairer.room and delete pairee.room
        robot.send pairer, "you should've paired with #{pair.pairee} this #{pair.time}#{pair.task} - did you?"
        robot.send pairee, "you should've paired with #{pair.pairer} this #{pair.time}#{pair.task} - did you?"
        pair.asked_if_paired = true

  slack_message = ->
    robot.messageRoom channel, "SLACK TIME!!!"
    
  new cron_job
    cronTime: cron_morning
    onTick: ->
      nagger 'morning'
    start: true

  new cron_job
    cronTime: cron_afternoon
    onTick: ->
      nagger 'afternoon'
      slack_message()
    start: true

  new cron_job
    cronTime: cron_clear_cache
    onTick: ->
      for pair in cache
        robot.messageRoom channel, "#{pair.pairee} and #{pair.pairer} didn't pair last #{pair.time}, or didn't respond when i asked them >:("

      cache = []
      robot.brain.data.pear = cache
    start: true

  robot.respond /(hello|hi|hey|ello)/i, (msg) ->
    user = msg.message.user
    console.log user
    robot.messageRoom channel, "HAI #{user.name.toUpperCase()}!!111 :D"

  # Ask the pair if they've actually paired
  #TODO: fork hubot-irc so we can use respond instead of hear
  robot.hear /(yes|no)$/i, (msg) ->
    user = msg.message.user
    response = msg.match[1].toLowerCase()
    unless user.room
      pair = _.find cache, (pair) ->
        (pair.pairer == user.name or pair.pairee == user.name) and pair.asked_if_paired
      if pair?
        robot.send user, "ok, thanks"
        #TODO: what if a pair is pairing both afternoon and morning
        #      which one gets deleted?
        if response == 'yes'
          robot.messageRoom channel, "#{pair.pairee} and #{pair.pairer} paired this #{pair.time} :D"
        else
          robot.messageRoom channel, "#{pair.pairee} and #{pair.pairer} didn't pair this #{pair.time} :("
        cache = _.without cache, pair
        robot.brain.data.pear = cache
      else
        robot.send user, "sorry, what?"

  # Start a pairing
  robot.respond /pair with (\w+) this (morning|afternoon)(?:on )?(.+)?/i, (msg) ->
    return unless msg.message.user.room
    task = msg.match[3]
    task = '' unless task?
    pairee = robot.userForName msg.match[1]
    time = msg.match[2]
    pairer = msg.message.user
    if pairee
      pairee_paired = _.find cache, (pair) ->
        (pair.pairer == pairer.name or pair.pairee == pairer.name) and pair.time == time
      unless pairee_paired?
        cache.push
          pairer: pairer.name
          pairee: pairee.name
          time: time
          task: task
        robot.messageRoom channel, "#{pairer.name} will pair with #{pairee.name} this #{time}#{task}"
        robot.brain.data.pear = cache
      else
        other_person = pairee_paired.pairer if pairee_paired.pairee == pairee.name
        other_person = pairee_paired.pairee if pairee_paired.pairer == pairee.name
        robot.messageRoom channel, "#{pairee.name} already pairing with #{other_person}#{task}"
    else
      robot.messageRoom channel, "i don't know #{msg.match[1]}"

  # Cancel a pairing
  robot.respond /cancel pair with (\w+) this (morning|afternoon)$/i, (msg) ->
    return unless msg.message.user.room

    pairee = robot.userForName msg.match[1]
    time = msg.match[2]
    pairer = msg.message.user

    if pairee
      pair = _.find cache, (p) ->
        ((p.pairer is pairer.name and p.pairee is pairee.name) or (p.pairee is pairer.name and p.pairer is pairee.name)) and p.time is time
      if pair?
        robot.messageRoom channel, "ok, pair cancelled"
        cache = _.without cache, pair
        robot.brain.data.pear = cache
      else
        robot.messageRoom channel, "i have no record of that pairing"
    else
      robot.messageRoom channel, "i don't know #{msg.match[1]}"

