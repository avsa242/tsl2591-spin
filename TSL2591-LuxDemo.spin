{
----------------------------------------------------------------------------------------------------
    Filename:       TSL2591-LuxDemo.spin
    Description:    Demo of the TSL2591 driver
        * Lux data output
    Author:         Jesse Burt
    Started:        Jul 23, 2022
    Updated:        Nov 4, 2025
    Copyright (c) 2025 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

' Uncomment the next two lines to use the bytecode-based I2C engine in the driver.
'#define TSL2591_I2C_BC
'#pragma exportdef(TSL2591_I2C_BC)

CON

    _clkmode    = xtal1+pll16x
    _xinfreq    = 5_000_000

' -- User-modifiable constants
    GA          = 1                             ' Glass attenuation factor
    DF          = 408                           ' Device factor
' --


OBJ

    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    sensor: "sensor.light.tsl2591" | SCL=28, SDA=29, I2C_FREQ=400_000
    time:   "time"


PUB main() | lux

    setup()

    repeat
        repeat
        until sensor.als_data_rdy()
        ser.pos_xy(0, 3)
        lux := sensor.lux()
        ser.printf(@"Illuminance (lux): %4.4d.%02.2d\n\r", (lux / 1000), abs(lux // 1000) )


PUB setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( sensor.start() )
        ser.strln(@"TSL2591 driver started")
    else
        ser.strln(@"TSL2591 driver failed to start - halting")
        repeat

    sensor.preset_als()

    sensor.glass_atten(GA)
    sensor.dev_factor(DF)


DAT
{
Copyright 2025 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

