# Copyright 2015 Alex Woroschilow (alex.woroschilow@gmail.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
import os
import strutils
import streams
import parseutils
import logging
import math

proc read(source: string): string =
  if existsFile(source):
    var stream = newFileStream(source, fmRead)
    var content = strip(stream.readAll())
    stream.close()
    return content
  return nil

proc write(source: string, value: string): void =
  if existsFile(source):
    var stream = newFileStream(source, fmWrite)
    stream.write(value)
    stream.close()
  return

proc ambientlight_get(path: string): float =
  var value: float = 100
  var maximum: float = 4095
  for kind, device in walkDir(path):
    var current = parseFloat(read("$#/in_illuminance_input" % [device]))
    var percent = current / maximum * 100
    if value > percent:
      value = percent
  return value

proc backlight_set(path: string, percent: int): void  =
    for kind, device in walkDir(path):
      var maximum = parseInt(read("$#/max_brightness" % [device]))
      var value = toint(maximum * percent / 100)
      write("$#/brightness" % [device], intToStr(value))
    return

proc backlight_get(path: string): float =
  var value: float = 0
  for kind, device in walkDir(path):
    var maximum = parseFloat(read("$#/max_brightness" % [device]))
    var current = parseFloat(read("$#/actual_brightness" % [device]))
    var percent = current / maximum * 100 # calcuate percentage of the brightness
    if 100 >= percent and percent > 0:
      if percent > value: value = percent
  return value


proc main(sensor_path: string, backlight_path: string)  =

  var timeout: int = 1000 # milliseconds
  var backlight_gobal: int = -1

  # default interval to keep the custom backlight settings
  # after the time is over, the backlight will be
  # adjusted to the ambient light automatically
  const interval_default: int = 300 # seconds

  var interval: int = interval_default

  if not dirExists(sensor_path):
    return

  while true:

    sleep(timeout)

    var backlight = backlight_get(backlight_path)
    var ambientlight = ambientlight_get(sensor_path)
    var difference_ba = abs(ambientlight - backlight)

    if backlight_gobal == -1: backlight_gobal = toInt(backlight)
    var difference_bb = abs(backlight_gobal - toInt(backlight))

    if difference_bb > 0 and interval >= 0:
      # if the ambient light has sudenly become to 100%
      # ignore the time interval and break the loop up
      if interval > 0 and ambientlight < 100:
        interval -= 1
        continue
      # if the ambient light has sudenly become to 100%
      # increase the backlight immediately
      if interval == 0 or ambientlight == 100:
        interval = interval_default

    if backlight == 0:
      # ignore everything if the backlight is off
      # it needs to be possible to turn the screen off
      continue

    if ambientlight == 100:
      # set backlight to 100% if there are a full sunlight
      backlight_gobal =  toInt(ambientlight)
      backlight_set(backlight_path, backlight_gobal)
      continue

    if ambientlight == 0 and difference_ba >= 10:
      backlight_gobal = toInt(backlight - (backlight / 5))
      # the 5% should be the minimal value
      # othervice the screen will be turnded off
      # automatically and this is not what we need
      if backlight_gobal < 5: backlight_gobal = 5
      backlight_set(backlight_path, backlight_gobal)
      continue

    if ambientlight > 0 and difference_ba >= 25:
      if backlight < ambientlight:
        backlight_gobal = toInt(ambientlight - ambientlight / 5)
        backlight_set(backlight_path, backlight_gobal)
        continue

      backlight_gobal = toInt(backlight - backlight / 3)
      if backlight_gobal < 5: backlight_gobal = 5
      backlight_set(backlight_path, backlight_gobal)
      continue


var backlight_path = "/sys/class/backlight"
var ambientlight_path = "/sys/bus/iio/devices"

main(ambientlight_path, backlight_path)
