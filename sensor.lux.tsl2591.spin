{
    --------------------------------------------
    Filename:
    Author:
    Copyright (c) 20__
    See end of file for terms of use.
    --------------------------------------------
}

CON

  TSL2591_SLAVE = $29 << 1
  W             = %0
  R             = %1
  
  TSL_ENABLE    = $00
  TSL_CONFIG    = $01
  TSL_AILTL     = $04
  TSL_AILTH     = $05
  TSL_AIHTL     = $06
  TSL_AIHTH     = $07
  TSL_NPAILTL   = $08
  TSL_NPAILTH   = $09
  TSL_NPAIHTL   = $0A
  TSL_NPAIHTH   = $0B
  TSL_PERSIST   = $0C
  TSL_PID       = $11
  TSL_ID        = $12
  TSL_STATUS    = $13
  TSL_C0DATAL   = $14
  TSL_C0DATAH   = $15
  TSL_C1DATAL   = $16
  TSL_C1DATAH   = $17

'Select Command Register
  TSL_CMD       = %1000_0000
'Select type of transaction to follow in subsequent data transfers
  TSL_CMD_TRANSACTION_NORMAL  = %01 << 5
  TSL_CMD_TRANSACTION_SPECIAL = %11 << 5
'Special function field - use if TSL_CMD_TRANSACTION_SPECIAL bits above are set
  TSL_CMD_ADDR_SF_FORCEINT    = %00100
  TSL_CMD_ADDR_SF_CLEARALSINT = %00110
  TSL_CMD_ADDR_SF_CLEARALS_NOPERSIST_INT  = %00111
  TSL_CMD_ADDR_SF_CLEAR_NOPERSIST_INT     = %01010

VAR

  byte  _ackbit
  long  _nak
  long  _monitor_stack[100]
  long  _als_data

OBJ

  i2c   : "jm_i2c_fast"

PUB Null
' This is not a top-level object

PUB Start(I2C_SCL, I2C_SDA, I2C_HZ): okay

  okay := i2c.setupx (I2C_SCL, I2C_SDA, I2C_HZ)

PUB Stop

  i2c.terminate

PUB Find_TSL | check, device_id', package_id

  i2c.start
  check := i2c.write(TSL2591_SLAVE)
  i2c.stop

'  package_id := PID
  device_id := ID


  if (check == i2c#ACK) AND (device_id == $50)
    return TRUE
  else
    return FALSE

PUB Command(register) | cmd_packet
'Trans 6..5 01 nml, 11 spec_func
  cmd_packet.byte[0] := TSL2591_SLAVE|W
  cmd_packet.byte[1] := (TSL_CMD | TSL_CMD_TRANSACTION_NORMAL) | register

  i2c.start
  i2c.pwrite (@cmd_packet, 2)
  i2c.stop

PUB SpecialFunc(func) | cmd_packet

  case func
    TSL_CMD_ADDR_SF_FORCEINT:
      cmd_packet.byte[0] := TSL2591_SLAVE|W
      cmd_packet.byte[1] := (TSL_CMD | TSL_CMD_TRANSACTION_SPECIAL) | TSL_CMD_ADDR_SF_FORCEINT

    TSL_CMD_ADDR_SF_CLEARALSINT:
      cmd_packet.byte[0] := TSL2591_SLAVE|W
      cmd_packet.byte[1] := (TSL_CMD | TSL_CMD_TRANSACTION_SPECIAL) | TSL_CMD_ADDR_SF_CLEARALSINT

    TSL_CMD_ADDR_SF_CLEARALS_NOPERSIST_INT:
      cmd_packet.byte[0] := TSL2591_SLAVE|W
      cmd_packet.byte[1] := (TSL_CMD | TSL_CMD_TRANSACTION_SPECIAL) | TSL_CMD_ADDR_SF_CLEARALS_NOPERSIST_INT

    TSL_CMD_ADDR_SF_CLEAR_NOPERSIST_INT:
      cmd_packet.byte[0] := TSL2591_SLAVE|W
      cmd_packet.byte[1] := (TSL_CMD | TSL_CMD_TRANSACTION_SPECIAL) | TSL_CMD_ADDR_SF_CLEAR_NOPERSIST_INT

    OTHER:
      return

  i2c.start
  i2c.pwrite (@cmd_packet, 2)
  i2c.stop

PUB Enable(NPIEN, SAI, AIEN, AEN, PON) | ena_byte
' NPIEN 7
' SAI 6
' RES 5 (0)
' AIEN 4
' RES 3..2 (0)
' AEN 1
' PON 0
  ena_byte := ((NPIEN & 1) << 7) | ((SAI & 1) << 6) | ((AIEN & 1) << 4) | ((AEN & 1) << 1) | (PON & 1)
  Command (TSL_ENABLE)
  WriteByte (ena_byte)

PUB Control(SRESET, AGAIN, ATIME) | ctrl_byte
' SRESET 7
' RES 6 (0)
' AGAIN 5..4
' RES 3 (0)
' ATIME 2..0
  ctrl_byte := ((SRESET & 1) << 7) | ((AGAIN & 3) << 4) | (ATIME & 5)
  Command ( TSL_CONFIG)
  WriteByte (ctrl_byte)

PUB SetALS_IntThresh(AILTL, AILTH, AIHTL, AIHTH) | als_long
' ALS: AILTL..AILTH low thresh, AIHTL..AIHTH high thresh
  als_long := (AILTL << 24) | (AILTH << 16) | (AIHTL << 8) | AIHTH
  Command (TSL_AILTL)
  WriteLong (als_long)

PUB SetNPALS_IntThresh(NPAILTL, NPAILTH, NPAIHTL, NPAIHTH) | npals_long
' NPALS: No-persist ALS
  npals_long := (NPAILTL << 24) | (NPAILTH << 16) | (NPAIHTL << 8) | NPAIHTH
  Command ( TSL_NPAILTL)
  WriteLong (npals_long)

PUB GetPersist(APERS)
' RES 7..4 (0)
' APERS 3..0:
'   0000: Every ALS cycle gen int
'   0001: Any val outside thresh
'   0010: 2 consecutive values OOR
'   0011: 3
'   0100: 5
'   ..  : 10, 15, 20, 25, 30, 35, 40, 45, 50, 55
'   1111: 60
  Command ( TSL_PERSIST)
  ReadByte (@APERS) 'No bounds checking/clamping to lower 4 bits...should there be?

PUB SetPersist(APERS)
' RES 7..4 (0)
' APERS 3..0:
'   0000: Every ALS cycle gen int
'   0001: Any val outside thresh
'   0010: 2 consecutive values OOR
'   0011: 3
'   0100: 5
'   ..  : 10, 15, 20, 25, 30, 35, 40, 45, 50, 55
'   1111: 60
  Command ( TSL_PERSIST)
  WriteByte ((||APERS) <# $0F)  'Take absolute value and clamp to 15/$0F

PUB PID: PACKAGEID
' RO
' RES 7..6
' PID 5..4
' RES 3..0
  Command (TSL_PID)
  ReadByte (@PACKAGEID)

PUB ID: DEVICEID
' RO
' ID 7..0
  Command (TSL_ID)
  ReadByte (@DEVICEID)

PUB Status: DEVSTATUS
' RO
' RES 7..6
' NPINTR 5
' AINT 4
' RES 3..1
' AVALID 0
  Command (TSL_STATUS)
  ReadByte (@DEVSTATUS)

PUB GetVisible | vis_word

  vis_word := (_als_data & $FFFF) - (_als_data.word[1])'_als_data >> 16)
  return _als_data.word[0]

PUB GetIR | als_long

  return _als_data.word[1] & $FFFF

PUB GetALS_Data
' C0DATAL
' C0DATAH
' C1DATAL
' C1DATAH
' Read 4 bytes
  Command (TSL_C0DATAL)
  ReadLong (@_als_data)
  return _als_data

PUB ReadByte(register)

  i2c.start
  _ackbit := i2c.write (TSL2591_SLAVE|R)
  i2c.pread (register, 1, TRUE)
  i2c.stop

PUB ReadWord(register) | raw_data

  i2c.start
  _ackbit := i2c.write (TSL2591_SLAVE|R)
  i2c.pread (@raw_data, 2, TRUE)
  i2c.stop
'  ser.NewLine
'  ser.Hex (raw_data, 4)
'  ser.NewLine
  word[register] := raw_data.word[0]
'  byte[register][0] := raw_data.byte[1]
'  byte[register][1] := raw_data.byte[0]

PUB ReadLong(register) | raw_data

  i2c.start
  _ackbit := i2c.write (TSL2591_SLAVE|R)
  i2c.pread (@raw_data, 4, TRUE)
  i2c.stop

  long[register] := raw_data
'  byte[register][0] := raw_data.byte[3]
'  byte[register][1] := raw_data.byte[2]
'  byte[register][2] := raw_data.byte[1]
'  byte[register][3] := raw_data.byte[0]

PUB WriteByte(data_byte)

  i2c.start
  i2c.write (TSL2591_SLAVE|W)
  _ackbit := i2c.write (data_byte)
  i2c.stop

PUB WriteLong(data_long) | byte_part

  i2c.start
  i2c.write (TSL2591_SLAVE|W)
'  _ackbit := i2c.write (data_byte)
  _ackbit := i2c.pwrite (data_long, 4)
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
