{
    --------------------------------------------
    Filename: sensor.lux.tsl2591.spin
    Description: Driver for the TSL2591 I2C Light/lux sensor
    Author: Jesse Burt
    Copyright (c) 2018
    Started Feb 17, 2018
    Updated Feb 24, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

  W                 = %0
  R                 = %1
  
  LSB               = 0
  SCL               = 28
  SDA               = 29
  HZ                = tsl2591#I2C_MAX_RATE

  #0, GAIN_LOW, GAIN_MED, GAIN_HI, GAIN_MAX             ' Symbolic names for Gain settings
  #0, FULL, IR, VISIBLE, BOTH                           ' Sensor channel to read

OBJ

  i2c     : "jm_i2c_fast"
  tsl2591 : "core.con.tsl2591"

PUB Null
' This is not a top-level object

PUB Start: okay                                         ' Default to "standard" Propeller I2C pins and 400kHz

  okay := Startx (SCL, SDA, HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ)

  if lookdown(SCL_PIN: 0..31)                           ' Validate pins
    if lookdown(SDA_PIN: 0..31)
      if SCL_PIN <> SDA_PIN
        if I2C_HZ =< HZ
          return i2c.setupx (SCL_PIN, SDA_PIN, I2C_HZ)  ' Start I2C object, return cog num + 1
        else
          return FALSE
      else
        return FALSE
    else
      return FALSE
  else
    return FALSE

PUB Stop
' Kills I2C cog
  i2c.terminate

PUB ClearAllInts
' Clears both ALS (persistent) and NPALS (non-persistent) Interrupts
  specFunc (tsl2591#SPECFUNC_CLEARALS_NOPERSIST_INT)

PUB ClearInt
' Clears NPALS Interrupt
  specFunc (tsl2591#SPECFUNC_CLEAR_NOPERSIST_INT)

PUB ClearPersistInt
' Clears ALS Interrupt
  specFunc (tsl2591#SPECFUNC_CLEARALSINT)

PUB DeviceID: device_id
' Returns contents of Device ID register ($12)
' Should return $50
  device_id := readReg1 (tsl2591#REG_ID) & $FF

PUB EnableInts(enabled)
' TRUE or 1 enables, FALSE or 0 disables (no-persist) Interrupts
  case ||enabled
    0, 1: enabled &= %1
    OTHER: return

  pokeReg_ENABLE ( tsl2591#NPIEN, enabled)

PUB EnablePersist(enabled)
' TRUE or 1 enables, FALSE or 0 disables (persistent) Interrupts
  case ||enabled
    0, 1: enabled &= %1
    OTHER: return

  pokeReg_ENABLE (tsl2591#AIEN, enabled)

PUB EnableSensor(enabled)
' Enable sensor's internal ADCs
' TRUE or 1 activates ADCs
' FALSE or 0 disables the ADCs
  case ||enabled
    0, 1: enabled &= %1
    OTHER: return

  pokeReg_ENABLE (tsl2591#AEN, enabled)

PUB ForceInt
' Force an ALS Interrupt
' NOTE: Per TLS2591 Datasheet, for an interrupt to be visible on the INT pin,
'  one of the interrupt enable bits in the ENABLE ($00) register must be set.
'  i.e., make sure you've called EnableInts(TRUE) or EnablePersist (TRUE)
  specFunc (tsl2591#SPECFUNC_FORCEINT)

PUB Gain
' Returns in the current gain setting (multiplier/factor)
  return lookupz(readReg1 (tsl2591#REG_CONTROL) >> tsl2591#AGAIN: 1, 25, 428, 9876)

PUB GetIntThresh
' Gets no-persist ALS threshold values currently set
' Bits 31..16: NPAIHTH_NPAIHTL - High threshold word
'      15..0: NPAILTH_NPAILTL - Low threshold word
  return readReg4 (tsl2591#REG_NPAILTL)

PUB IntegrationTime | tmp
' Returns ADC Integration time (both channels)
' Queries CONTROL Register and returns ADC Integration time in milliseconds
  return lookupz( (readReg1 (tsl2591#REG_CONTROL) >> tsl2591#ATIME) & tsl2591#ATIME_MASK: 100, 200, 300, 400, 500, 600)

PUB IntsEnabled
' Returns whether or not (no-persist) interrupts have been enabled
  return ((readReg1 (tsl2591#REG_ENABLE) >> tsl2591#NPIEN) & %1) * TRUE

PUB IntTriggered
' Indicates if a no-persist interrupt has been triggered
  return ((readReg1 (tsl2591#REG_STATUS) >> tsl2591#NPINTR) & %1) * TRUE

PUB IsPowered
' Indicates if the sensor is powered on
  return ((readReg1 (tsl2591#REG_ENABLE) >> tsl2591#PON) & %1) * TRUE

PUB Luminosity(channel) | tmp
' Get luminosity data from sensor
' %00 - Full spectrum
' %01 - IR
' %10 - Visible
' %11 - Both (see comments for case %11)
  case channel
    %00:
      tmp := 0
      tmp := readReg2 (tsl2591#REG_C0DATAL)
      return tmp
    ' Reads ALS data from channel 0 (Full spectrum)

    %01:
      return readReg2 (tsl2591#REG_C1DATAL)
    ' Reads ALS data from channel 1 (IR)
    
    %10:
      tmp := readReg4 (tsl2591#REG_C0DATAL)
      return tmp.word[0] - tmp.word[1]
    ' Reads ALS data from both channels (returns Visible only)

    %11:
      return readReg4 (tsl2591#REG_C0DATAL)

    ' Reads ALS data from both channels (returns both channels)
    ' Bits 31..16/Most-significant word contain the IR data
    ' Bits 15..0/Least-significant word contain the Full-spectrum light data
    
    OTHER: return

PUB MeasurementComplete
' Is ALS data valid?
' Indicates ADCs completed integration cycle since AEN bit was set
  return ((readReg1 (tsl2591#REG_STATUS) >> tsl2591#AVALID) & %1) * TRUE

PUB PackageID
' Returns Package ID register ($11)
' Should always return $00
' Bits 7..6: Reserved (should be 0)
'      5..4: Package ID (%00)
'      3..0: Reserved (should be 0)
  return ((readReg1 (tsl2591#PID) >> tsl2591#PID) & tsl2591#PID_MASK)

PUB PersistCycles | tmp
' Returns Interrupt persistence filter value
' Queries the PERSIST register and returns the number of consecutive cycles necessary to generate an interrupt
  return lookupz(readReg1 (tsl2591#REG_PERSIST) & tsl2591#APERS_MASK: 0, 1, 2, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60)

PUB PersistEnabled
' Indicates if Persistent interrupts are enabled
  return ((readReg1 (tsl2591#REG_ENABLE) >> tsl2591#AIEN) & %1) * TRUE

PUB PersistIntTriggered
' Indicates if a persistent interrupt has been triggered
  return ((readReg1 (tsl2591#REG_STATUS) >> tsl2591#AINT) & %1) * TRUE

PUB PersistThresh: threshold
' Gets ALS threshold values currently set
' Bits 31..16: AIHTH_AIHTL - High threshold word
'      15..0: AILTH_AILTL - Low threshold word
  return readReg4 (tsl2591#REG_AILTL)

PUB PowerOn(power) | npien, sai, aien, aen
' Power ON
'  1 or TRUE activates the sensor's internal oscillator
'  0 or FALSE disables the oscillator/powers down
'  anything else is ignored
  case ||power
    0, 1: power &= %1
    OTHER: return

  pokeReg_ENABLE (tsl2591#PON, power)

PUB Reset
' Resets the TSL2591
' Sets SRESET/System Reset field in CONTROL register. Equivalent to Power-On Reset
' Field is self-clearing (i.e., once reset, it will be set back to 0)
  pokeReg_CONTROL (tsl2591#SRESET, 1)

PUB SetGain(gain_mult)
' Sets amplifier gain (affects both channels) 
' * 1x
'   25x
'   428x
'   9876x
  ifnot lookdown(gain_mult: 1, 25, 428, 9876)
    return $DEADBEEF

  pokeReg_CONTROL (tsl2591#AGAIN, lookdownz(gain_mult: 1, 25, 428, 9876))

PUB SetIntegrationTime(ms)
' Set the ADC Integration Time, in ms
' Time  Value Written   Max ADC count
' 100ms %000            37888
' 200ms %001            65535
' 300ms %010            65535
' 400ms %011            65535
' 500ms %100            65535
' 600ms %101            65535
  ifnot lookdown(ms: 100, 200, 300, 400, 500, 600)
    return $DEADBEEF

  writeReg1 (tsl2591#REG_CONTROL, lookdownz(ms: 100, 200, 300, 400, 500, 600))

PUB SetInterruptThresh(low_threshold, high_threshold) | npals_long
' Sets trigger threshold values for no-persist ALS interrupts (registers $08..$0B)
  if low_threshold < 0 or low_threshold > 65535 or high_threshold < 0 or high_threshold > 65535
    return

  writeReg4 (tsl2591#REG_NPAILTL, (high_threshold << 16) | low_threshold)

PUB SetPersistence(cycles)
' Sets Persist register ($0C)
' Sets number of consecutive out-of-range ALS cycles necessary to generate an interrupt
'       0       : Generate interrupt every ALS cycle, regardless if it's outside threshold range or not
'       1       : Generate interrupt anytime value goes outside threshold range/Out Of Range
'       2       : Generate interrupt when there have been 2 consecutive values OOR
'       3       : Generate interrupt when there have been 3 consecutive values OOR
'       4       : ...5 consecutive values
'       5 .. 14 : 10, 15, 20, 25, 30, 35, 40, 45, 50, 55
'       15      : 60
  writeReg1 (tsl2591#REG_PERSIST, lookdownz(cycles: 0, 1, 2, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60))

PUB SetPersistThresh(low_threshold, high_threshold) | als_long
' Sets trigger threshold values for persistent ALS interrupts
  if low_threshold < 0 or low_threshold > 65535 or high_threshold < 0 or high_threshold > 65535
    return

  writeReg4 (tsl2591#REG_AILTL, (high_threshold << 16) | low_threshold)

PUB SensorEnabled
' Returns whether the sensor ADCs have been enabled
  return ((readReg1 (tsl2591#REG_ENABLE) >> tsl2591#AEN) & %1) * TRUE

PUB SleepAfterInt(enabled) | npien, aien, aen, pon
' Enable Sleep After Interrupt
' TRUE or 1 enables, FALSE or 0 disables Sleeping after an Interrupt is asserted
  case ||enabled
    0, 1: enabled &= %1
    OTHER: return

  pokeReg_ENABLE ( tsl2591#SAI, enabled)

PUB SleepingAfterInt
' Indicates if the sensor will sleep after an interrupt is triggered
  return ((readReg1 (tsl2591#REG_ENABLE) >> tsl2591#SAI) & %1) * TRUE

PRI pokeReg_CONTROL(field, val) | reg_tmp, sreset, again, atime
' Read, modify fields, write byte back to CONTROL register
  reg_tmp := 0
  sreset := 0 
  again := 0
  atime := 0
' Get current state:
  reg_tmp := readReg1 (tsl2591#REG_CONTROL) 
' The SRESET field is here too, but don't bother reading it; it should never read as set
  again := (reg_tmp >> tsl2591#AGAIN) & tsl2591#AGAIN_MASK
  atime := reg_tmp & tsl2591#ATIME_MASK

  case field
    tsl2591#SRESET:
      sreset := val << tsl2591#SRESET
' If we're resetting, we don't care about preserving the other two fields
'   they'll be wiped after reset, anyway

    tsl2591#AGAIN:
      again := (val <# %11) << tsl2591#AGAIN
      atime := atime <# %101
 
    tsl2591#ATIME:
      again := again << tsl2591#AGAIN
      atime := val <# %101

    OTHER:
      return $DEADBEEF

  reg_tmp := (sreset | again | atime) & $FF
  writeReg1 (tsl2591#REG_CONTROL, reg_tmp)
  return reg_tmp

PRI pokeReg_ENABLE(field, val) | reg_tmp, npien, sai, aien, aen, pon
' Read, modify fields, write byte back to ENABLE register
  reg_tmp := 0
  npien := 0
  sai := 0
  aien := 0
  aen := 0
  pon := 0
' Get current state:
  reg_tmp := readReg1 (tsl2591#REG_ENABLE)
  npien := (reg_tmp >> tsl2591#NPIEN)  & %1
  sai   := (reg_tmp >> tsl2591#SAI)    & %1
  aien  := (reg_tmp >> tsl2591#AIEN)   & %1
  aen   := (reg_tmp >> tsl2591#AEN)    & %1
  pon   := (reg_tmp >> tsl2591#PON)    & %1

  case field
    tsl2591#NPIEN:
      npien := val << tsl2591#NPIEN
      sai   := sai << tsl2591#SAI
      aien  := aien << tsl2591#AIEN
      aen   := aen << tsl2591#AEN
      pon   := pon << tsl2591#PON

    tsl2591#SAI:
      sai := val << tsl2591#SAI
      npien := npien << tsl2591#NPIEN
      aien  := aien << tsl2591#AIEN
      aen   := aen << tsl2591#AEN
      pon   := pon << tsl2591#PON

    tsl2591#AIEN:
      aien := val << tsl2591#AIEN
      npien := npien << tsl2591#NPIEN
      sai   := sai << tsl2591#SAI
      aen   := aen << tsl2591#AEN
      pon   := pon << tsl2591#PON

    tsl2591#AEN:
      aen := val << tsl2591#AEN
      npien := npien << tsl2591#NPIEN
      sai   := sai << tsl2591#SAI
      aien  := aien << tsl2591#AIEN
      pon   := pon << tsl2591#PON

    tsl2591#PON:
      pon := val
      npien := npien << tsl2591#NPIEN
      sai   := sai << tsl2591#SAI
      aien  := aien << tsl2591#AIEN
      aen   := aen << tsl2591#AEN

  reg_tmp := npien | sai | aien | aen | pon
  writeReg1 (tsl2591#REG_ENABLE, reg_tmp)
  
PRI readReg1(reg): tmp
' Read 1 byte from register 'reg'
  ifnot lookdown(reg: $00, $01, $04..$0C, $11..$17)
    return $DEADBEEF
  i2c.start
  i2c.write (tsl2591#SLAVE_ADDR|W)
  i2c.write (tsl2591#TSL2591_CMD | tsl2591#TRANS_TYPE_NORMAL | reg)
  i2c.start
  i2c.write (tsl2591#SLAVE_ADDR|R)
  tmp := (i2c.read (TRUE)) & $FF
  i2c.stop

PRI readReg2(reg): tmp
' Read 2 bytes starting from register 'reg'
  ifnot lookdown(reg: $04, $06, $08, $0A, $14, $16)
    return $DEADBEEF
  i2c.start
  i2c.write (tsl2591#SLAVE_ADDR|W)
  i2c.write (tsl2591#TSL2591_CMD | tsl2591#TRANS_TYPE_NORMAL | reg)
  i2c.start
  i2c.write (tsl2591#SLAVE_ADDR|R)
  i2c.pread (@tmp, 2, TRUE)
  i2c.stop

PRI readReg4(reg): tmp | i2c_packet
' Read 4 bytes starting from register 'reg'
  ifnot lookdown(reg: $04, $08, $14)
    return $DEADBEEF
  i2c.start
  i2c.write (tsl2591#SLAVE_ADDR|W)
  i2c.write (tsl2591#TSL2591_CMD | tsl2591#TRANS_TYPE_NORMAL | reg)
  i2c.start
  i2c.write (tsl2591#SLAVE_ADDR|R)
  i2c.pread (@tmp, 4, TRUE)
  i2c.stop

PRI writeReg1(reg, val) | i2c_packet
' Write 1 byte 'val' to register 'reg'
  i2c_packet.byte[LSB] := tsl2591#SLAVE_ADDR|W
  i2c_packet.byte[1] := (tsl2591#TSL2591_CMD | tsl2591#TRANS_TYPE_NORMAL) | reg
  i2c_packet.byte[2] := val

  i2c.start
  i2c.pwrite (@i2c_packet, 3)
  i2c.stop

PRI writeReg2(reg, val) | i2c_packet
' Write 2 bytes 'val' starting with register 'reg'
  i2c_packet.byte[LSB] := tsl2591#SLAVE_ADDR|W
  i2c_packet.byte[1] := (tsl2591#TSL2591_CMD | tsl2591#TRANS_TYPE_NORMAL) | reg
  i2c_packet.byte[2] := val & $FFFF

  i2c.start
  i2c.pwrite (@i2c_packet, 4)
  i2c.stop

PRI writeReg4(reg, val) | i2c_packet[2]
' Write 4 bytes 'val' starting with register 'reg'
  i2c_packet.byte[LSB] := tsl2591#SLAVE_ADDR|W
  i2c_packet.byte[1] := (tsl2591#TSL2591_CMD | tsl2591#TRANS_TYPE_NORMAL) | reg
  i2c_packet.word[1] := val & $FFFF
  i2c_packet.word[2] := (val >> 16) & $FFFF

  i2c.start
  i2c.pwrite (@i2c_packet, 6)
  i2c.stop

PRI specFunc(func) | i2c_packet

  case func
    tsl2591#SPECFUNC_FORCEINT, tsl2591#SPECFUNC_CLEARALSINT, tsl2591#SPECFUNC_CLEARALS_NOPERSIST_INT, tsl2591#SPECFUNC_CLEAR_NOPERSIST_INT:
      i2c_packet.byte[LSB] := tsl2591#SLAVE_ADDR|W
      i2c_packet.byte[1] := (tsl2591#TSL2591_CMD | tsl2591#TRANS_TYPE_SPECIAL) | func '$Ex52
'      i2c_packet := constant( ((tsl2591#TSL2591_CMD | tsl2591#TRANS_TYPE_SPECIAL) << 8) | (tsl2591#SLAVE_ADDR|W)) | (func << 8) '$Ex52
    OTHER:
      return $DEADBEEF

  i2c.start
  i2c.pwrite (@i2c_packet, 2)
  i2c.stop

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
