{
    --------------------------------------------
    Filename:
    Author:
    Copyright (c) 20__
    See end of file for terms of use.
    --------------------------------------------
}

CON

  _clkmode = cfg#_clkmode
  _xinfreq = cfg#_xinfreq

  TSL2591_LUX_DF  = 408

OBJ

  cfg   : "core.con.client.parraldev"
  ser   : "com.serial.terminal"
  int   : "string.integer"
  time  : "time"
  lux   : "sensor.lux.tsl2591"
  debug : "debug"
  math  : "math.float"
  fs    : "string.float"

VAR

  long _lux_cog
  long _ch0, _ch1
  long _fpscl
  long _cpl
  long _ga

PUB Main | it, g

  Setup
  lux.SetIntegrationTime (200)  ' 100-600ms (incr of 100)
  lux.SetGain (1)               ' 1, 25, 428, 9876
  waitkey
  ser.Clear

  _ga := 1                      ' Glass attenuation factor
  _fpscl := 1000                ' Fixed-point math scaler
  it := lux.IntegrationTime
  g := lux.Gain
  _cpl := it/g                  ' ADC Counts per Lux

  ser.Position (0, 0)
'                  0    5    10   15   20   25   30   35   40   45   50
'                  |    |    |    |    |    |    |    |....|....|....|
  ser.Str (string("Gain: xxxxx    Integration Time: xxxms    CPL: "))
  ser.Position (6, 0)
  ser.Str (int.DecPadded (g, 4))
  ser.Position (33, 0)
  ser.Dec (it)
  ser.Position (47, 0)
  ser.Dec (_cpl)

'  TestIntTime
'  TestInterrupts
'  TestPower
'  TestEnabled
'  TestGain
'  TestIntThresholds
  TestPersistence
  debug.here (17)

  repeat
    lux.ReadLightData
    repeat until lux.LastDataValid
    _ch0 := lux.FullSpec
    _ch1 := lux.IR
    ser.Position (0, 2)
    ser.Str (int.DecPadded (lux1, 8))

    ser.Position (0, 3)
    ser.Str (int.DecPadded (lux2, 8))
    ser.Position (10, 3)
    ser.Str (int.DecPadded (lux2/_fpscl, 5))
    ser.Position (15, 3)
    ser.Char (".")
    ser.Dec (lux2//_fpscl)
    ser.Char (" ")
    time.MSleep (100)

PUB lux2 | ATIME_us, AGAINx

  ATIME_us := lux.IntegrationTime * _fpscl
  AGAINx := lux.Gain

  return ((_fpscl * _ch0) - ((2 * _fpscl) * _ch1)) / ((ATIME_us * AGAINx) / (_ga * TSL2591_LUX_DF))

PUB lux1 | f, i, cor

  f := lux.FullSpec * _fpscl
  i := lux.IR * _fpscl
  cor := f-i
  cor /= _cpl

PUB TestPersistence | i, lt, ht, thr, pcy, r

  ser.Clear
  ser.Str (string("Testing persistence thresholds:", ser#NL))
  ser.Str (string("Setting all thresholds to 0, reading back: "))
  lux.SetPersistThresh (0, 0)
  thr := lux.GetPersistThresh
  lt := thr & $FFFF
  ht := (thr >> 16) & $FFFF
  ser.Str (string("Low: "))
  ser.Str (int.DecZeroed (lt, 5))
  ser.Str (string(" High: "))
  ser.Str (int.DecZeroed (ht, 5))
  if lt == 0 and ht == 0
    ser.Str (string(", PASSED", ser#NL))
  else
    ser.Str (string(", FAILED", ser#NL))

  ser.Str (string("Setting thresholds to Low: 1234, High: 5678, reading back: "))
  lux.SetPersistThresh (1234, 5678)
  thr := lux.GetPersistThresh
  lt := thr & $FFFF
  ht := (thr >> 16) & $FFFF
  ser.Str (string("Low: "))
  ser.Str (int.DecZeroed (lt, 5))
  ser.Str (string(" High: "))
  ser.Str (int.DecZeroed (ht, 5))
  if lt == 1234 and ht == 5678
    ser.Str (string(", PASSED", ser#NL))
  else
    ser.Str (string(", FAILED", ser#NL))

  repeat i from 0 to 15
    pcy := lookupz(i: 0, 1, 2, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60)
    ser.Str (string("Setting persist cycles to "))
    ser.Dec (pcy)
    lux.SetPersistence (pcy)
    time.MSleep (1)
    ser.Str (string(", reading back: "))
    ser.Dec (r := lux.GetPersistCycles)
    if r == pcy
      ser.Str (string(", PASSED", ser#NL))
    else
      ser.Str (string(", FAILED", ser#NL))

PUB TestIntThresholds | lt, ht, thr

  ser.Clear
  ser.Str (string("Testing interrupt thresholds:", ser#NL))
  ser.Str (string("Setting all thresholds to 0, reading back: "))
  lux.SetInterruptThresh (0, 0)
  thr := lux.GetIntThresh
  lt := thr & $FFFF
  ht := (thr >> 16) & $FFFF
  ser.Str (string("Low: "))
  ser.Str (int.DecZeroed (lt, 5))
  ser.Str (string(" High: "))
  ser.Str (int.DecZeroed (ht, 5))
  if lt == 0 and ht == 0
    ser.Str (string(", PASSED", ser#NL))
  else
    ser.Str (string(", FAILED", ser#NL))

  ser.Str (string("Setting thresholds to Low: 1234, High: 5678, reading back: "))
  lux.SetInterruptThresh (1234, 5678)
  thr := lux.GetIntThresh
  lt := thr & $FFFF
  ht := (thr >> 16) & $FFFF
  ser.Str (string("Low: "))
  ser.Str (int.DecZeroed (lt, 5))
  ser.Str (string(" High: "))
  ser.Str (int.DecZeroed (ht, 5))
  if lt == 1234 and ht == 5678
    ser.Str (string(", PASSED", ser#NL))
  else
    ser.Str (string(", FAILED", ser#NL))

PUB TestGain | i, glut, r 'XXX Test invalid value also?

  ser.Clear
  repeat i from 0 to 3
    glut := lookupz(i: 1, 25, 428, 9876)
    ser.Str (string("Testing gain value of "))
    ser.Dec (glut)
    lux.SetGain (glut)
    ser.Str (string(", readback: "))
    ser.Dec (r := lux.Gain)
    if r == glut
      ser.Str (string(", PASSED", ser#NL))
    else
      ser.Str (string(", FAILED", ser#NL))

PUB TestEnabled

  ser.Clear
  ser.Str (string("Testing ADCs enabled..."))
  lux.EnableSensor (TRUE)
  if lux.SensorEnabled
    ser.Str (string("PASSED", ser#NL))
  else
    ser.Str (string("FAILED", ser#NL))

  ser.Str (string("Testing ADCs disabled..."))
  lux.EnableSensor (FALSE)
  if lux.SensorEnabled
    ser.Str (string("FAILED", ser#NL))
  else
    ser.Str (string("PASSED", ser#NL))

PUB TestPower

  ser.Clear
  ser.Str (string("Testing power on..."))
  lux.PowerOn (TRUE)
  if lux.IsPowered
    ser.Str (string("PASSED", ser#NL))
  else
    ser.Str (string("FAILED", ser#NL))

  ser.Str (string("Testing power off..."))
  lux.PowerOn (FALSE)
  if lux.IsPowered
    ser.Str (string("FAILED", ser#NL))
  else
    ser.Str (string("PASSED", ser#NL))

PUB TestIntTime | i, r

  ser.Clear
  ser.Str (string("Testing setting of integration time:", ser#NL))

  repeat i from 100 to 600 step 100
    ser.Position (0, (i/100))
    ser.Str (string("Setting "))
    ser.Dec (i)
    lux.SetIntegrationTime (i)
    ser.Str (string(", read back: "))
    r := lux.IntegrationTime
    ser.Dec (r)
    if r == i
      ser.Str (string(", PASSED"))
    else
      ser.Str (string(", FAILED"))

PUB TestInterrupts | i, r 'XXX - More comprehensive?

  ser.Clear
  ser.Str (string("Disabling interrupts", ser#NL))
  lux.EnableInts (FALSE)
  ser.Str (string("Clearing interrupts", ser#NL))
  lux.ClearAllInts
  ser.NewLine

  ser.Str (string("Testing for triggered interrupts..."))
  if lux.IntTriggered
    r := (string("FAILED", ser#NL))
  else
    r := (string("PASSED", ser#NL))

  ser.Str (string("Forcing an interrupt", ser#NL))
  lux.ForceInt
  ser.Str (string("Testing for triggered interrupts..."))
  ser.Str (r)

  if lux.IntTriggered
    r := (string("PASSED", ser#NL))
  else
    r := (string("FAILED", ser#NL))
  
PUB Setup

  repeat until ser.Start (115_200)
  ser.Clear
  ser.Str (string("TSL2591 demo", ser#NL))

  math.Start
  fs.SetPrecision (3)
  ser.Str (string("F32 object started", ser#NL))

  _lux_cog := lux.Start-1
  ser.Str (string("tsl2591 object started...probing for sensor: "))

  if lux.Probe_TSL2591
    ser.Str (string("found!", ser#NL))
  else
    ser.Str (string("not found - halting!", ser#NL))
    lux.Stop
    ser.Stop
    repeat

  lux.PowerOn (TRUE)
  lux.EnableSensor (TRUE)

PUB waitkey

  ser.Str (string("Press any key", ser#NL))
  ser.CharIn

PUB waitmsg(msg_string)

  ser.Str (msg_string)
  ser.CharIn

DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
