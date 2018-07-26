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
'   - Use CASE for specific allowed values, limit minimum/maximum for sequential ranges (WIP)
'   - Use proper boolean values for methods that return boolean values (i.e., -1 for TRUE, 0 for FALSE) (WIP)
'   - Separate methods for
'     Getting "processed" values, i.e., return parsed units. e.g., GetPersist would return 30 (WIP)
'     Getting "unprocessed" values, i.e., return raw value from device. e.g., GetPersist_raw might return %1001 (WIP)
' Break Special Function/Interrupt settings into separate methods (WIP)
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
'Kills I2C cog
  i2c.terminate

PUB CheckAINT: bool__ALS_interrupt
'Indicates ALS interrupt
'Bit 4 of STATUS register
  bool__ALS_interrupt := ((GetStatusReg >> 4) & %1) * -1

PUB CheckNPINT: bool__NPALS_interrupt
'Indicates No-persist interrupt
'Bit 5 of STATUS register
  bool__NPALS_interrupt := ((GetStatusReg >> 5) & %1) * -1

PUB ClearALS_INT
'Clears ALS Interrupt
  SetSpecialFunc (tsl2591#SPECFUNC_CLEARALSINT)

PUB ClearALL_INTs
'Clears both ALS and NPALS Interrupts
  SetSpecialFunc (tsl2591#SPECFUNC_CLEARALS_NOPERSIST_INT)

PUB ClearNPALS_INT
'Clears NPALS Interrupt
  SetSpecialFunc (tsl2591#SPECFUNC_CLEAR_NOPERSIST_INT)

PUB ForceINT
'Force an ALS Interrupt
'NOTE: Per TLS2591 Datasheet, for an interrupt to be visible on the INT pin,
' one of the interrupt enable bits in the ENABLE ($00) register must be set
  SetSpecialFunc (tsl2591#SPECFUNC_FORCEINT)

PUB GetAEN: bool__ALS_Enabled
'Gets ALS ENable field
'Queries Enable Register and returns ALS ENable field bit
  bool__ALS_Enabled := (GetEnableReg >> 1) & 1

PUB GetAIEN: bool__ALS_interrupt_enabled
'Gets ALS Interrupt ENable field
'Queries Enable Register and returns ALS Interrupt ENable field bits
  bool__ALS_interrupt_enabled := (GetEnableReg >> 4) & 1

PUB GetALSData_Full: word__ALS_fullspectrum_data
'Returns Full-spectrum light data portion of last ALS data read
  word__ALS_fullspectrum_data := _als_data.word[0] & $FFFF

PUB GetALSData_IR: word__ALS_IR_data
'Returns IR light data portion of last ALS data read
  word__ALS_IR_data := _als_data.word[1] & $FFFF

PUB GetALS_IntThreshReg: long__threshold | als_long
'Gets ALS threshold values currently set
' Bits 31..16: AIHTH_AIHTL - High threshold word
'      15..0: AILTH_AILTL - Low threshold word
  Command (tsl2591#REG_AILTL)
  ReadLong (@long__threshold)

PUB GetALSDataReg: long__ALS_data
'Gets data from ALS registers ($14..$17)
'Reads ALS data from both channels
' Bits 31..16/Most-significant word contain the IR data
' Bits  15..0/Least-significant word contain the Full light data
  Command (tsl2591#REG_C0DATAL)
  ReadLong (@_als_data)
  long__ALS_data := _als_data

PUB GetALSPersist: apers_cycles
'Returns Interrupt persistence filter value
'Queries the PERSIST register and returns the number of consecutive cycles necessary to generate an interrupt
  apers_cycles := GetPersistReg
  case apers_cycles
    %0000..%0011: return apers_cycles
    %0100: return 5
    %0101: return 10
    %0110: return 15
    %0111: return 20
    %1000: return 25
    %1001: return 30
    %1010: return 35
    %1011: return 40
    %1100: return 45
    %1101: return 50
    %1110: return 55
    %1111: return 60
    OTHER: return 0

PUB GetAIntegrationTime: a_time_ms
'Returns ADC Integration time (both channels)
'Queries CONTROL Register and returns ADC Integration time in milliseconds
  long[a_time_ms] := ((GetControlReg & %111) + 1) * 100

PUB GetAIntegrationTimeRaw: a_time
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

PUB GetControlReg: ctrl_reg
'Returns Control Register ($01) value
' Bits    7: SRESET - System Reset (self-clearing)
'         6: Reserved (should read 0)
'      5..4: AGAIN - ALS Gain
'         3: Reserved (should read 0)
'      2..0: ATIME - ADC integration Time
  Command (tsl2591#REG_CONFIG)
  ReadByte (@ctrl_reg)

PUB GetDeviceIDReg: device_id
'Returns Device ID register ($12)
'Should return $50
' Bits 7..0: ID
  Command (tsl2591#REG_ID)
  ReadByte (@device_id)

PUB GetEnableReg: state
'Returns Enable Register ($00) contents
  Command (tsl2591#REG_ENABLE)
  ReadByte (@state)

PUB GetGain: gain
'Returns gain setting for internal integration amplifiers
'Queries Control Register and returns bits 5..4
' Bits 5..4:
'       %00: Low-gain
'       %01: Medium-gain
'       %10: High-gain
'       %11: Max-gain
  byte[gain] := (GetControlReg >> 4) & %11

PUB GetNPALS_IntThreshReg: threshold | npals_long
'Gets no-persist ALS threshold values currently set
' Bits 31..16: NPAIHTH_NPAIHTL - High threshold word
'      15..0: NPAILTH_NPAILTL - Low threshold word
  Command (tsl2591#REG_NPAILTL)
  ReadLong (@threshold)

PUB GetNPIEN: bool__NP_interrupt_enabled
'Gets No-Persist Interrupt ENable field
'Queries Enable Register and returns No-Persist Interrupt ENable field bit
  bool__NP_interrupt_enabled := ((GetEnableReg >> 7) & 1) * -1

PUB GetPersistReg: cycles
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
  Command (tsl2591#REG_PERSIST)
  ReadByte (@cycles) 'No bounds checking/clamping to lower 4 bits...should there be?

PUB GetPackageIDReg: package_id
'Returns Package ID register ($11)
' Bits 7..6: Reserved (should be 0)
'      5..4: Package ID
'      3..0: Reserved (should be 0)
  Command (tsl2591#REG_PID)
  ReadByte (@package_id)

PUB GetPON: pon
'Gets Power ON field
'Queries Enable Register and returns Power ON field bit
  pon := GetStatusReg & 1

PUB GetSAI: sai
'Gets Sleep After Interrupt field
'Queries Enable Register and returns Sleep After Interrupt field bit
  sai := (GetEnableReg >> 6) & 1

PUB GetStatusReg: dev_status
'Returns contents of Status register ($13)
' Bits 7..6: Reserved (should be 0)
'         5: NPINTR - Indicates No-persist interrupt
'         4: AINT - Indicates ALS interrupt
'      3..1: Reserved (should be 0)
'         0: AVALID - Indicates ADCs completed integration cycle since AEN bit was set
  Command (tsl2591#REG_STATUS)
  ReadByte (@dev_status)

PUB IsAValid: bool__adc_valid
'ALS data valid.
'Indicates ADCs completed integration cycle since AEN bit was set
' Bit 0 of Status register
  if GetStatusReg & 1
    return TRUE
  else
    return FALSE

PUB PowerOn(bool__powered) | npien, sai, aien, aen
'Power ON
'1 or TRUE activates internal osc
'0 or FALSE disables the osc
  case ||bool__powered
    0..1: bool__powered &= 1
    OTHER: bool__powered := 0

  npien := GetNPIEN
  sai := GetSAI
  aien := GetAIEN
  aen := GetAEN

  SetEnableReg (NPIEN, SAI, AIEN, AEN, bool__powered)

PUB Probe_TSL2591 | check, device_id', package_id
'Probes I2C Bus for device ACK, and if there is a response,
' query the device for the ID register, which should return $50.
'Returns TRUE only if *both* conditions are satisfied
  i2c.start
  check := i2c.write(TSL2591_SLAVE)
  i2c.stop

'  package_id := GetPackageIDReg
  device_id := GetDeviceIDReg

  if (check == i2c#ACK) AND (device_id == $50)
    return TRUE
  else
    return FALSE

PUB Reset
' Resets the TSL2591
' Sets SRESET/System Reset field in CONTROL register. Equivalent to Power-On Reset
' Field is self-clearing
  SetControlReg (1, 0, 0)

PUB SetALS_IntThreshReg(low_threshold_word, high_threshold_word) | als_long 'XXX Change order of params to match return from GetALS?
'Sets ALS threshold values/registers ($04..$07)
' low_threshold_word - Low threshold
' high_threshold_word - high threshold
  if low_threshold_word < 0 or low_threshold_word > 65535 or high_threshold_word < 0 or high_threshold_word > 65535
    return
  CommandWords (tsl2591#REG_AILTL, high_threshold_word, low_threshold_word)

PUB SetAIntegrationTime(integration_time_ms) | again
'Sets ADC Integration Time, in ms
  case integration_time_ms
    100, 200, 300, 400, 500, 600:
      integration_time_ms := (integration_time_ms / 100) - 1
    OTHER: integration_time_ms := %000    'Default to 100ms

  again := GetGain                        'We're only setting one field in a multi-field register, so we want to
                                          'preserve the current settings of the other fields not being modified.
  SetControlReg (0, again, integration_time_ms)

PUB SetControlReg(SRESET, AGAIN, ATIME) | ctrl_byte
'Set ALS Gain and ADC integration Time, and also provide System Reset
' SRESET - System Reset (= POR)
' AGAIN  - ALS Gain
' ATIME  - ALS Time/ADC Integration time

  ctrl_byte := ((SRESET & 1) << 7) | ((AGAIN & 3) << 4) | (ATIME & 5)
  Command (tsl2591#REG_CONFIG)
  WriteByte (ctrl_byte)

PUB SetEnableReg(NPIEN, SAI, AIEN, AEN, PON) | ena_byte
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
  Command (tsl2591#REG_ENABLE)
  WriteByte (ena_byte)

PUB SetGainRaw(gain_mode) | atime
'Sets amplifier gain (affects both channels)
  case gain_mode
    GAIN_LOW..GAIN_MAX: gain_mode <<= 4
    OTHER: gain_mode := %00 << 4

  atime := GetAIntegrationTime        'We're only setting one field in a multi-field register, so we want to
                                      'preserve the current settings of the other fields not being modified.
  SetControlReg (0, gain_mode, ATIME)

PUB SetNPALS_IntThreshReg(nopersist_low_threshold_word, nopersist_high_threshold_word) | npals_long
'Sets no-persist ALS threshold values/registers ($08..$0B)
' nopersist_low_threshold_word - No-persist low threshold
' nopersist_high_threshold_word - No-persist high threshold
  if nopersist_low_threshold_word < 0 or nopersist_low_threshold_word > 65535 or nopersist_high_threshold_word < 0 or nopersist_high_threshold_word > 65535
    return
  CommandWords (tsl2591#REG_NPAILTL, nopersist_high_threshold_word, nopersist_low_threshold_word)

PUB SetNPINT(npi_enabled) | sai, aien, aen, pon
'Enables or disables No-Persist Interrupts
  case ||npi_enabled
    0..1: npi_enabled <<= 7
    OTHER: npi_enabled := 0

  sai := GetSAI
  aien := GetAIEN
  aen := GetAEN
  pon := GetPON
  SetEnableReg (npi_enabled, SAI, AIEN, AEN, PON)

PUB SetPersistReg(cycles)
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
  case cycles
    0..15:
      Command (tsl2591#REG_PERSIST)
      WriteByte (cycles)
    OTHER:
      return

PUB SetSAI(bool__sleep_after_interrupt) | npien, aien, aen, pon
'Enable Sleep After Interrupt
'Enable or Disable Sleeping after an Interrupt is asserted
  case ||bool__sleep_after_interrupt
    0..1: bool__sleep_after_interrupt &= 1
    OTHER: bool__sleep_after_interrupt := 0

  npien := GetNPIEN
  aien := GetAIEN
  aen := GetAEN
  pon := GetPON

  SetEnableReg (NPIEN, bool__sleep_after_interrupt, AIEN, AEN, PON)

PUB SetSpecialFunc(func) | cmd_packet
'Set/clear interrupts
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

PUB Command(register) | cmd_packet
'Send device Command
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

PUB CommandWords(register, low_word, high_word) | cmd_packet[2]
'Send device Command, then two words of data, LSW first
'This was created specially for the SetALS_IntThreshReg and SetNPALS_IntThreshReg methods
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
'Reads one byte from the TSL2591
  i2c.start
  _ackbit := i2c.write (TSL2591_SLAVE|R)
  i2c.pread (ptr_byte, 1, TRUE)
  i2c.stop

PRI ReadLong(ptr_long) | raw_data
'Reads four bytes from the TSL2591
  i2c.start
  _ackbit := i2c.write (TSL2591_SLAVE|R)
  i2c.pread (@raw_data, 4, TRUE)
  i2c.stop
  long[ptr_long] := raw_data

PRI ReadWord(ptr_word) | raw_data
'Reads two bytes from the TSL2591
  i2c.start
  _ackbit := i2c.write (TSL2591_SLAVE|R)
  i2c.pread (@raw_data, 2, TRUE)
  i2c.stop
  {word}long[ptr_word] := raw_data.word[0]

PRI WriteLong(data_long) | byte_part
'Writes four bytes (packed into one long) to the TSL2591
  i2c.start
  i2c.write (TSL2591_SLAVE|W)
  _ackbit := i2c.pwrite (@data_long, 4)
  i2c.stop

PRI WriteByte(data_byte)
'Writes one byte to the TSL2591
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
