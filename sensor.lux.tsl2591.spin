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
' For Get*/Set* Methods:
'   - Use CASE for specific allowed values, limit minimum/maximum for sequential ranges
'   - Separate methods for
'     Getting "processed" values, i.e., return parsed units. e.g., GetPersist would return %1001
'     Getting "unprocessed" values, i.e., return raw value from device. e.g., GetPersist_raw might return 30
' Break Special Function/Interrupt settings into separate methods

CON

  TSL2591_SLAVE     = $29 << 1
  W                 = %0
  R                 = %1
  TSL2591_MAX_RATE  = 400_000   'Max I2C Clock, per TSL2591 datasheet
  
  TSL2591_ENABLE    = $00
  TSL2591_CONFIG    = $01
  TSL2591_AILTL     = $04
  TSL2591_AILTH     = $05
  TSL2591_AIHTL     = $06
  TSL2591_AIHTH     = $07
  TSL2591_NPAILTL   = $08
  TSL2591_NPAILTH   = $09
  TSL2591_NPAIHTL   = $0A
  TSL2591_NPAIHTH   = $0B
  TSL2591_PERSIST   = $0C
  TSL2591_PID       = $11
  TSL2591_ID        = $12
  TSL2591_STATUS    = $13
  TSL2591_C0DATAL   = $14
  TSL2591_C0DATAH   = $15
  TSL2591_C1DATAL   = $16
  TSL2591_C1DATAH   = $17

'Select Command Register
  TSL2591_CMD                                 = %1000_0000
'Select type of transaction to follow in subsequent data transfers
  TSL2591_CMD_NORMAL                          =  %01      << 5
  TSL2591_CMD_SPECIAL                         =  %11      << 5
'Special function field - use if TSL2591_CMD_SPECIAL bits above are set
  TSL2591_CMD_SPECIAL_FORCEINT                =     %00100
  TSL2591_CMD_SPECIAL_CLEARALSINT             =     %00110
  TSL2591_CMD_SPECIAL_CLEARALS_NOPERSIST_INT  =     %00111
  TSL2591_CMD_SPECIAL_CLEAR_NOPERSIST_INT     =     %01010

VAR

  long  _als_data
  byte  _ackbit

OBJ

  i2c   : "jm_i2c_fast"

PUB Null
' This is not a top-level object

PUB Start(i2c_scl, i2c_sda, i2c_Hz): okay
'Start I2C object - limit bus speed to 400kHz maximum, specified by TLS2591 datasheet
  i2c_Hz := (||i2c_Hz) <# TSL2591_MAX_RATE
  okay := i2c.setupx (i2c_scl, i2c_sda, i2c_Hz)

PUB Stop
'Kills I2C cog
  i2c.terminate

PUB Find_TSL | check, device_id', package_id
'Probes I2C Bus for device ACK, and if there is a response,
' query the device for the ID register (should return $50).
'Returns TRUE *only* if both conditions are satisfied
  i2c.start
  check := i2c.write(TSL2591_SLAVE)
  i2c.stop

'  package_id := GetPackageID
  device_id := GetDeviceID


  if (check == i2c#ACK) AND (device_id == $50)
    return TRUE
  else
    return FALSE

PUB Command(register) | cmd_packet
'Send device Command
' Bits  4..0: Register Address
  cmd_packet.byte[0] := TSL2591_SLAVE|W
  cmd_packet.byte[1] := (TSL2591_CMD | TSL2591_CMD_NORMAL) | (register & %11111)

  i2c.start
  i2c.pwrite (@cmd_packet, 2)
  i2c.stop

PUB CommandWords(register, high_word, low_word) | cmd_packet[2]

  cmd_packet.byte[0] := TSL2591_SLAVE|W
  cmd_packet.byte[1] := (TSL2591_CMD | TSL2591_CMD_NORMAL) | (register & %11111)
  cmd_packet.word[1] := low_word
  cmd_packet.word[2] := high_word

  i2c.start
  _ackbit := i2c.pwrite (@cmd_packet, 6)
  i2c.stop

PUB SpecialFunc(func) | cmd_packet
'Set/clear interrupts
' %00100: Force Interrupt
' %00110: Clear ALS Interrupt
' %00111: Clear ALS and No-Persist Interrupt
' %01010: Clear No-Persist Interrupt
'  Other values ignored
  case func
    TSL2591_CMD_SPECIAL_FORCEINT:
      cmd_packet.byte[0] := TSL2591_SLAVE|W
      cmd_packet.byte[1] := (TSL2591_CMD | TSL2591_CMD_SPECIAL) | TSL2591_CMD_SPECIAL_FORCEINT

    TSL2591_CMD_SPECIAL_CLEARALSINT:
      cmd_packet.byte[0] := TSL2591_SLAVE|W
      cmd_packet.byte[1] := (TSL2591_CMD | TSL2591_CMD_SPECIAL) | TSL2591_CMD_SPECIAL_CLEARALSINT

    TSL2591_CMD_SPECIAL_CLEARALS_NOPERSIST_INT:
      cmd_packet.byte[0] := TSL2591_SLAVE|W
      cmd_packet.byte[1] := (TSL2591_CMD | TSL2591_CMD_SPECIAL) | TSL2591_CMD_SPECIAL_CLEARALS_NOPERSIST_INT

    TSL2591_CMD_SPECIAL_CLEAR_NOPERSIST_INT:
      cmd_packet.byte[0] := TSL2591_SLAVE|W
      cmd_packet.byte[1] := (TSL2591_CMD | TSL2591_CMD_SPECIAL) | TSL2591_CMD_SPECIAL_CLEAR_NOPERSIST_INT

    OTHER:
      return

  i2c.start
  i2c.pwrite (@cmd_packet, 2)
  i2c.stop

PUB Enable(NPIEN, SAI, AIEN, AEN, PON) | ena_byte
'Set Enable Register ($00) fields
'Power device on or off, enable functions, interrupts
' Bits  7: NPIEN  - No Persist Interrupt Enable
'       6: SAI    - Sleep After Interrupt
'       5: Reserved (write as 0, should read 0)
'       4: AIEN   - ALS Interrupt Enable
'    3..2: Reserved (write as 0, should read 0)
'       1: AEN    - ALS Enable
'       0: PON    - Power On
  ena_byte := ((NPIEN & 1) << 7) | ((SAI & 1) << 6) | ((AIEN & 1) << 4) | ((AEN & 1) << 1) | (PON & 1)
  Command (TSL2591_ENABLE)
  WriteByte (ena_byte)

PUB GetState: state
'Returns Enable Register ($00) contents
  Command (TSL2591_ENABLE)
  ReadByte (@state)

PUB GetNPIEN: npien 'XXX NOT SURE
'Gets No-Persist Interrupt ENable field
'Queries Enable Register and returns No-Persist Interrupt ENable field bit
  npien := (GetState >> 7) & 1

PUB GetSAI: sai
'Gets Sleep After Interrupt field
'Queries Enable Register and returns Sleep After Interrupt field bit
  sai := (GetState >> 6) & 1

PUB GetAIEN: aien
'Gets ALS Interrupt ENable field
'Queries Enable Register and returns ALS Interrupt ENable field bits
  aien := (GetState >> 4) & 1

PUB GetAEN: aen
'Gets ALS ENable field
'Queries Enable Register and returns ALS ENable field bit
  aen := (GetState >> 1) & 1

PUB GetPON: pon
'Gets Power ON field
'Queries Enable Register and returns Power ON field bit
  pon := GetState & 1

PUB Control(SRESET, AGAIN, ATIME) | ctrl_byte
'Set ALS Gain and ADC integration Time, and also provide System Reset
' SRESET - System Reset (= POR)
' AGAIN  - ALS Gain
' ATIME  - ALS Time/ADC Integration time

  ctrl_byte := ((SRESET & 1) << 7) | ((AGAIN & 3) << 4) | (ATIME & 5)
  Command ( TSL2591_CONFIG)
  WriteByte (ctrl_byte)

PUB GetControlReg: ctrl_reg
'Returns Control Register ($01) value
' Bits    7: SRESET - System Reset (self-clearing)
'         6: Reserved (should read 0)
'      5..4: AGAIN - ALS Gain
'         3: Reserved (should read 0)
'      2..0: ATIME - ADC integration Time
  Command (TSL2591_CONFIG)
  ReadByte (@ctrl_reg)

PUB GetGain: gain
'Returns gain setting for internal integration amplifiers
'Queries Control Register and returns bits 5..4
' Bits 5..4:
'       %00: Low-gain
'       %01: Medium-gain
'       %10: High-gain
'       %11: Max-gain
  byte[gain] := (GetControlReg >> 4) & %11

PUB GetATime: a_time
'Returns ADC Integration time (both channels)
'Queries Control Register and returns bits 2..0
' Val   Int time  Max Count
' %000  100ms     37888
' %001  200ms     65535
' %010  300ms     65535
' %011  400ms     65535
' %100  500ms     65535
' %101  600ms     65535
  byte[a_time] := GetControlReg & %111

PUB SetALS_IntThresh(low_threshold_word, high_threshold_word) | als_long 'XXX Change order of params to match return from GetALS?
'Sets ALS threshold values/registers ($04..$07)
' low_threshold_word - Low threshold
' high_threshold_word - high threshold
  if low_threshold_word < 0 or low_threshold_word > 65535 or high_threshold_word < 0 or high_threshold_word > 65535
    return
  CommandWords (TSL2591_AILTL, high_threshold_word, low_threshold_word)

PUB GetALS_IntThresh: threshold | als_long
'Gets ALS threshold values currently set
' Bits 31..16: AIHTH_AIHTL - High threshold word
'      15..0: AILTH_AILTL - Low threshold word
  Command (TSL2591_AILTL)
  ReadLong (@threshold)

PUB SetNPALS_IntThresh(nopersist_low_threshold_word, nopersist_high_threshold_word) | npals_long
'Sets no-persist ALS threshold values/registers ($08..$0B)
' nopersist_low_threshold_word - No-persist low threshold
' nopersist_high_threshold_word - No-persist high threshold
  if nopersist_low_threshold_word < 0 or nopersist_low_threshold_word > 65535 or nopersist_high_threshold_word < 0 or nopersist_high_threshold_word > 65535
    return
  CommandWords (TSL2591_NPAILTL, nopersist_high_threshold_word, nopersist_low_threshold_word)

PUB GetNPALS_IntThresh: threshold | npals_long
'Gets no-persist ALS threshold values currently set
' Bits 31..16: NPAIHTH_NPAIHTL - High threshold word
'      15..0: NPAILTH_NPAILTL - Low threshold word
  Command (TSL2591_NPAILTL)
  ReadLong (@threshold)

PUB GetPersist: cycles
'Gets currently set number of consecutive out-of-range ALS cycles necessary to generate an interrupt
' Bits 7..4: Reserved (write as 0, should read 0)
'      3..0: APERS - Number of cycles
'       0000: Generate interrupt every ALS cycle, regardless
'       0001: Generate interrupt anytime value goes outside threshold range/OOR
'       0010: Generate interrupt when there have been 2 consecutive values OOR
'       0011: 3
'       0100: 5
'        .. : 10, 15, 20, 25, 30, 35, 40, 45, 50, 55
'       1111: 60
  Command (TSL2591_PERSIST)
  ReadByte (@cycles) 'No bounds checking/clamping to lower 4 bits...should there be?

PUB SetPersist(cycles)
'Sets Persist register ($0C)
'Sets number of consecutive out-of-range ALS cycles necessary to generate an interrupt
' Bits 7..4: Reserved (write as 0, should read 0)
'      3..0: APERS - Number of cycles
'       0000: Generate interrupt every ALS cycle, regardless
'       0001: Generate interrupt anytime value goes outside threshold range/OOR
'       0010: Generate interrupt when there have been 2 consecutive values OOR
'       0011: 3
'       0100: 5
'        .. : 10, 15, 20, 25, 30, 35, 40, 45, 50, 55
'       1111: 60
  if cycles < 0 or cycles > 15
    return
  Command (TSL2591_PERSIST)
  WriteByte (cycles)

PUB GetPackageID: package_id
'Returns Package ID register ($11)
' Bits 7..6: Reserved (should be 0)
'      5..4: Package ID
'      3..0: Reserved (should be 0)
  Command (TSL2591_PID)
  ReadByte (@package_id)

PUB GetDeviceID: device_id
'Returns Device ID register ($12)
'Should return $50
' Bits 7..0: ID
  Command (TSL2591_ID)
  ReadByte (@device_id)

PUB Status: dev_status
'Returns contents of Status register ($13)
' Bits 7..6: Reserved (should be 0)
'         5: NPINTR - Indicates No-persist interrupt
'         4: AINT - Indicates ALS interrupt
'      3..1: Reserved (should be 0)
'         0: AVALID - Indicates ADCs completed integration cycle since AEN bit was set
  Command (TSL2591_STATUS)
  ReadByte (@dev_status)

PUB GetVisible
'Returns Visible light data portion of last ALS data read
  return _als_data.word[0] & $FFFF

PUB GetIR
'Returns IR light data portion of last ALS data read
  return _als_data.word[1] & $FFFF

PUB GetALS_Data
'Gets data from ALS registers ($14..$17)
'Reads ALS data from both channels
' Bits 31..16/Most-significant word contain the IR data
' Bits  15..0/Least-significant word contain the Visible light data
  Command (TSL2591_C0DATAL)
  ReadLong (@_als_data)
  return _als_data

PUB ReadByte(ptr_byte)
'Reads one byte from the TSL2591
  i2c.start
  _ackbit := i2c.write (TSL2591_SLAVE|R)
  i2c.pread (ptr_byte, 1, TRUE)
  i2c.stop

PUB ReadWord(ptr_word) | raw_data
'Reads two bytes from the TSL2591
  i2c.start
  _ackbit := i2c.write (TSL2591_SLAVE|R)
  i2c.pread (@raw_data, 2, TRUE)
  i2c.stop
  {word}long[ptr_word] := raw_data.word[0]

PUB ReadLong(ptr_long) | raw_data
'Reads four bytes from the TSL2591
  i2c.start
  _ackbit := i2c.write (TSL2591_SLAVE|R)
  i2c.pread (@raw_data, 4, TRUE)
  i2c.stop
  long[ptr_long] := raw_data

PUB WriteByte(data_byte)
'Writes one byte to the TSL2591
  i2c.start
  i2c.write (TSL2591_SLAVE|W)
  _ackbit := i2c.write (data_byte)
  i2c.stop

PUB WriteLong(data_long) | byte_part
'Writes four bytes (packed into one long) to the TSL2591
  i2c.start
  i2c.write (TSL2591_SLAVE|W)
  _ackbit := i2c.pwrite (@data_long, 4)
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
