{
    --------------------------------------------
    Filename:
    Author:
    Copyright (c) 20__
    See end of file for terms of use.
    --------------------------------------------
}

CON

  TSL2591_SLAVE = $52
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
  TSL_CMD_TRANSACTION_NORMAL  = %01
  TSL_CMD_TRANSACTION_SPECIAL = %11
  
  TSL_CMD_ADDR_SF_FORCEINT    = %00100
  TSL_CMD_ADDR_SF_CLEARALSINT = %00110
  TSL_CMD_ADDR_SF_CLEARALS_NOPERSIST_INT  = %00111
  TSL_CMD_ADDR_SF_CLEAR_NOPERSIST_INT     = %01010

VAR


OBJ

  i2c : "jm_i2c_fast"

PUB null
''This is not a top-level object

PUB Start(I2C_SCL, I2C_SDA, I2C_HZ): okay

  I2C_HZ := I2C_HZ <# 400_000                   'Clamp I2C clock to TSL2591 maximum spec
  okay := i2c.setupx (I2C_SCL, I2C_SDA, I2C_HZ)
  ifnot okay
    return

PUB Command(transaction, addr_sf) | i, j
'Trans 6..5 01 nml, 11 spec_func

PUB Enable(NPIEN, SAI, AIEN, AEN, PON)
' NPIEN 7
' SAI 6
' RES 5 (0)
' AIEN 4
' RES 3..2 (0)
' AEN 1
' PON 0

PUB Control(SRESET, AGAIN, ATIME)
' SRESET 7
' RES 6 (0)
' AGAIN 5..4
' RES 3 (0)
' ATIME 2..0

PUB ALS_IntThresh(ALS_LOW, ALS_HIGH, NPALS_LOW, NPALS_HIGH)
' ALS: AILTL..AILTH low thresh, AIHTL..AIHTH high thresh
' NPALS: No-persist ALS

PUB Persist(APERS)
' RES 7..4 (0)
' APERS 3..0:
'   0000: Every ALS cycle gen int
'   0001: Any val outside thresh
'   0010: 2 consecutive values OOR
'   0011: 3
'   0100: 5
'   ..  : 10, 15, 20, 25, 30, 35, 40, 45, 50, 55
'   1111: 60

PUB PID: PACKAGEID
' RO
' RES 7..6
' PID 5..4
' RES 3..0

PUB ID: DEVICEID
' RO
' ID 7..0

PUB Status: DEVSTATUS
' RO
' RES 7..6
' NPINTR 5
' AINT 4
' RES 3..1
' AVALID 0

PUB ALS_Data
' C0DATAL
' C0DATAH
' C1DATAL
' C1DATAH
' Read 4 bytes

PRI


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
