{
    --------------------------------------------
    Filename: sensor.lux.tsl2591.spin
    Description: Driver for the TSL2591 I2C Light/lux sensor
    Author: Jesse Burt
    Copyright (c) 2018
    See end of file for terms of use.
    --------------------------------------------
}
'TODO:
' Test most/all of these in the demo/test harness
' Perhaps most importantly - verify computed lux values in the demo/test harness are reasonably (=?) accurate...need calibrated light meter

CON

  TSL2591_SLAVE     = $29 << 1
  W                 = %0
  R                 = %1

  SCL               = 28
  SDA               = 29
  HZ                = tsl2591#I2C_MAX_RATE

  #0, GAIN_LOW, GAIN_MED, GAIN_HI, GAIN_MAX

VAR

  long  _als_data
  byte  _ackbit

OBJ

  i2c     : "jm_i2c_fast"
  tsl2591 : "core.con.tsl2591"

PUB Null
' This is not a top-level object

PUB Start: okay                                         'Default to "standard" Propeller I2C pins and 400kHz

  okay := Startx (SCL, SDA, HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ)

  if lookdown(SCL_PIN: 0..31)                           'Validate pins
    if lookdown(SDA_PIN: 0..31)
      if SCL_PIN <> SDA_PIN
        if I2C_HZ =< HZ
          return i2c.setupx (SCL_PIN, SDA_PIN, I2C_HZ)
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
' Clears both ALS and NPALS Interrupts
  SpecialFunc (tsl2591#SPECFUNC_CLEARALS_NOPERSIST_INT)

PUB ClearInt
' Clears NPALS Interrupt
  SpecialFunc (tsl2591#SPECFUNC_CLEAR_NOPERSIST_INT)

PUB ClearPersistInt
' Clears ALS Interrupt
  SpecialFunc (tsl2591#SPECFUNC_CLEARALSINT)

PUB DeviceID: device_id
' Returns contents of Device ID register ($12)
' Should return $50
  Command (tsl2591#REG_ID)
  ReadByte (@device_id)

PUB EnableInts(enabled) | sai, aien, aen, pon
' Enables or disables Interrupts
  case ||enabled
    1: enabled <<= 7
    OTHER: enabled := 0

  sai := getField_SAI
  aien := getField_AIEN
  aen := getField_AEN
  pon := getField_PON
  setReg_ENABLE (enabled, SAI, AIEN, AEN, PON)

PUB EnablePersist(enabled) | sai, npien, aen, pon
' Enables or disables Interrupts
  case ||enabled
    1: enabled <<= 7
    OTHER: enabled := 0

  npien := getField_NPIEN'quicknote: generic get function that uses constants to extract/set bits
  sai := getField_SAI
  aen := getField_AEN
  pon := getField_PON
  setReg_ENABLE (NPIEN, SAI, enabled, AEN, PON)

PUB EnableSensor(enabled) | npien, sai, aien, pon
' Enable sensor's internal ADCs
' 1 or TRUE activates ADCs
' anything else disables the ADCs
  case ||enabled
    1: enabled &= 1
    OTHER: enabled := 0

  npien := getField_NPIEN
  sai := getField_SAI
  aien := getField_AIEN
  pon := getField_PON

  setReg_ENABLE (NPIEN, SAI, AIEN, enabled, PON)

PUB ForceInt 'XXX
' Force an ALS Interrupt
' NOTE: Per TLS2591 Datasheet, for an interrupt to be visible on the INT pin,
'  one of the interrupt enable bits in the ENABLE ($00) register must be set.
'  i.e., make sure you've called EnableInts(TRUE)
  SpecialFunc (tsl2591#SPECFUNC_FORCEINT)

PUB FullSpec
' Returns Full-spectrum light data portion of last ALS data read
' NOTE: ReadLightData must be called first
  return _als_data.word[0] & $FFFF

PUB Gain
' Returns gain setting for internal integration amplifiers
' Value returned is a factor
  return lookupz(getField_AGAIN: 1, 25, 428, 9876)

PUB GetIntThresh: threshold
' Gets no-persist ALS threshold values currently set
' Bits 31..16: NPAIHTH_NPAIHTL - High threshold word
'      15..0: NPAILTH_NPAILTL - Low threshold word
  Command (tsl2591#REG_NPAILTL)
  ReadLong (@threshold)

PUB GetPersistCycles
' Returns Interrupt persistence filter value
' Queries the PERSIST register and returns the number of consecutive cycles necessary to generate an interrupt
  return lookupz(getField_APERS: 0, 1, 2, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60)

PUB GetPersistThresh: threshold
' Gets ALS threshold values currently set
' Bits 31..16: AIHTH_AIHTL - High threshold word
'      15..0: AILTH_AILTL - Low threshold word
  Command (tsl2591#REG_AILTL)
  ReadLong (@threshold)

PUB IntegrationTime
' Returns ADC Integration time (both channels)
' Queries CONTROL Register and returns ADC Integration time in milliseconds
  return (getField_ATIME + 1) * 100

PUB IntsEnabled
' Gets No-Persist Interrupt Enable field
' Queries Enable Register and returns No-Persist Interrupt Enable field bit, promotes to TRUE
  return getField_NPIEN * TRUE

PUB IntTriggered
' Indicates No-persist interrupt, promotes to TRUE
  return getField_NPINTR * TRUE

PUB IR
' Returns IR light data portion of last ALS data read
' NOTE: ReadLightData must be called first
  return _als_data.word[1] & $FFFF

PUB IsPowered
' Indicates if the sensor powered on, promotes to TRUE
  return getField_PON * TRUE

PUB LastDataValid
' Is ALS data valid
' Indicates ADCs completed integration cycle since AEN bit was set
  return (getReg_STATUS & 1) * TRUE

PUB PackageID: package_id
' Returns Package ID register ($11)
' Should always return $00
' Bits 7..6: Reserved (should be 0)
'      5..4: Package ID (%00)
'      3..0: Reserved (should be 0)
  Command (tsl2591#REG_PID)
  ReadByte (@package_id)

PUB PersistIntsEnabled
' Indicates if Persistent Interrupts are enabled, promotes to TRUE
  return getField_AIEN * TRUE

PUB PersistIntTriggered
' Indicates if a Persistent Interrupt has been triggered, promotes to TRUE
  return getField_AINT * TRUE

PUB PowerOn(power) | npien, sai, aien, aen
' Power ON
'  1 or TRUE activates the sensor's internal oscillator
'  anything else disables the oscillator/powers down
  case ||power
    1: power &= 1
    OTHER: power := 0

  npien := getField_NPIEN
  sai := getField_SAI
  aien := getField_AIEN
  aen := getField_AEN

  setReg_ENABLE (NPIEN, SAI, AIEN, AEN, power)

PUB Probe_TSL2591 | check
' Probes I2C Bus for device ACK at slave address $29, and if there is a response,
'  query the device for the ID register, which should always return $50.
' Returns TRUE only if *both* conditions are satisfied
  i2c.start
  check := i2c.write(TSL2591_SLAVE)
  i2c.stop

  if (check == i2c#ACK) AND (DeviceID == $50)
    return TRUE
  else
    return FALSE

PUB ReadLightData
' Gets data from ALS registers ($14..$17)
' Reads ALS data from both channels
' Bits 31..16/Most-significant word contain the IR data
' Bits  15..0/Least-significant word contain the Full light data
  Command (tsl2591#REG_C0DATAL)
  ReadLong (@_als_data)
{  if _als_data.word[0] := $FFFF
    _als_data.word[0] := $0000
  if _als_data.word[1] := $FFFF
    _als_data.word[1] := $0000}
  return _als_data

PUB Reset
' Resets the TSL2591
' Sets SRESET/System Reset field in CONTROL register. Equivalent to Power-On Reset
' Field is self-clearing (i.e., once reset, it will be set back to 0)
  setReg_CONTROL (1, 0, 0)

PUB SensorEnabled
' Indicates if the sensor's internal ADCs are enabled, promotes to TRUE
  return getField_AEN * TRUE

PUB SetIntegrationTime(ms) | again
' Set the ADC Integration Time, in ms
' Time  Value Written   Max ADC count
' 100ms %000            37888
' 200ms %001            65535
' 300ms %010            65535
' 400ms %011            65535
' 500ms %100            65535
' 600ms %101            65535
  again := getField_AGAIN                       'We're only setting one field in a multi-field register, so we want to
                                                'preserve the current settings of the other fields not being modified.
  setReg_CONTROL (0, again, lookdownz(ms: 100, 200, 300, 400, 500, 600))

PUB SetPersistThresh(low_threshold_word, high_threshold_word) | als_long
' Sets ALS threshold values/registers ($04..$07)
'  low_threshold_word - Low threshold
'  high_threshold_word - high threshold
  if low_threshold_word < 0 or low_threshold_word > 65535 or high_threshold_word < 0 or high_threshold_word > 65535
    return
  CommandWords (tsl2591#REG_AILTL, low_threshold_word, high_threshold_word)

PUB SetGain(gain_mult)
' Sets amplifier gain (affects both channels)
' * 1x
'   25x
'   428x
'   9876x
  setField_AGAIN(lookdownz(gain_mult: 1, 25, 428, 9876))

PUB SetInterruptThresh(low_threshold_word, high_threshold_word) | npals_long
' Sets no-persist ALS threshold values/registers ($08..$0B)
  if low_threshold_word < 0 or low_threshold_word > 65535 or high_threshold_word < 0 or high_threshold_word > 65535
    return
  CommandWords (tsl2591#REG_NPAILTL, low_threshold_word, high_threshold_word)

PUB SetPersistence(cycles)
' Sets Persist register ($0C)
' Sets number of consecutive out-of-range ALS cycles necessary to generate an interrupt
'  Bits 7..4: Reserved (write as 0, should read 0)
'      3..0: APERS - Number of cycles
'       0000: Generate interrupt every ALS cycle, regardless
'       0001: Generate interrupt anytime value goes outside threshold range/OOR
'       0010: Generate interrupt when there have been 2 consecutive values OOR
'       0011: 3
'       0100: 5
'        .. : 10, 15, 20, 25, 30, 35, 40, 45, 50, 55
'       1111: 60
  Command (tsl2591#REG_PERSIST)
  WriteByte (lookdownz(cycles: 0, 1, 2, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60))

PUB SleepAfterInt(enabled) | npien, aien, aen, pon
' Enable Sleep After Interrupt
' Enable or Disable Sleeping after an Interrupt is asserted
  case ||enabled
    1: enabled &= 1
    OTHER: enabled := 0

  npien := getField_NPIEN
  aien := getField_AIEN
  aen := getField_AEN
  pon := getField_PON

  setReg_ENABLE (NPIEN, enabled, AIEN, AEN, PON)

PUB SleepingAfterInt
' Indicates if the sensor will sleep after an interrupt is triggered, promotes to TRUE
  return getField_SAI * TRUE

PRI getField_AEN
' Gets ALS ENable field
' Queries Enable Register and returns ALS ENable field bit
  return (getReg_ENABLE >> 1) & 1

PRI getField_AGAIN
' Returns gain setting for internal integration amplifiers
' Queries Control Register and returns bits 5..4
' Bits 5..4:
'       %00: Low-gain
'       %01: Medium-gain
'       %10: High-gain
'       %11: Max-gain
  return (getReg_CONTROL>> 4) & %11

PRI getField_AIEN
' Gets ALS Interrupt ENable field
' Queries Enable Register and returns ALS Interrupt ENable field bits
  return (getReg_ENABLE >> 4) & 1

PRI getField_AINT
' Indicates ALS interrupt
' Bit 4 of STATUS register
  return (getReg_STATUS >> 4) & %1

PRI GetALS_IntThreshReg: long__threshold | als_long
' Gets ALS threshold values currently set
' Bits 31..16: AIHTH_AIHTL - High threshold word
'      15..0: AILTH_AILTL - Low threshold word
  Command (tsl2591#REG_AILTL)
  ReadLong (@long__threshold)

PRI getField_APERS: cycles
' Gets currently set number of consecutive out-of-range ALS cycles necessary to generate an interrupt
' Bits 7..4: Reserved (write as 0, should read 0)
'      3..0: APERS - Number of cycles
'       0000: Generate interrupt every ALS cycle, regardless
'       0001: Generate interrupt anytime value goes outside threshold range/OOR
'       0010: Generate interrupt when there have been 2 consecutive values OOR
'       0011: 3
'       0100: 5
'        .. : 10, 15, 20, 25, 30, 35, 40, 45, 50, 55
'       1111: 60
  Command (tsl2591#REG_PERSIST)
  ReadByte (@cycles) 'No bounds checking/clamping to lower 4 bits...should there be?

PRI getField_ATIME
' Returns ADC Integration time (both channels)
' Queries Control Register and returns bits 2..0
' Val   Int time  Max Count
' %000  100ms     37888
' %001  200ms     65535
' %010  300ms     65535
' %011  400ms     65535
' %100  500ms     65535
' %101  600ms     65535
  return getReg_CONTROL & %111

PRI getReg_CONTROL: ctrl_reg
' Returns Control Register ($01) value
' Bits    7: SRESET - System Reset (self-clearing)
'         6: Reserved (should read 0)
'      5..4: AGAIN - ALS Gain
'         3: Reserved (should read 0)
'      2..0: ATIME - ADC integration Time
  Command (tsl2591#REG_CONFIG)
  ReadByte (@ctrl_reg)

PRI getReg_ENABLE: state
' Returns Enable Register ($00) contents
  Command (tsl2591#REG_ENABLE)
  ReadByte (@state)

PRI getField_NPIEN
' Gets No-Persist Interrupt ENable field
' Queries Enable Register and returns No-Persist Interrupt ENable field bit
  return (getReg_ENABLE >> 7) & 1

PRI getField_NPINTR
' Indicates No-persist interrupt
' Bit 5 of STATUS register
  return (getReg_STATUS >> 5) & %1

PRI getField_PON: pon
' Gets Power ON field
' Queries Enable Register and returns Power ON field bit
  pon := getReg_STATUS & %1

PRI getField_SAI: sai
' Gets Sleep After Interrupt field
' Queries Enable Register and returns Sleep After Interrupt field bit
  sai := (getReg_ENABLE >> 6) & %1

PRI getReg_STATUS: dev_status
' Returns contents of Status register ($13)
' Bits 7..6: Reserved (should be 0)
'         5: NPINTR - Indicates No-persist interrupt
'         4: AINT - Indicates ALS interrupt
'      3..1: Reserved (should be 0)
'         0: AVALID - Indicates ADCs completed integration cycle since AEN bit was set
  Command (tsl2591#REG_STATUS)
  ReadByte (@dev_status)

PRI setReg_CONTROL(SRESET, AGAIN, ATIME) | ctrl_byte
' Set ALS Gain and ADC integration Time, and also provide System Reset
' SRESET - System Reset (= POR)
' AGAIN  - ALS Gain
' ATIME  - ALS Time/ADC Integration time

  ctrl_byte := ((SRESET & %1) << 7) | ((AGAIN & %11) << 4) | (ATIME & %111)
  Command (tsl2591#REG_CONFIG)
  WriteByte (ctrl_byte)

PRI setReg_ENABLE(NPIEN, SAI, AIEN, AEN, PON) | ena_byte
' Set Enable Register ($00) fields
' Power device on or off, enable functions, interrupts
' Bits  7: NPIEN  - No Persist Interrupt Enable
'       6: SAI    - Sleep After Interrupt
'       5: Reserved (write as 0, should read 0)
'       4: AIEN   - ALS Interrupt Enable
'    3..2: Reserved (write as 0, should read 0)
'       1: AEN    - ALS Enable
'       0: PON    - Power On
  ena_byte := ((NPIEN & %1) << 7) | ((SAI & %1) << 6) | ((AIEN & %1) << 4) | ((AEN & %1) << 1) | (PON & %1)
  Command (tsl2591#REG_ENABLE)
  WriteByte (ena_byte)

PRI setField_AGAIN(gain_mode) | atime
' Sets amplifier gain (affects both channels)
  case gain_mode
    GAIN_LOW..GAIN_MAX:
    OTHER: gain_mode := %00

  atime := getField_ATIME        'We're only setting one field in a multi-field register, so we want to
                                      'preserve the current settings of the other fields not being modified.
  setReg_CONTROL (0, gain_mode, atime)

PRI SpecialFunc(func) | cmd_packet
' Set/clear interrupts
' %00100: Force Interrupt
' %00110: Clear ALS Interrupt
' %00111: Clear ALS and No-Persist Interrupt
' %01010: Clear No-Persist Interrupt
'  Other values ignored
  case func
    tsl2591#SPECFUNC_FORCEINT:
      cmd_packet.byte[0] := TSL2591_SLAVE|W
      cmd_packet.byte[1] := (tsl2591#TSL2591_CMD | tsl2591#TRANS_TYPE_SPECIAL) | tsl2591#SPECFUNC_FORCEINT
    tsl2591#SPECFUNC_CLEARALSINT:
      cmd_packet.byte[0] := TSL2591_SLAVE|W
      cmd_packet.byte[1] := (tsl2591#TSL2591_CMD | tsl2591#TRANS_TYPE_SPECIAL) | tsl2591#SPECFUNC_CLEARALSINT
    tsl2591#SPECFUNC_CLEARALS_NOPERSIST_INT:
      cmd_packet.byte[0] := TSL2591_SLAVE|W
      cmd_packet.byte[1] := (tsl2591#TSL2591_CMD | tsl2591#TRANS_TYPE_SPECIAL) | tsl2591#SPECFUNC_CLEARALS_NOPERSIST_INT
    tsl2591#SPECFUNC_CLEAR_NOPERSIST_INT:
      cmd_packet.byte[0] := TSL2591_SLAVE|W
      cmd_packet.byte[1] := (tsl2591#TSL2591_CMD | tsl2591#TRANS_TYPE_SPECIAL) | tsl2591#SPECFUNC_CLEAR_NOPERSIST_INT
    OTHER:
      return

  i2c.start
  i2c.pwrite (@cmd_packet, 2)
  i2c.stop

PRI Command(register) | cmd_packet
' Send device Command
' Bits  4..0: Register Address
  case register
    $00, $01, $04..$0C, $11..$17:
      cmd_packet.byte[0] := TSL2591_SLAVE|W
      cmd_packet.byte[1] := (tsl2591#TSL2591_CMD | tsl2591#TRANS_TYPE_NORMAL) | (register & %11111)
    OTHER:
      return
  i2c.start
  i2c.pwrite (@cmd_packet, 2)
  i2c.stop

PRI CommandWords(register, low_word, high_word) | cmd_packet[2]
' Send device Command, then two words of data, LSW first
' This was created specially for the SetALS_IntThreshReg and SetNPALS_IntThreshReg methods
' Bits  4..0: Register Address
  case register
    $04..$0B:     'This method is really only designed for these eight registers, so ignore anything else
      cmd_packet.byte[0] := TSL2591_SLAVE|W
      cmd_packet.byte[1] := (tsl2591#TSL2591_CMD | tsl2591#TRANS_TYPE_NORMAL) | (register & %11111)
      cmd_packet.word[1] := low_word
      cmd_packet.word[2] := high_word
    OTHER:
      return
  i2c.start
  _ackbit := i2c.pwrite (@cmd_packet, 6)
  i2c.stop

PRI ReadByte(ptr_byte)
' Reads one byte from the TSL2591
  i2c.start
  _ackbit := i2c.write (TSL2591_SLAVE|R)
  i2c.pread (ptr_byte, 1, TRUE)
  i2c.stop

PRI ReadLong(ptr_long) | raw_data
' Reads four bytes from the TSL2591
  i2c.start
  _ackbit := i2c.write (TSL2591_SLAVE|R)
  i2c.pread (@raw_data, 4, TRUE)
  i2c.stop
  long[ptr_long] := raw_data

PRI ReadWord(ptr_word) | raw_data
' Reads two bytes from the TSL2591
  i2c.start
  _ackbit := i2c.write (TSL2591_SLAVE|R)
  i2c.pread (@raw_data, 2, TRUE)
  i2c.stop
  {word}long[ptr_word] := raw_data.word[0]

PRI WriteLong(data_long) | byte_part
' Writes four bytes (packed into one long) to the TSL2591
  i2c.start
  i2c.write (TSL2591_SLAVE|W)
  _ackbit := i2c.pwrite (@data_long, 4)
  i2c.stop

PRI WriteByte(data_byte)
' Writes one byte to the TSL2591
  i2c.start
  i2c.write (TSL2591_SLAVE|W)
  _ackbit := i2c.write (data_byte)
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
