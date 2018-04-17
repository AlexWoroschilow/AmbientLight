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

proc ambientlight_get(path: string): int =
  var value: int = 100
  var maximum: int = 4095
  for kind, device in walkDir(path):
    var current = parseInt(read("$#/in_illuminance_input" % [device]))
    var percent = toInt(current / maximum * 100)
    if value > percent:
      value = percent
  return value

proc backlight_set(path: string, percent: int): void  =
    for kind, device in walkDir(path):
      var maximum = parseInt(read("$#/max_brightness" % [device]))
      var value = toint(maximum * percent / 100)
      write("$#/brightness" % [device], intToStr(value))
    return

proc main(sensor_path: string, backlight_path: string)  =

  if not dirExists(sensor_path):
    return

  while true:
    var ambientlight = ambientlight_get(sensor_path)

    if ambientlight <  5: ambientlight = 5
    backlight_set(backlight_path, ambientlight)

    sleep(1500)

var backlight_path = "/sys/class/backlight"
var ambientlight_path = "/sys/bus/iio/devices"

main(ambientlight_path, backlight_path)
