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

    DAT_COL     = 20

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    int     : "string.integer"
    time    : "time"
    tsl2591 : "sensor.lux.tsl2591.i2c"

PUB Main{}

    setup{}

    tsl2591.glassattenuation(GA)
    tsl2591.devicefactor(DF)
    repeat
        repeat until tsl2591.dataready{}
        tsl2591.measure(tsl2591#BOTH)

        ser.position(0, 5)
        ser.str(string("Lux: "))
        ser.positionx(DAT_COL)
        decimaldot(tsl2591.lastlux{}, 1000)

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
        tsl2591.defaults_als{}
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
