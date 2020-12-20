{
    --------------------------------------------
    Filename: TSL2591-Demo.spin
    Description: Demo of the TSL2591 driver
    Author: Jesse Burt
    Copyright (c) 2020
    Started Nov 23, 2019
    Updated Dec 20, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-modifiable constants
    LED         = cfg#LED1
    SER_BAUD    = 115_200

    I2C_SCL     = 28
    I2C_SDA     = 29
    I2C_HZ      = 400_000                       ' max is 400_000

    GA          = 1                             ' Glass attenuation factor
    DF          = 408                           ' Device factor
' --

    LBL_COL     = 0
    DAT_COL     = 20
    PADDING     = 6

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    int     : "string.integer"
    time    : "time"
    tsl2591 : "sensor.lux.tsl2591.i2c"

PUB Main{} | atime_ms, againx, Lux1, cpl, ch0, ch1, scale

    setup{}

    scale := 1_000
    atime_ms := tsl2591.integrationtime(-2)
    againx:= tsl2591.gain(-2)
    cpl := ((atime_ms * againx) * scale) / (GA * DF)

    ser.position(LBL_COL, 4)
    ser.str(string("Integration time: "))
    ser.positionx(DAT_COL)
    ser.dec(atime_ms)
    ser.newline{}

    ser.str(string("Gain: "))
    ser.positionx(DAT_COL)
    ser.dec(AGAINx)
    ser.newline{}

    ser.str(string("Glass attenuation: "))
    ser.positionx(DAT_COL)
    ser.dec(GA)
    ser.newline{}

    ser.str(string("Device Factor: "))
    ser.positionx(DAT_COL)
    ser.dec(DF)
    ser.newline{}

    ser.str(string("Counts per Lux: "))
    ser.positionx(DAT_COL)
    ser.dec(CPL)
    ser.newline{}

    repeat
        repeat until tsl2591.dataready{}
        tsl2591.measure(tsl2591#BOTH)
        ch0 := tsl2591.lastfull{} * scale
        ch1 := tsl2591.lastir{} * scale
        lux1 := ((ch0 - ch1) * ((1 * scale) - (ch1 / ch0))) / cpl   ' XXX Unverified
        ser.position(LBL_COL, 10)
        ser.str(string("CH0: "))
        ser.positionx(DAT_COL)
        ser.str(int.decpadded(ch0 / scale, PADDING))
        ser.newline{}

        ser.str(string("CH1: "))
        ser.positionx(DAT_COL)
        ser.str(int.decpadded(ch1 / scale, PADDING))
        ser.newline{}

        ser.str(string("(CH0 - CH1): "))
        ser.positionx(DAT_COL)
        ser.str(int.decpadded((ch0 - ch1), PADDING))
        ser.newline{}

        ser.str(string("1 - (CH0 - CH1): "))
        ser.positionx(DAT_COL)
        ser.str(int.decpadded((1 * scale) - (ch1 / ch0), PADDING))
        ser.newline{}

        ser.str(string("Lux: "))
        ser.positionx(DAT_COL)
        decimaldot(lux1, scale)

PRI DecimalDot(scaled, divisor) | whole[4], part[4], places, tmp
' Display a fixed-point scaled up number in decimal-dot notation - scale it back down by divisor
'   e.g., Decimal (314159, 100000) would display 3.14159 on the terminal
'   scaled: Fixed-point scaled up number
'   divisor: Divide scaled-up number by this amount
    whole := scaled / divisor
    tmp := divisor
    places := 0

    repeat
        tmp /= 10
        places++
    until tmp == 1
    part := int.deczeroed(||(scaled // divisor), places)

    ser.dec (whole)
    ser.char (".")
    ser.str (part)
    ser.clearline{}

PUB Setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))
    if tsl2591.startx(I2C_SCL, I2C_SDA, I2C_HZ)
        ser.strln(string("TSL2591 driver started"))
        tsl2591.defaultsals{}
    else
        ser.strln(string("TSL2591 driver failed to start - halting"))
        time.msleep(30)
        tsl2591.stop{}
        repeat

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
