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
  TSL2591_LUX_DF  = 408

OBJ

  cfg   : "core.con.client.parraldev"
  ser   : "com.serial.terminal"
  time  : "time"
  lux   : "sensor.lux.tsl2591"
  debug : "debug"
  math  : "math.float"
  fs    : "string.float"

VAR

  long _lux_cog
  long _als_data
  long ch0, ch1
  long scale

PUB Main

  Setup
  time.Sleep (1)
  ser.NewLine
{  TestENABLE_reg
  TestCONTROL_reg
  TestALSIntThresh_reg
  TestNPALSIntThresh_reg
  TestPERSIST_reg
  TestRO_regs
}
  waitmsg (string("Press any key to begin continuous read of sensor...", ser#NL))
  ser.Clear

  repeat
    Test_Luminance

PUB TestRO_regs | package_id, device_id, status_reg, als_data

  ser.Str (string("Package ($11) ID: "))
  ser.Hex (lux.GetPackageIDReg, 8)
  ser.NewLine

  ser.Str (string("Device ($12) ID: "))
  ser.Hex (lux.GetDeviceIDReg, 8)
  ser.NewLine

  ser.Str (string("Status ($13) reg: "))
  ser.Hex (lux.GetStatusReg, 8)
  ser.NewLine

  ser.Str (string("ALS Data ($14..$17): "))
  ser.Hex (lux.GetALSDataReg, 8)
  ser.NewLine

PUB TestPERSIST_reg | testval, readback

  testval := 3

  ser.Str (string("PERSIST ($0C) register readback test", ser#NL))
  ser.Str (string("Current settings:", ser#NL))
  ser.Hex (lux.GetPersistReg, 8)
  ser.NewLine

  ser.Str (string("About to set:", ser#NL))
  ser.Hex (testval, 8)
  ser.NewLine
  lux.SetPersistReg (testval)
  readback := lux.GetPersistReg

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
  ser.Hex (lux.GetNPALS_IntThreshReg, 8)
  ser.NewLine

  ser.Str (string("About to set: "))
  ser.Hex (testval, 8)
  ser.NewLine
  lux.SetNPALS_IntThreshReg (testval.word[0], testval.word[1])
  readback := lux.GetNPALS_IntThreshReg

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
  ser.Hex (lux.GetALS_IntThreshReg, 8)
  ser.NewLine

  ser.Str (string("About to set: "))
  ser.Hex (testval, 8)
  ser.NewLine
  lux.SetALS_IntThreshReg (testval.word[0], testval.word[1])
  readback := lux.GetALS_IntThreshReg

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
  lux.SetControlReg (0, %00, %000)
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

  lux.SetEnableReg (0, 0, 0, 1, 1)

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

PUB calc_f_Lux: f_lux | f_atime, f_again, f_df, f_ga, f_dgf, f_dim_incan, f_cpl, f_lux1, f_lux2, lux_tmp
{
From AMS DN28:
Data Sheet Lux Equation:

CPL = (ATIME_ms * AGAINx) / (GA * 53)
Lux1 = (C0DATA – 2 * C1DATA) / CPL
Lux2 = (0.6 * C0DATA − C1DATA) / CPL
Lux = MAX(Lux1, Lux2, 0)

Terms:
CPL = Counts Per Lux
GA = Glass Attenuation (Open Air = 1.0)
DF = Device Factor
DGF = GA * DF

}

  f_atime := 100.0
  f_again := 1.0
  f_df := 53.0
  f_ga := 1.0
  f_dgf := math.MulF (f_df, f_ga)
  f_dim_incan := 0.6

  f_cpl := math.DivF (math.MulF (f_atime, f_again), f_df)
  f_lux1 := math.DivF (math.SubF (ch0, math.MulF (2.0, ch1)), f_cpl)
  f_lux2 := math.DivF (math.SubF (math.MulF (f_dim_incan, ch0), ch1), f_cpl)
  lux_tmp := math.CmpF (f_lux1, f_lux2)
  case lux_tmp
    -1:
      return fs.FloatToString (f_lux2)
    0:
      return fs.FloatToString (f_lux1)
    1:
      return fs.FloatToString (f_lux1)
    OTHER:
      return 0

PUB Test_Luminance
  
  ser.Clear
  _als_data := lux.GetALSDataReg
  ch0 := math.FloatF (lux.GetALSData_Full)
  ch1 := math.FloatF (lux.GetALSData_IR)
  ser.Str (string("f_Lux: "))
  ser.Str (calc_f_Lux)
  ser.NewLine
  time.MSleep (120)


PUB Setup | lux_found

  ser.Start (115_200)
  ser.Clear
  ser.Str (string("Started TSL2591 demo", ser#NL))

  math.Start
  fs.SetPrecision (6)
  _lux_cog := lux.Start (cfg#SCL, cfg#SDA, I2C_HZ)-1
  ser.Str (string("Started tsl2591 object", ser#NL))

  lux_found := lux.Probe_TSL2591

  if lux_found
    ser.Str (string("TSL2591 found!", ser#NL))
  else
    ser.Str (string("TSL2591 not found - halting!", ser#NL))
    lux.Stop
    ser.Stop
    repeat

  lux.SetEnableReg (0, 0, 0, 1, 1)

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
