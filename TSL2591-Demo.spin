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
  time.Sleep (1)
  ser.NewLine
  TestENABLE_reg
  TestCONTROL_reg
  TestALSIntThresh_reg
  TestNPALSIntThresh_reg
  TestPERSIST_reg
  TestRO_regs

  waitmsg (string("Press any key to begin continuous read of sensor...", ser#NL))
  ser.Clear

  repeat
    _als_data := lux.GetALS_Data
    ser.Str (string("IR light data: "))
    ser.hex (lux.GetIR, 4)
    ser.NewLine
    ser.Str (string("Visible light data: "))
    ser.hex (lux.GetVisible, 4)
    ser.NewLine
    time.MSleep (250)
    ser.NewLine

PUB TestRO_regs | package_id, device_id, status_reg, als_data

  ser.Str (string("Package ($11) ID: "))
  ser.Hex (lux.GetPackageID, 8)
  ser.NewLine

  ser.Str (string("Device ($12) ID: "))
  ser.Hex (lux.GetDeviceID, 8)
  ser.NewLine

  ser.Str (string("Status ($13) reg: "))
  ser.Hex (lux.Status, 8)
  ser.NewLine

  ser.Str (string("ALS Data ($14..$17): "))
  ser.Hex (lux.GetALS_Data, 8)
  ser.NewLine

PUB TestPERSIST_reg | testval, readback

  testval := 3

  ser.Str (string("PERSIST ($0C) register readback test", ser#NL))
  ser.Str (string("Current settings:", ser#NL))
  ser.Hex (lux.GetPersist, 8)
  ser.NewLine

  ser.Str (string("About to set:", ser#NL))
  ser.Hex (testval, 8)
  ser.NewLine
  lux.SetPersist (testval)
  readback := lux.GetPersist

  ser.Str (string("Readback:", ser#NL))
  ser.Hex (readback, 8)
  ser.NewLine

  if readback == testval
    ser.Str (string("*** PASSED ***", ser#NL))
  else
    ser.Str (STRING("*** FAILED ***", ser#NL))

PUB TestNPALSIntThresh_reg | testval, readback

  testval := $DEAD_FACE
  ser.Str (string("No-persist ALS Interrupt Threshold ($08..$0B) register readback test", ser#NL))
  ser.Str (string("Current settings: "))
  ser.Hex (lux.GetNPALS_IntThresh, 8)
  ser.NewLine

  ser.Str (string("About to set: "))
  ser.Hex (testval, 8)
  ser.NewLine
  lux.SetNPALS_IntThresh (testval.word[0], testval.word[1])
  readback := lux.GetNPALS_IntThresh

  ser.Str (string("Readback: "))
  ser.Hex (readback, 8)
  ser.NewLine

  if readback == testval
    ser.Str (string("*** PASSED ***", ser#NL))
  else
    ser.Str (STRING("*** FAILED ***", ser#NL))

PUB TestALSIntThresh_reg | testval, readback

  testval := $DEAD_BEEF
  ser.Str (string("ALS Interrupt Threshold ($04..$07) register readback test", ser#NL))
  ser.Str (string("Current settings: "))
  ser.Hex (lux.GetALS_IntThresh, 8)
  ser.NewLine

  ser.Str (string("About to set: "))
  ser.Hex (testval, 8)
  ser.NewLine
  lux.SetALS_IntThresh (testval.word[0], testval.word[1])
  readback := lux.GetALS_IntThresh

  ser.Str (string("Readback: "))
  ser.Hex (readback, 8)
  ser.NewLine

  if readback == testval
    ser.Str (string("*** PASSED ***", ser#NL))
  else
    ser.Str (STRING("*** FAILED ***", ser#NL))

PUB TestCONTROL_reg

  ser.Str (string("CONTROL ($01) register readback test", ser#NL))
  ser.Str (string("Current settings:", ser#NL))
  ser.Hex (lux.GetControlReg, 8)
  ser.NewLine
  lux.Control (0, %00, %101)
  ser.Str (string("Readback:", ser#NL))
  ser.Hex (lux.GetControlReg, 8)
  ser.NewLine

PUB TestENABLE_reg

  ser.Str (string("ENABLE ($00) register readback test", ser#NL))
  ser.Str (string("Current settings:", ser#NL))
  ser.Str (string("NPIEN: "))
  ser.Hex (lux.GetNPIEN, 2)'XXX
  ser.Str (string(" SAI: "))
  ser.Hex (lux.GetSAI, 2)'XXX
  ser.Str (string(" AIEN: "))
  ser.Hex (lux.GetAIEN, 2)'XXX
  ser.Str (string(" AEN: "))
  ser.Hex (lux.GetAEN, 2)'XXX
  ser.Str (string(" PON: "))
  ser.Hex (lux.GetPON, 2)'XXX
  ser.NewLine

  lux.Enable (0, 0, 0, 1, 1)

  ser.Str (string("Readback:", ser#NL))
  ser.Str (string("NPIEN: "))
  ser.Hex (lux.GetNPIEN, 2)'XXX
  ser.Str (string(" SAI: "))
  ser.Hex (lux.GetSAI, 2)'XXX
  ser.Str (string(" AIEN: "))
  ser.Hex (lux.GetAIEN, 2)'XXX
  ser.Str (string(" AEN: "))
  ser.Hex (lux.GetAEN, 2)'XXX
  ser.Str (string(" PON: "))
  ser.Hex (lux.GetPON, 2)'XXX
  ser.NewLine

PUB Test_Luminance

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
