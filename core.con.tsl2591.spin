{
    --------------------------------------------
    Filename: core.con.tsl2591.spin
    Description: Register map for TSL2591
    Author: Jesse Burt
    Copyright (c) 2018
    See end of file for terms of use.
    --------------------------------------------
}

CON

  TSL2591_SLAVE                   = $29 << 1
  W                               = %0
  R                               = %1
  I2C_MAX_RATE                    = 400_000   'Max I2C Clock, per TSL2591 datasheet

  REG_ENABLE                      = $00
  REG_CONFIG                      = $01
  REG_AILTL                       = $04
  REG_AILTH                       = $05
  REG_AIHTL                       = $06
  REG_AIHTH                       = $07
  REG_NPAILTL                     = $08
  REG_NPAILTH                     = $09
  REG_NPAIHTL                     = $0A
  REG_NPAIHTH                     = $0B
  REG_PERSIST                     = $0C
  REG_PID                         = $11
  REG_ID                          = $12
  REG_STATUS                      = $13
  REG_C0DATAL                     = $14
  REG_C0DATAH                     = $15
  REG_C1DATAL                     = $16
  REG_C1DATAH                     = $17

'Select Command Register
  TSL2591_CMD                     = %1000_0000
'Select type of transaction to follow in subsequent data transfers
  TRANS_TYPE_NORMAL               =  %01      << 5
  TRANS_TYPE_SPECIAL              =  %11      << 5
'Special function field - use if TSL2591_CMD_SPECIAL bits above are set
  SPECFUNC_FORCEINT               =     %00100
  SPECFUNC_CLEARALSINT            =     %00110
  SPECFUNC_CLEARALS_NOPERSIST_INT =     %00111
  SPECFUNC_CLEAR_NOPERSIST_INT    =     %01010

PUB Null
' This is not a top-level object

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
