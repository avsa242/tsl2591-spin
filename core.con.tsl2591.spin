x{
    --------------------------------------------
    Filename: core.con.tsl2591.spin
    Description: TSL2591 low-level constants
    Author: Jesse Burt
    Copyright (c) 2018
    Started Feb 17, 2018
    Updated Feb 24, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    I2C_MAX_FREQ                    = 400_000   ' Max I2C Clock, per TSL2591 datasheet
    SLAVE_ADDR                      = $29 << 1  ' Hardcoded - no address option for this device
' Registers (fields within registers are indented)
    REG_ENABLE                      = $00
        NPIEN                       = 7         ' No-Persist Interrupts Enabled
        SAI                         = 6         ' Sleep After Interrupt
        AIEN                        = 4         ' Persist Interrupts Enabled
        AEN                         = 1         ' ALS Enable
        PON                         = 0         ' Power On
    REG_CONTROL                     = $01
        SRESET                      = 7         ' System Reset
        AGAIN                       = 4         ' ALS Gain
        AGAIN_MASK                  = %11
        ATIME                       = 0         ' ALS time
        ATIME_MASK                  = %111
    REG_AILTL                       = $04
    REG_AILTH                       = $05
    REG_AIHTL                       = $06
    REG_AIHTH                       = $07
    REG_NPAILTL                     = $08
    REG_NPAILTH                     = $09
    REG_NPAIHTL                     = $0A
    REG_NPAIHTH                     = $0B
    REG_PERSIST                     = $0C
        APERS_MASK                  = %1111     ' ALS Interrupt Persistence filter
    REG_PID                         = $11       ' Package Identification
        PID                         = 4
        PID_MASK                    = %11
    REG_ID                          = $12       ' Device Identification
    REG_STATUS                      = $13       ' Internal Status
        NPINTR                      = 5
        AINT                        = 4
        AVALID                      = 0
    REG_C0DATAL                     = $14       ' ALS Light Data (Ch0 Low byte)
    REG_C0DATAH                     = $15       ' ALS Light Data (Ch0 Hi byte)
    REG_C1DATAL                     = $16       ' ALS Light Data (Ch1 Low byte)
    REG_C1DATAH                     = $17       ' ALS Light Data (Ch1 Hi byte)
    
    
    TSL2591_CMD                     = %1000_0000' Select Command Register
    
    TRANS_TYPE_NORMAL               = %0010_0000' Select type of transaction to follow in subsequent data transfers
    TRANS_TYPE_SPECIAL              = %0110_0000' ( | or together with TSL2591_CMD)
    
    SPECFUNC_FORCEINT               =     %00100' Special
    SPECFUNC_CLEARALSINT            =     %00110' function
    SPECFUNC_CLEARALS_NOPERSIST_INT =     %00111' fields
    SPECFUNC_CLEAR_NOPERSIST_INT    =     %01010'  - use if TRANS_TYPE_SPECIAL bits above are set

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
