{
    --------------------------------------------
    Filename: TSL2591-Demo.spin
    Description: Demo for the TSL2591 driver
    Author: Jesse Burt
    Copyright (c) 2018
    Started Feb 17, 2018
    Updated Feb 24, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

  _clkmode = cfg#_clkmode
  _xinfreq = cfg#_xinfreq

  TSL2591_LUX_DF  = 408

OBJ

  cfg   : "core.con.boardcfg.flip"
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

PUB Main | it, g, i, r

  Setup
  ser.NewLine
  ser.Str (string("IsPowered: "))
  ser.Hex (lux.IsPowered, 8)
  ser.NewLine
  ser.Str (string("SensorEnabled: "))
  ser.Hex (lux.SensorEnabled, 8)
  ser.NewLine
  lux.Reset
  lux.SetGain (1)               ' 1, 25, 428, 9876
  lux.SetIntegrationTime (200)
  lux.PowerOn (TRUE)
  lux.EnableSensor (TRUE)
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

'  debug.here (17)

  repeat
'    lux.ReadLightData
    repeat until lux.MeasurementComplete
    _ch0 := lux.Luminosity (2)
    _ch1 := lux.Luminosity (1)
    ser.Position (0, 2)
    ser.Hex (_ch0, 4)
    ser.Position (0, 3)
    ser.Hex (_ch1, 4)
    
{    ser.Str (int.DecPadded (lux1, 8))

    ser.Position (0, 3)
    ser.Str (int.DecPadded (lux2, 8))
    ser.Position (10, 3)
    ser.Str (int.DecPadded (lux2/_fpscl, 5))
    ser.Position (15, 3)
    ser.Char (".")
    ser.Dec (lux2//_fpscl)
    ser.Char (" ")}
    time.MSleep (100)

PUB lux2 | ATIME_us, AGAINx

  ATIME_us := lux.IntegrationTime * _fpscl
  AGAINx := lux.Gain

  return ((_fpscl * _ch0) - ((2 * _fpscl) * _ch1)) / ((ATIME_us * AGAINx) / (_ga * TSL2591_LUX_DF))

PUB lux1 | f, i, cor

  f := lux.Luminosity (0) * _fpscl
  i := lux.Luminosity (1) * _fpscl
  cor := f-i
  cor /= _cpl

PUB Setup

  repeat until ser.Start (115_200)
  ser.Clear
  ser.Str (string("TSL2591 demo", ser#NL))

  math.Start
  fs.SetPrecision (3)
  ser.Str (string("F32 object started", ser#NL))

  _lux_cog := lux.Start-1
  ser.Str (string("tsl2591 object started on cog "))
  ser.Dec (_lux_cog)
  ser.Str (string(", probing for sensor..."))

  if \lux.DeviceID == $50
    ser.Str (string("found!", ser#NL))
  else
    ser.Str (string("not found - halting!", ser#NL))
    time.MSleep (500)
    lux.Stop
    ser.Stop
    repeat


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
