cron_job = (require 'cron').CronJob
_        = require 'underscore'

module.exports = (robot) ->
  cache = []
  cron_morning   = '00 00 12 * * 2-6'
  cron_afternoon = '*/1 * * * * *'
  cron_check_responses    = '*/1 * * * * *'
  cron_clear_cache   = '00 00 06 * * 2-6'

  robot.brain.on 'loaded', ->
    if robot.brain.data.pears
      cache = robot.brain.data.pears

  nagger = (time) ->
    for pair in cache
      if pair.time == time and not pair.asked_if_paired
        pairer = robot.userForName pair.pairer
        pairee = robot.userForName pair.pairee
        delete pairer.room
        delete pairee.room
        robot.send pairer, "you should've paired with #{pair.pairee} - did you?"
        robot.send pairee, "you should've paired with #{pair.pairer} - did you?"
        pair.asked_if_paired = true

  new cron_job
    cronTime: cron_morning
    onTick: ->
      nagger 'morning'
    start: true

  new cron_job
    cronTime: cron_afternoon
    onTick: ->
      nagger 'afternoon'
    start: true

  new cron_job
    cronTime: cron_clear_cache
    onTick: ->
      for pair in cache
        robot.messageRoom '#ehgtest', "#{pair.pairee} and #{pair.pairer} didn't pair last #{pair.time}, or didn't respond when i asked them >:("

      cache = []
    start: true

  robot.hear /^(yes|no)$/i, (msg) ->
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
          robot.messageRoom '#ehgtest', "#{pair.pairee} and #{pair.pairer} paired this #{pair.time} :D"
        else
          robot.messageRoom '#ehgtest', "#{pair.pairee} and #{pair.pairer} didn't pair this #{pair.time} :("
        cache = _.without cache, pair
      else
        robot.send user, "sorry, what?"

  robot.respond /pair with (\w+) this (morning|afternoon)/i, (msg) ->
    return unless msg.message.user.room
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
        robot.messageRoom '#ehgtest', "#{pairer.name} will pair with #{pairee.name} this #{time}"
      else
        other_person = pairee_paired.pairer if pairee_paired.pairee == pairee.name
        other_person = pairee_paired.pairee if pairee_paired.pairer == pairee.name
        robot.messageRoom '#ehgtest', "#{pairee.name} already pairing with #{other_person}"
    else
      robot.messageRoom '#ehgtest', "i don't know #{msg.match[1]}"

