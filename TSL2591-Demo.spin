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

  I2C_HZ    = 100_000

OBJ

  cfg   : "core.con.client.parraldev"
  ser   : "com.serial.terminal"
  time  : "time"
  lux   : "sensor.lux.tsl2591"
  debug : "debug"

VAR

  long _lux_cog
  long _als_data

PUB Main

  Setup
  ser.Str (string("Before:", ser#NL))
  ser.Hex (lux.GetState, 8)
  ser.NewLine
  ser.Hex (lux.GetNPIEN, 8)
  ser.NewLine
  ser.Hex (lux.GetSAI, 8)
  ser.NewLine
  ser.Hex (lux.GetAIEN, 8)
  ser.NewLine
  ser.Hex (lux.GetAEN, 8)
  ser.NewLine
  ser.Hex (lux.GetPON, 8)
  ser.NewLine

  lux.Enable (1, 1, 1, 1, 1)'NPIEN, SAI, AIEN, AEN, PON)

  ser.Str (string("After:", ser#NL))
  ser.Hex (lux.GetState, 8)
  ser.NewLine
  ser.Hex (lux.GetNPIEN, 8)
  ser.NewLine
  ser.Hex (lux.GetSAI, 8)
  ser.NewLine
  ser.Hex (lux.GetAIEN, 8)
  ser.NewLine
  ser.Hex (lux.GetAEN, 8)
  ser.NewLine
  ser.Hex (lux.GetPON, 8)
  ser.NewLine



  debug.here (16)

PUB Luminance_Loop
  repeat
    _als_data := lux.GetALS_Data
    ser.Str (string("Full luminance data: "))
    ser.Hex (_als_data, 8)
    ser.NewLine

    ser.Str (string("IR luminance data: "))
    ser.Hex (lux.GetIR, 4)
    ser.NewLine

    ser.Str (string("Visible luminance data: "))
    ser.Hex (lux.GetVisible, 4)
    ser.NewLine
  
    ser.NewLine
    time.MSleep (500)

PUB Setup | lux_found

  ser.Start (115_200)
  ser.Clear
  ser.Str (string("Started TSL2591 demo", ser#NL))

  _lux_cog := lux.Start (cfg#SCL, cfg#SDA, I2C_HZ)-1
  ser.Str (string("Started tsl2591 object", ser#NL))

  lux_found := lux.Find_TSL

  if lux_found
    ser.Str (string("TSL2591 found!", ser#NL))
  else
    ser.Str (string("TSL2591 not found - halting!", ser#NL))
    lux.Stop
    ser.Stop
    repeat

  lux.Enable (0, 0, 0, 1, 1)

  waitkey
{
  ser.Str (string("STATUS Register: $"))
  ser.Hex (lux.Status, 4)
  ser.NewLine
}
PUB waitkey

  ser.Str (string("Press any key", ser#NL))
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
