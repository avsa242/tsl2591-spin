{
    --------------------------------------------
    Filename: sensor.lux.tsl2591.spin
    Description: Driver for the TSL2591 I2C Light/lux sensor
    Author: Jesse Burt
    Copyright (c) 2021
    Started Nov 23, 2019
    Updated May 20, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR        = core#SLAVE_ADDR
    SLAVE_RD        = core#SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 100_000

    FPSCALE         = 1_000                     ' fixed-point math scale

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

    long _cpl, _itime, _gain, _glass_att, _dev_fact
    long _ir_adc_scl, _full_adc_scl
    word _ir_adc, _full_adc

OBJ

    i2c     : "com.i2c"
    core    : "core.con.tsl2591"
    time    : "time"

PUB Null{}
' This is not a top-level object

PUB Start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start using custom settings
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#T_POR)
            if deviceid{} == core#DEV_ID_RESP
                reset{}
                return

    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE

PUB Stop{}
' Kills I2C cog
    powered(FALSE)
    i2c.deinit{}

PUB Defaults{}
' Factory default settings
    reset{}

PUB Defaults_ALS{}
' Factory defaults, with sensor enabled
    reset{}
    powered(TRUE)
    sensorenabled(TRUE)
    devicefactor(408)
    glassattenuation(1)
    gain(1)
    integrationtime(100)

PUB ClearAllInts{}
' Clears both ALS (persistent) and NPALS (non-persistent) Interrupts
    writereg(core#SF_CLRALS_NP_INT, 0, 0)

PUB ClearInt{}
' Clears NPALS Interrupt
    writereg(core#SF_CLR_NP_INT, 0, 0)

PUB ClearPersistInt{}
' Clears ALS Interrupt
    writereg(core#SF_CLRALSINT, 0, 0)

PUB DataReady{}: flag
' Flag indicating new luminosity data is ready
'   Returns: TRUE (-1) or FALSE (0)
    flag := 0
    readreg(core#STATUS, 1, @flag)
    return ((flag >> core#AVALID) & 1) == 1

PUB DeviceFactor(df)
' Set device factor
    _dev_fact := df

PUB DeviceID{}: id
' Device ID of chip
'   Known values: $50
    id := 0
    readreg(core#ID, 1, @id)

PUB ForceInt{}
' Force an ALS Interrupt
' NOTE: An active interrupt will always be visible using Interrupt(),
'   however, to be visible on the INT pin, IntsEnabled() or
'   PersistIntsEnabled() must be set to TRUE
    writereg(core#SF_FORCEINT, 0, 0)

PUB Gain(gainx): curr_gain
' Set gain gainx/factor
'   Valid values: *1, 25, 428, 9876
'   Any other value polls the chip and returns the current setting
    curr_gain := 0
    readreg(core#CONTROL, 1, @curr_gain)
    case gainx
        1, 25, 428, 9876:
            _gain := gainx
            gainx := lookdownz(gainx: 1, 25, 428, 9876) << core#AGAIN
        other:
            curr_gain := (curr_gain >> core#AGAIN) & core#AGAIN_BITS
            return lookupz(curr_gain: 1, 25, 428, 9876)

    gainx := ((curr_gain & core#AGAIN_MASK) | gainx) & core#CONTROL_MASK
    writereg(core#CONTROL, 1, gainx)
    updatecpl{}                                 ' update counts per lux equ.

PUB GlassAttenuation(ga)
' Set glass attenuation factor
    _glass_att := ga

PUB IntegrationTime(time_ms): curr_time
' Set ADC Integration time, in milliseconds (affects both photodiode channels)
'   Valid values: *100, 200, 300, 400, 500, 600
'   Any other value polls the chip and returns the current setting
    curr_time := 0
    readreg(core#CONTROL, 1, @curr_time)
    case time_ms
        100, 200, 300, 400, 500, 600:
            _itime := time_ms
            time_ms := lookdownz(time_ms: 100, 200, 300, 400, 500, 600)
        other:
            curr_time &= core#ATIME_BITS
            return lookupz(curr_time: 100, 200, 300, 400, 500, 600)

    time_ms := ((curr_time & core#ATIME_MASK) | time_ms) & core#CONTROL_MASK
    writereg(core#CONTROL, 1, time_ms)
    updatecpl{}                                 ' update counts per lux equ.

PUB Interrupt{}: flag
' Flag indicating a non-persistent interrupt has been triggered
'   Returns: TRUE (-1) if interrupt triggered, FALSE (0) otherwise
'   NOTE: An active interrupt will always be visible using Interrupt(),
'       however, to be visible on the INT pin, EnableInts() or EnablePersist()
'       must be set to TRUE
    flag := 0
    readreg(core#STATUS, 1, @flag)
    return ((flag >> core#NPINTR) & 1) == 1

PUB IntsEnabled(state): curr_state
' Enable non-persistent interrupts
'   Valid values: TRUE (1 or -1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#ENABLE, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#NPIEN
        other:
            return ((curr_state >> core#NPIEN) & 1) == 1

    state := ((curr_state & core#NPIEN_MASK) | state) & core#ENABLE_MASK
    writereg(core#ENABLE, 1, state)

PUB IntThresh(low, high): curr_thr
' Set non-persistent interrupt thresholds
'   Valid values for low and high thresholds: 0..65535 (default: 0, 0)
'   Any other value polls the chip and returns the current setting
'   Returns:
'       [31..16]: high threshold
'       [15..0]: low threshold
    curr_thr := 0
    readreg(core#NPAILTL, 4, @curr_thr)
    case low
        0..65535:
        other:
            return curr_thr.word[0]

    case high
        0..65535:
            high := (high << 16) | low
        other:
            return curr_thr.word[1]

    case curr_thr
        0:
        other:
            return curr_thr

    writereg(core#NPAILTL, 4, high)

PUB LastFull{}: fsdata
' Returns full-spectrum data from last measurement
    return _full_adc

PUB LastIR{}: irdata
' Returns infra-red data from last measurement
    return _ir_adc

PUB LastLux{}: l
' Return Lux from last measurement (scale = 1000x)
    return ((_full_adc_scl - _ir_adc_scl) * (FPSCALE - (_ir_adc_scl / _full_adc_scl))) / _cpl

PUB Lux{}: l
' Return Lux from live measurement (scale = 1000x)
    measure(BOTH)
    return ((_full_adc_scl - _ir_adc_scl) * (FPSCALE - (_ir_adc_scl / _full_adc_scl))) / _cpl

PUB Measure(channel): lum_data
' Get luminosity data from sensor
'   Valid values:
'       %00 - Full spectrum
'       %01 - IR
'       %10 - Visible
'       %11 - Both (Returns: [31..16]: IR, [15..0]: Full-spectrum)
'   Any other values ignored
    lum_data := 0
    readreg(core#C0DATAL, 4, @lum_data)
    case channel
        %00:
            lum_data := lum_data.word[0] & $FFFF
        %01:
            lum_data := lum_data.word[1] & $FFFF
        %10:
            lum_data := (lum_data.word[0] - lum_data.word[1]) & $FFFF
        %11:
            lum_data := lum_data
        other:
            return

    _ir_adc := lum_data.word[1] & $FFFF
    _full_adc := lum_data.word[0] & $FFFF
    _ir_adc_scl := _ir_adc * FPSCALE
    _full_adc_scl := _full_adc * FPSCALE

PUB PackageID{}: id
' Returns Package ID
'   Known values: $00
    id := 0
    readreg(core#PID, 1, @id)

PUB PersistInt{}: flag
' Flag indicating a persistent interrupt has been triggered
'   Returns: TRUE (-1) an interrupt, FALSE (0) otherwise
'   NOTE: An active interrupt will always be visible using PersistInt(),
'       however, to be visible on the INT pin, PersistIntsEnabled()
'       must be set to TRUE
    flag := 0
    readreg(core#STATUS, 1, @flag)
    return ((flag >> core#AINT) & 1) == 1

PUB PersistIntCycles(cycles): curr_cyc
' Set number of consecutive cycles necessary to generate an interrupt
'   Valid values:
'       *0, 1, 2, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60
'       Special cases:
'           0: Every cycle generates an interrupt, regardless of value
'           1: Any value outside the threshold generates an interrupt
'   Any other value polls the chip and returns the current setting
    case cycles
        0, 1, 2, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60:
            writereg(core#PERSIST, 1, curr_cyc)
            cycles := lookdownz(cycles: 0, 1, 2, 3, 5, 10, 15, 20, 25, 30, 35,{
}           40, 45, 50, 55, 60)
        other:
            curr_cyc := 0
            readreg(core#PERSIST, 1, @curr_cyc)
            curr_cyc &= core#APERS_BITS
            return lookupz(curr_cyc: 0, 1, 2, 3, 5, 10, 15, 20, 25, 30, 35,{
}           40, 45, 50, 55, 60)

PUB PersistIntsEnabled(state): curr_state
' Enable persistent interrupts
'   Valid values:
'       TRUE (1 or -1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#ENABLE, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#AIEN
        other:
            return ((curr_state >> core#AIEN) & 1) == 1

    state := ((curr_state & core#AIEN_MASK) | state) & core#ENABLE_MASK
    writereg(core#ENABLE, 1, state)

PUB PersistIntThresh(low, high): curr_thr
' Sets trigger threshold values for persistent ALS interrupts
'   Valid values for low and high thresholds: 0..65535
'   Any other value polls the chip and returns the current setting
'   Returns:
'       [31..16]: High threshold
'       [15..0]: Low threshold
    curr_thr := 0
    readreg(core#AILTL, 4, @curr_thr)
    case low
        0..65535:
        other:
            return curr_thr.word[0]

    case high
        0..65535:
            high := (high << 16) | low
        other:
            return curr_thr.word[1]

    case curr_thr
        0:
        other:
            return curr_thr

    writereg(core#AILTL, 4, high)

PUB Powered(state): curr_state
' Enable sensor power
'   Valid values:
'       TRUE (1 or -1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#ENABLE, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state)
        other:
            return (curr_state & 1) == 1

    state := ((curr_state & core#PON_MASK) | state) & core#ENABLE_MASK
    writereg(core#ENABLE, 1, state)

PUB Reset{}
' Resets the TSL2591 (equivalent to POR)
    writereg(core#CONTROL, 1, 1 << core#SRESET)

PUB SensorEnabled(state): curr_state
' Enable ambient light sensor ADCs
'   Valid values:
'       TRUE (1 or -1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#ENABLE, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#AEN
        other:
            return ((curr_state >> core#AEN) & 1) == 1

    state := ((curr_state & core#AEN_MASK) | state) & core#ENABLE_MASK
    writereg(core#ENABLE, 1, state)

PUB SleepAfterInt(state): curr_state
' Enable Sleep After Interrupt
'   Valid values:
'       TRUE (1 or -1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#ENABLE, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#SAI
        other:
            return ((curr_state >> core#SAI) & 1) == 1

    state := ((curr_state & core#SAI_MASK) | state) & core#ENABLE_MASK
    writereg(core#ENABLE, 1, state)

PRI updateCPL{}
' Update counts-per-lux, used in Lux calculations
    _cpl := ((_itime * _gain) * FPSCALE) / (_glass_att * _dev_fact)

PRI readReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt, tmp
' Read nr_bytes from device into ptr_buff
    case reg_nr
        core#ENABLE, core#CONTROL, core#AILTL..core#PERSIST,{
}       core#PID..core#C1DATAH:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr | core#CMD_NORMAL

            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.wait(SLAVE_RD)
            i2c.rdblock_lsbf(ptr_buff, nr_bytes, i2c#NAK)
            i2c.stop{}
        other:
            return

PRI writeReg(reg_nr, nr_bytes, val) | cmd_pkt[2], tmp
' Write nr_bytes from val to device
    case reg_nr
        core#ENABLE, core#CONTROL, core#AILTL..core#PERSIST:
            reg_nr |= core#CMD_NORMAL
        core#SF_FORCEINT, core#SF_CLRALSINT, core#SF_CLRALS_NP_INT,{
}       core#SF_CLR_NP_INT:
            nr_bytes := 0
            val := 0
        other:
            return

    cmd_pkt.byte[0] := SLAVE_WR
    cmd_pkt.byte[1] := reg_nr

    case nr_bytes
        0:
        1..4:
            repeat tmp from 0 to nr_bytes-1
                cmd_pkt.byte[2 + tmp] := val.byte[tmp]
        other:
            return

    i2c.start{}
    i2c.wrblock_lsbf(@cmd_pkt, nr_bytes+2)
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
