{
    --------------------------------------------
    Filename: sensor.lux.tsl2591.spin
    Description: Driver for the TSL2591 I2C Light/lux sensor
    Author: Jesse Burt
    Copyright (c) 2020
    Started Nov 23, 2019
    Updated Dec 20, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR        = core#SLAVE_ADDR
    SLAVE_RD        = core#SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 100_000

    LSB             = 0

' Gain settings
    GAIN_LOW        = 0
    GAIN_MED        = 1
    GAIN_HI         = 2
    GAIN_MAX        = 3

' Sensor channels
    FULL            = 0
    IR              = 1
    VISIBLE         = 2
    BOTH            = 3

VAR

    word _ir_counts, _fullspec_counts

OBJ

    i2c     : "com.i2c"
    core    : "core.con.tsl2591"

PUB Null{}
' This is not a top-level object

PUB Start{}: okay

    okay := startx(DEF_SCL, DEF_SDA, DEF_HZ)
    return

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): okay

    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31)
        if I2C_HZ =< core#I2C_MAX_FREQ
            if okay := i2c.setupx(SCL_PIN, SDA_PIN, I2C_HZ)
                if deviceid{} == core#DEV_ID_RESP
                    reset{}
                    return okay
    return FALSE

PUB Stop{}
' Kills I2C cog
    powered(FALSE)
    i2c.terminate{}

PUB ClearAllInts{}
' Clears both ALS (persistent) and NPALS (non-persistent) Interrupts
    writereg(core#TRANS_SPECIAL, core#SF_CLRALS_NP_INT, 0, 0)

PUB ClearInt{}
' Clears NPALS Interrupt
    writereg(core#TRANS_SPECIAL, core#SF_CLR_NP_INT, 0, 0)

PUB ClearPersistInt{}
' Clears ALS Interrupt
    writereg(core#TRANS_SPECIAL, core#SF_CLRALSINT, 0, 0)

PUB DataReady{}
' Indicates ADCs completed integration cycle since AEN bit was set
    result := $00
    readreg(core#STATUS, 1, @result)
    return ((result >> core#AVALID) & 1) * TRUE

PUB DeviceID{}
' Device ID of chip
'   Known values: $50
    result := $00
    readreg(core#ID, 1, @result)
    result &= $FF

PUB ForceInt{}
' Force an ALS Interrupt
' NOTE: Per TLS2591 Datasheet, for an interrupt to be visible on the INT pin,
'  one of the interrupt enable bits in the ENABLE ($00) register must be set.
'  i.e., make sure you've called EnableInts(TRUE) or EnablePersist (TRUE)
    writereg(core#TRANS_SPECIAL, core#SF_FORCEINT, 0, 0)

PUB Gain(multiplier) | tmp
' Set gain multiplier/factor
'   Valid values: 1, 25, 428, 9876
'   Any other value polls the chip and returns the current setting
    tmp := 0
    readreg(core#CONTROL, 1, @tmp)
    case multiplier
        1, 25, 428, 9876:
            multiplier := lookdownz(multiplier: 1, 25, 428, 9876) << core#AGAIN
        other:
            result := (tmp >> core#AGAIN) & core#AGAIN_BITS
            return lookupz(result: 1, 25, 428, 9876)

    tmp &= core#AGAIN_MASK
    tmp := (tmp | multiplier) & core#CONTROL_MASK
    writereg(core#TRANS_NORMAL, core#CONTROL, 1, tmp)

PUB IntegrationTime(time_ms) | tmp
' Set ADC Integration time, in milliseconds (affects both photodiode channels)
'   Valid values: 100, 200, 300, 400, 500, 600
'   Any other value polls the chip and returns the current setting
    tmp := 0
    readreg(core#CONTROL, 1, @tmp)
    case time_ms
        100, 200, 300, 400, 500, 600:
            time_ms := lookdownz(time_ms: 100, 200, 300, 400, 500, 600)
        other:
            result := tmp & core#ATIME_BITS
            return lookupz(result: 100, 200, 300, 400, 500, 600)

    tmp &= core#ATIME_MASK
    tmp := (tmp | time_ms) & core#CONTROL_MASK
    writereg(core#TRANS_NORMAL, core#CONTROL, 1, tmp)

PUB Interrupt{}
' Indicates if a non-persistent interrupt has been triggered
'   Returns: TRUE (-1) if interrupt triggered, FALSE (0) otherwise
    result := $00
    readreg(core#STATUS, 1, @result)
    result := ((result >> core#NPINTR) & 1) * TRUE

PUB IntsEnabled(enabled) | tmp
' Enable non-persistent interrupts
'   Valid values: TRUE (1 or -1): interrupts enabled, FALSE (0) disables interrupts
'   Any other value polls the chip and returns the current setting
    tmp := 0
    readreg(core#ENABLE, 1, @tmp)
    case ||(enabled)
        0, 1:
            enabled := ||(enabled) << core#NPIEN
        other:
            return ((tmp >> core#NPIEN) & 1) * TRUE

    tmp &= core#NPIEN_MASK
    tmp := (tmp | enabled) & core#ENABLE_MASK
    writereg(core#TRANS_NORMAL, core#ENABLE, 1, tmp)

PUB IntThresh(low, high) | tmp
' Set non-persistent interrupt thresholds
'   Valid values for low and high thresholds: 0..65535
'   Any other value polls the chip and returns the current setting
'       (high threshold will be returned in upper word of result, low threshold in lower word)
    tmp := 0
    readreg(core#NPAILTL, 4, @tmp)
    case low
        0..65535:
        other:
            result.word[0] := tmp.word[0]

    case high
        0..65535:
            high := (high << 16) | low
        other:
            result.word[1] := tmp.word[1]

    case result
        0:
        other:
            return result

    writereg(core#TRANS_NORMAL, core#NPAILTL, 4, high)

PUB LastFull{}
' Returns full-spectrum data from last measurement
    return _fullspec_counts

PUB LastIR{}
' Returns infra-red data from last measurement
    return _ir_counts

PUB Measure(channel) | tmp
' Get luminosity data from sensor
'   Valid values:
'       %00 - Full spectrum
'       %01 - IR
'       %10 - Visible
'       %11 - Both (most-significant word: IR, least-signficant word: Full-spectrum)
'   Any other values ignored
    tmp := 0
    readreg(core#C0DATAL, 4, @tmp)
    case channel
        %00:
            result := tmp.word[0] & $FFFF
        %01:
            result := tmp.word[1] & $FFFF
        %10:
            result := (tmp.word[0] - tmp.word[1]) & $FFFF
        %11:
            result := tmp
        other:
            return

    _ir_counts := tmp.word[1] & $FFFF
    _fullspec_counts := tmp.word[0] & $FFFF

PUB PackageID{}
' Returns Package ID
'   Known values: $00
    result := $00
    readreg(core#PID, 1, @result)

PUB PersistInt{}
' Indicates if a persistent interrupt has been triggered
'   Returns: TRUE (-1) an interrupt, FALSE (0) otherwise
    result := $00
    readreg(core#STATUS, 1, @result)
    result := ((result >> core#AINT) & 1) * TRUE

PUB PersistIntCycles(cycles) | tmp
' Set number of consecutive cycles necessary to generate an interrupt (i.e., persistence)
'   Valid values:
'       0, 1, 2, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60
'   Any other value polls the chip and returns the current setting
    tmp := 0
    readreg(core#PERSIST, 1, @tmp)
    case cycles
        0, 1, 2, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60:
            cycles := lookdownz(cycles: 0, 1, 2, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60)
        other:
            tmp &= core#APERS_BITS
            result := lookupz(tmp: 0, 1, 2, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60)
            return

    tmp := cycles & core#PERSIST_MASK
    writereg(core#TRANS_NORMAL, core#PERSIST, 1, tmp)

PUB PersistIntsEnabled(enabled) | tmp
' Enable persistent interrupts
'   Valid values:
'       TRUE (1 or -1): Enabled
'       FALSE (0): Disabled
'   Any other value polls the chip and returns the current setting
    tmp := 0
    readreg(core#ENABLE, 1, @tmp)
    case ||(enabled)
        0, 1:
            enabled := ||(enabled) << core#AIEN
        other:
            return ((tmp >> core#AIEN) & 1) * TRUE

    tmp &= core#AIEN_MASK
    tmp := (tmp | enabled) & core#ENABLE_MASK
    writereg(core#TRANS_NORMAL, core#ENABLE, 1, tmp)

PUB PersistIntThresh(low, high) | tmp
' Sets trigger threshold values for persistent ALS interrupts
'   Valid values for low and high thresholds: 0..65535
'   Any other value polls the chip and returns the current setting
'   Returns:
'       Most Significant Word: High threshold
'       Least Significant Word: Low threshold
    tmp := 0
    readreg(core#AILTL, 4, @tmp)
    case low
        0..65535:
        other:
            result.word[0] := tmp.word[0]

    case high
        0..65535:
            high := (high << 16) | low
        other:
            result.word[1] := tmp.word[1]

    case result
        0:
        other:
            return result

    writereg(core#TRANS_NORMAL, core#AILTL, 4, high)

PUB Powered(enabled) | tmp
' Enable sensor power
'   Valid values:
'       TRUE (1 or -1): Power on
'       FALSE (0): Power off
'   Any other value polls the chip and returns the current setting
    tmp := 0
    readreg(core#ENABLE, 1, @tmp)
    case ||(enabled)
        0, 1:
            enabled := ||(enabled)
        other:
            return (tmp & 1) * TRUE

    tmp &= core#PON_MASK
    tmp := (tmp | enabled) & core#ENABLE_MASK
    writereg(core#TRANS_NORMAL, core#ENABLE, 1, tmp)

PUB Reset{}
' Resets the TSL2591 (equivalent to POR)
    writereg(core#TRANS_NORMAL, core#CONTROL, 1, 1 << core#SRESET)

PUB SensorEnabled(enabled) | tmp
' Enable ambient light sensor ADCs
'   Valid values:
'       TRUE (1 or -1): Enabled
'       FALSE (0): Disabled
'   Any other value polls the chip and returns the current setting
    tmp := 0
    readreg(core#ENABLE, 1, @tmp)
    case ||(enabled)
        0, 1:
            enabled := ||(enabled) << core#AEN
        other:
            return ((tmp >> core#AEN) & 1) * TRUE

    tmp &= core#AEN_MASK
    tmp := (tmp | enabled) & core#ENABLE_MASK
    writereg(core#TRANS_NORMAL, core#ENABLE, 1, tmp)

PUB SleepAfterInt(enabled) | tmp
' Enable Sleep After Interrupt
'   Valid values:
'       TRUE (1 or -1): Enable
'       FALSE (0): Disable
'   Any other value polls the chip and returns the current setting
    tmp := 0
    readreg(core#ENABLE, 1, @tmp)
    case ||(enabled)
        0, 1:
            enabled := ||(enabled) << core#SAI
        other:
            return ((tmp >> core#SAI) & 1) * TRUE

    tmp &= core#SAI_MASK
    tmp := (tmp | enabled) & core#ENABLE_MASK
    writereg(core#TRANS_NORMAL, core#ENABLE, 1, tmp)

PRI readReg(reg, nr_bytes, buff_addr) | cmd_packet[2], tmp
'Read nr_bytes from register 'reg' to address 'addr_buff'
    writereg(core#TRANS_NORMAL, reg, 0, 0)

    i2c.start{}
    i2c.write(SLAVE_RD)
    repeat tmp from 0 to nr_bytes-1
        byte[buff_addr][tmp] := i2c.read(tmp == nr_bytes-1)
    i2c.stop{}

PRI writeReg(trans_type, reg, nr_bytes, val) | cmd_packet[2], tmp
' Write nr_bytes to register 'reg' stored in val
    cmd_packet.byte[LSB] := SLAVE_WR

    case trans_type
        core#TRANS_NORMAL:
            case reg
                core#ENABLE, core#CONTROL, core#AILTL..core#NPAIHTH, core#PERSIST, core#PID..core#C1DATAH:
                other:
                    return
'            cmd_packet.byte[1] := (core#TSL2591_CMD | trans_type) | reg

        core#TRANS_SPECIAL:
            case reg
                core#SF_FORCEINT, core#SF_CLRALSINT, core#SF_CLRALS_NP_INT, core#SF_CLR_NP_INT:
                    nr_bytes := 0
                    val := 0
                other:
                    return

        other:
            return

    cmd_packet.byte[1] := (core#TSL2591_CMD | trans_type) | reg

    case nr_bytes
        0:
        1..4:
            repeat tmp from 0 to nr_bytes-1
                cmd_packet.byte[2 + tmp] := val.byte[tmp]
        other:
            return

    i2c.start{}
    i2c.wr_block(@cmd_packet, nr_bytes+2)
    i2c.stop{}

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
