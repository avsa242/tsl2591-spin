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

    SLAVE_WR        = core#SLAVE_ADDR
    SLAVE_RD        = core#SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 400_000

    LSB             = 0

    #0, GAIN_LOW, GAIN_MED, GAIN_HI, GAIN_MAX             ' Symbolic names for Gain settings
    #0, FULL, IR, VISIBLE, BOTH                           ' Sensor channel to read

OBJ

    i2c     : "jm_i2c_fast"
    core    : "core.con.tsl2591"

PUB Null
' This is not a top-level object

PUB Start: okay                                         ' Default to "standard" Propeller I2C pins and 400kHz

    okay := Startx (DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): okay

    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31)
        if I2C_HZ =< core#I2C_MAX_FREQ
            if okay := i2c.setupx (SCL_PIN, SDA_PIN, I2C_HZ)
                if DeviceID == core#DEV_ID_RESP
                    return okay
    return FALSE

PUB Stop
' Kills I2C cog
    i2c.terminate

PUB ClearAllInts
' Clears both ALS (persistent) and NPALS (non-persistent) Interrupts
'  specFunc (core#SPECFUNC_CLEARALS_NOPERSIST_INT)
    writeRegX (core#TRANS_SPECIAL, core#SF_CLEARALS_NOPERSIST_INT, 0, 0)

PUB ClearInt
' Clears NPALS Interrupt
'  specFunc (core#SPECFUNC_CLEAR_NOPERSIST_INT)
    writeRegX ( core#TRANS_SPECIAL, core#SF_CLEAR_NOPERSIST_INT, 0, 0)

PUB ClearPersistInt
' Clears ALS Interrupt
'  specFunc (core#SPECFUNC_CLEARALSINT)
    writeRegX ( core#TRANS_SPECIAL, core#SF_CLEARALSINT, 0, 0)

PUB DeviceID
' Returns contents of Device ID register ($12)
' Should return $50
'  device_id := readReg1 (core#ID) & $FF
    readRegX (core#ID, 1, @result)
    result &= $FF

PUB Interrupts(enabled) | tmp
' Enable non-persistent interrupts
'   Valid values: TRUE (1 or -1): interrupts enabled, FALSE (0) disables interrupts
'   Any other value polls the chip and returns the current setting
    readRegX (core#ENABLE, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := ||enabled << core#FLD_NPIEN
        OTHER:
            return ((tmp >> core#FLD_NPIEN) & %1) * TRUE

    tmp &= core#MASK_NPIEN
    tmp := (tmp | enabled) & core#ENABLE_MASK
    writeRegX ( core#TRANS_NORMAL, core#ENABLE, 1, tmp)

PUB PersistInterrupts(enabled) | tmp
' Enable persistent interrupts
'   Valid values: TRUE (1 or -1): interrupts enabled, FALSE (0) disables interrupts
'   Any other value polls the chip and returns the current setting
    readRegX (core#ENABLE, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := ||enabled << core#FLD_AIEN
        OTHER:
            return ((tmp >> core#FLD_AIEN) & %1) * TRUE

    tmp &= core#MASK_AIEN
    tmp := (tmp | enabled) & core#ENABLE_MASK
    writeRegX (core#TRANS_NORMAL, core#ENABLE, 1, tmp)

PUB Sensor(enabled) | tmp
' Enable ambient light sensor
'   Valid values: TRUE (1 or -1): sensor enabled, FALSE (0): sensor disabled
'   Any other value polls the chip and returns the current setting
    readRegX (core#ENABLE, 1, @tmp)
    case ||enabled
        0, 1:
            enabled := ||enabled << core#FLD_AEN
        OTHER:
            return ((tmp >> core#FLD_AEN) & %1) * TRUE

    tmp &= core#MASK_AEN
    tmp := (tmp | enabled) & core#ENABLE_MASK
    writeRegX (core#TRANS_NORMAL, core#ENABLE, 1, tmp)

PUB ForceInt
' Force an ALS Interrupt
' NOTE: Per TLS2591 Datasheet, for an interrupt to be visible on the INT pin,
'  one of the interrupt enable bits in the ENABLE ($00) register must be set.
'  i.e., make sure you've called EnableInts(TRUE) or EnablePersist (TRUE)
'  specFunc (core#SPECFUNC_FORCEINT)
    writeRegX ( core#TRANS_SPECIAL, core#SF_FORCEINT, 0, 0)

PUB Gain(multiplier) | tmp
' Set gain multiplier/factor
'   Valid values: 1, 25, 428, 9876
'   Any other value polls the chip and returns the current setting
    readRegX (core#CONTROL, 1, @tmp)
    case multiplier
        1, 25, 428, 9876:
            multiplier := lookdownz(multiplier: 1, 25, 428, 9876) << core#FLD_AGAIN
        OTHER:
            return (tmp >> core#FLD_AGAIN) & core#BITS_AGAIN

    tmp &= core#MASK_AGAIN
    tmp := (tmp | multiplier) & core#CONTROL_MASK
    writeRegX (core#TRANS_NORMAL, core#CONTROL, 1, tmp)

PUB IntThresh(low, high) | tmp
' Set non-persistent interrupt thresholds
'   Valid values for low and high thresholds: 0..65535
'   Any other value polls the chip and returns the current setting
'       (high threshold will be returned in upper word of result, low threshold in lower word)
    readRegX (core#NPAILTL, 4, @tmp)
    case low
        0..65535:
        OTHER:
            result.word[0] := tmp.word[0]

    case high
        0..65535:
            high := (high << 16) | low
        OTHER:
            result.word[1] := tmp.word[1]

    case result
        0:
        OTHER:
            return result

    writeRegX (core#TRANS_NORMAL, core#NPAILTL, 4, high)', reg, nr_bytes, val)

PUB IntegrationTime(time_ms) | tmp
' Set ADC Integration time, in milliseconds (affects both photodiode channels)
'   Valid values: 100, 200, 300, 400, 500, 600
'   Any other value polls the chip and returns the current setting
    readRegX (core#CONTROL, 1, @tmp)
    case time_ms
        100, 200, 300, 400, 500, 600:
            time_ms := lookdownz(time_ms: 100, 200, 300, 400, 500, 600)
        OTHER:
            result := tmp & core#BITS_ATIME
            return lookupz(result: 100, 200, 300, 400, 500, 600)

    tmp &= core#MASK_ATIME
    tmp := (tmp | time_ms) & core#CONTROL_MASK
    writeRegX (core#TRANS_NORMAL, core#CONTROL, 1, tmp)

PUB IntTriggered
' Indicates if a no-persist interrupt has been triggered
  return ((readReg1 (core#STATUS) >> core#NPINTR) & %1) * TRUE

PUB IsPowered
' Indicates if the sensor is powered on
  return ((readReg1 (core#ENABLE) >> core#PON) & %1) * TRUE

PUB Luminosity(channel) | tmp
' Get luminosity data from sensor
' %00 - Full spectrum
' %01 - IR
' %10 - Visible
' %11 - Both (see comments for case %11)
  case channel
    %00:
      tmp := 0
      tmp := readReg2 (core#C0DATAL)
      return tmp
    ' Reads ALS data from channel 0 (Full spectrum)

    %01:
      return readReg2 (core#C1DATAL)
    ' Reads ALS data from channel 1 (IR)
    
    %10:
      tmp := readReg4 (core#C0DATAL)
      return tmp.word[0] - tmp.word[1]
    ' Reads ALS data from both channels (returns Visible only)

    %11:
      return readReg4 (core#C0DATAL)

    ' Reads ALS data from both channels (returns both channels)
    ' Bits 31..16/Most-significant word contain the IR data
    ' Bits 15..0/Least-significant word contain the Full-spectrum light data
    
    OTHER: return

PUB MeasurementComplete
' Is ALS data valid?
' Indicates ADCs completed integration cycle since AEN bit was set
  return ((readReg1 (core#STATUS) >> core#AVALID) & %1) * TRUE

PUB PackageID
' Returns Package ID register ($11)
' Should always return $00
' Bits 7..6: Reserved (should be 0)
'      5..4: Package ID (%00)
'      3..0: Reserved (should be 0)
'  return ((readReg1 (core#PID) >> core#PID) & core#PID_MASK)
    readRegX (core#PID, 1, @result)'reg, nr_bytes, addr_buff)

PUB PersistCycles | tmp
' Returns Interrupt persistence filter value
' Queries the PERSIST register and returns the number of consecutive cycles necessary to generate an interrupt
  return lookupz(readReg1 (core#PERSIST) & core#APERS_MASK: 0, 1, 2, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60)

PUB PersistIntTriggered
' Indicates if a persistent interrupt has been triggered
  return ((readReg1 (core#STATUS) >> core#AINT) & %1) * TRUE

PUB PersistThresh: threshold
' Gets ALS threshold values currently set
' Bits 31..16: AIHTH_AIHTL - High threshold word
'      15..0: AILTH_AILTL - Low threshold word
  return readReg4 (core#AILTL)

PUB PowerOn(power) | npien, sai, aien, aen
' Power ON
'  1 or TRUE activates the sensor's internal oscillator
'  0 or FALSE disables the oscillator/powers down
'  anything else is ignored
  case ||power
    0, 1: power &= %1
    OTHER: return

  pokeENABLE (core#PON, power)

PUB Reset
' Resets the TSL2591
' Sets SRESET/System Reset field in CONTROL register. Equivalent to Power-On Reset
' Field is self-clearing (i.e., once reset, it will be set back to 0)
'  pokeCONTROL (core#SRESET, 1)
    writeRegX ( core#TRANS_NORMAL, core#CONTROL, 1, 1 << core#FLD_SRESET)

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
  writeReg1 (core#PERSIST, lookdownz(cycles: 0, 1, 2, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60))

PUB SetPersistThresh(low_threshold, high_threshold) | als_long
' Sets trigger threshold values for persistent ALS interrupts
  if low_threshold < 0 or low_threshold > 65535 or high_threshold < 0 or high_threshold > 65535
    return

  writeReg4 (core#AILTL, (high_threshold << 16) | low_threshold)

PUB SleepAfterInt(enabled) | npien, aien, aen, pon
' Enable Sleep After Interrupt
' TRUE or 1 enables, FALSE or 0 disables Sleeping after an Interrupt is asserted
  case ||enabled
    0, 1: enabled &= %1
    OTHER: return

  pokeENABLE ( core#SAI, enabled)

PUB SleepingAfterInt
' Indicates if the sensor will sleep after an interrupt is triggered
  return ((readReg1 (core#ENABLE) >> core#SAI) & %1) * TRUE

PRI pokeCONTROL(field, val) | tmp, sreset, again, atime
' Read, modify fields, write byte back to CONTROL register
  tmp := 0
  sreset := 0 
  again := 0
  atime := 0
' Get current state:
  tmp := readReg1 (core#CONTROL) 
' The SRESET field is here too, but don't bother reading it; it should never read as set
  again := (tmp >> core#AGAIN) & core#AGAIN_MASK
  atime := tmp & core#ATIME_MASK

  case field
    core#SRESET:
      sreset := val << core#SRESET
' If we're resetting, we don't care about preserving the other two fields
'   they'll be wiped after reset, anyway

    core#AGAIN:
      again := (val <# %11) << core#AGAIN
      atime := atime <# %101
 
    core#ATIME:
      again := again << core#AGAIN
      atime := val <# %101

    OTHER:
      return $DEADBEEF

  tmp := (sreset | again | atime) & $FF
  writeReg1 (core#CONTROL, tmp)
  return tmp

PRI pokeENABLE(field, val) | tmp, npien, sai, aien, aen, pon
' Read, modify fields, write byte back to ENABLE register
  tmp := 0
  npien := 0
  sai := 0
  aien := 0
  aen := 0
  pon := 0
' Get current state:
  tmp := readReg1 (core#ENABLE)
  npien := (tmp >> core#NPIEN)  & %1
  sai   := (tmp >> core#SAI)    & %1
  aien  := (tmp >> core#AIEN)   & %1
  aen   := (tmp >> core#AEN)    & %1
  pon   := (tmp >> core#PON)    & %1

  case field
    core#NPIEN:
      npien := val << core#NPIEN
      sai   := sai << core#SAI
      aien  := aien << core#AIEN
      aen   := aen << core#AEN
      pon   := pon << core#PON

    core#SAI:
      sai := val << core#SAI
      npien := npien << core#NPIEN
      aien  := aien << core#AIEN
      aen   := aen << core#AEN
      pon   := pon << core#PON

    core#AIEN:
      aien := val << core#AIEN
      npien := npien << core#NPIEN
      sai   := sai << core#SAI
      aen   := aen << core#AEN
      pon   := pon << core#PON

    core#AEN:
      aen := val << core#AEN
      npien := npien << core#NPIEN
      sai   := sai << core#SAI
      aien  := aien << core#AIEN
      pon   := pon << core#PON

    core#PON:
      pon := val
      npien := npien << core#NPIEN
      sai   := sai << core#SAI
      aien  := aien << core#AIEN
      aen   := aen << core#AEN

  tmp := npien | sai | aien | aen | pon
  writeReg1 (core#ENABLE, tmp)
  
PRI readReg1(reg): tmp
' Read 1 byte from register 'reg'
  ifnot lookdown(reg: $00, $01, $04..$0C, $11..$17)
    return $DEADBEEF
  i2c.start
  i2c.write (core#SLAVE_ADDR|W)
  i2c.write (core#TSL2591_CMD | core#TRANS_TYPE_NORMAL | reg)
  i2c.start
  i2c.write (core#SLAVE_ADDR|R)
  tmp := (i2c.read (TRUE)) & $FF
  i2c.stop

PRI readReg2(reg): tmp
' Read 2 bytes starting from register 'reg'
  ifnot lookdown(reg: $04, $06, $08, $0A, $14, $16)
    return $DEADBEEF
  i2c.start
  i2c.write (core#SLAVE_ADDR|W)
  i2c.write (core#TSL2591_CMD | core#TRANS_TYPE_NORMAL | reg)
  i2c.start
  i2c.write (core#SLAVE_ADDR|R)
  i2c.pread (@tmp, 2, TRUE)
  i2c.stop

PRI readReg4(reg): tmp | i2c_packet
' Read 4 bytes starting from register 'reg'
  ifnot lookdown(reg: $04, $08, $14)
    return $DEADBEEF
  i2c.start
  i2c.write (core#SLAVE_ADDR|W)
  i2c.write (core#TSL2591_CMD | core#TRANS_TYPE_NORMAL | reg)
  i2c.start
  i2c.write (core#SLAVE_ADDR|R)
  i2c.pread (@tmp, 4, TRUE)
  i2c.stop

PUB readRegX(reg, nr_bytes, addr_buff) | cmd_packet[2], ackbit
'Read nr_bytes from register 'reg' to address 'addr_buff'
    writeRegX (core#TRANS_NORMAL, reg, 0, 0)

    i2c.start
    i2c.write (SLAVE_RD)
    i2c.pread (addr_buff, nr_bytes, TRUE)
    i2c.stop

PUB writeRegX(trans_type, reg, nr_bytes, val) | cmd_packet[2], tmp
' Write nr_bytes to register 'reg' stored in val
    cmd_packet.byte[LSB] := SLAVE_WR

    case trans_type
        core#TRANS_NORMAL:
            case reg
                core#ENABLE, core#CONTROL, core#AILTL..core#NPAIHTH, core#PERSIST, core#PID..core#C1DATAH:
                OTHER:
                    return
'            cmd_packet.byte[1] := (core#TSL2591_CMD | trans_type) | reg

        core#TRANS_SPECIAL:
            case reg
                core#SF_FORCEINT, core#SF_CLEARALSINT, core#SF_CLEARALS_NOPERSIST_INT, core#SF_CLEAR_NOPERSIST_INT:
                    nr_bytes := 0
                    val := 0
                OTHER:
                    return

        OTHER:
            return

    cmd_packet.byte[1] := (core#TSL2591_CMD | trans_type) | reg

    case nr_bytes
        0:
        1..4:
            repeat tmp from 0 to nr_bytes-1
                cmd_packet.byte[2 + tmp] := val.byte[tmp]
        OTHER:
            return

    i2c.start
    i2c.pwrite (@cmd_packet, 2 + nr_bytes)
    i2c.stop

PRI writeReg1(reg, val) | i2c_packet
' Write 1 byte 'val' to register 'reg'
  i2c_packet.byte[LSB] := core#SLAVE_ADDR|W
  i2c_packet.byte[1] := (core#TSL2591_CMD | core#TRANS_TYPE_NORMAL) | reg
  i2c_packet.byte[2] := val

  i2c.start
  i2c.pwrite (@i2c_packet, 3)
  i2c.stop

PRI writeReg2(reg, val) | i2c_packet
' Write 2 bytes 'val' starting with register 'reg'
  i2c_packet.byte[LSB] := core#SLAVE_ADDR|W
  i2c_packet.byte[1] := (core#TSL2591_CMD | core#TRANS_TYPE_NORMAL) | reg
  i2c_packet.byte[2] := val & $FFFF

  i2c.start
  i2c.pwrite (@i2c_packet, 4)
  i2c.stop

PRI writeReg4(reg, val) | i2c_packet[2]
' Write 4 bytes 'val' starting with register 'reg'
  i2c_packet.byte[LSB] := core#SLAVE_ADDR|W
  i2c_packet.byte[1] := (core#TSL2591_CMD | core#TRANS_TYPE_NORMAL) | reg
  i2c_packet.word[1] := val & $FFFF
  i2c_packet.word[2] := (val >> 16) & $FFFF

  i2c.start
  i2c.pwrite (@i2c_packet, 6)
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
