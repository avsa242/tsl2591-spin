{
    --------------------------------------------
    Filename: sensor.light.tsl2591.spin
    Description: Driver for the TSL2591 I2C Light/lux sensor
    Author: Jesse Burt
    Copyright (c) 2022
    Started Nov 23, 2019
    Updated Dec 2, 2022
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

' Operating modes
    STDBY           = 0
    CONT            = 1

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

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef TSL2591_I2C_BC
    i2c : "com.i2c.nocog"                       ' BC I2C engine
#else
    i2c : "com.i2c"                             ' PASM I2C engine
#endif
    core: "core.con.tsl2591"
    time: "time"

PUB null{}
' This is not a top-level object

PUB start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start using custom settings
    if (lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and I2C_HZ =< core#I2C_MAX_FREQ)
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#T_POR)
            if (dev_id{} == core#DEV_ID_RESP)
                reset{}
                return

    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE

PUB stop{}
' Stop the driver
    powered(FALSE)
    i2c.deinit{}
    longfill(@_cpl, 0, 7)
    wordfill(@_ir_adc, 0, 2)

PUB defaults{}
' Factory default settings
    reset{}

PUB preset_als{}
' Factory defaults, with sensor enabled
    reset{}
    powered(TRUE)
    opmode(CONT)
    dev_factor(408)
    glass_atten(1)
    als_gain(1)
    als_integr_time(100)

PUB als_data{}: als_adc
' Read Ambient Light Sensor data
'   Returns: u16:u16 [31..16]: IR, [15..0]: Full-spectrum (IR+Vis)
    readreg(core#C0DATAL, 4, @als_adc)
    _ir_adc := (als_adc.word[1] & $FFFF)
    _full_adc := (als_adc.word[0] & $FFFF)
    _ir_adc_scl := (_ir_adc * FPSCALE)
    _full_adc_scl := (_full_adc * FPSCALE)

PUB als_data_rdy{}: flag
' Flag indicating new luminosity data is ready
'   Returns: TRUE (-1) or FALSE (0)
    flag := 0
    readreg(core#STATUS, 1, @flag)
    return (((flag >> core#AVALID) & 1) == 1)

PUB als_gain(gainx): curr_gain
' Set gain gain/factor
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
    update_cpl{}                                 ' update counts per lux equ.

PUB als_integr_time(time_ms): curr_time
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
    update_cpl{}                                 ' update counts per lux equ.

PUB dev_factor(df)
' Set device factor
    _dev_fact := df

PUB dev_id{}: id
' Device ID of chip
'   Known values: $50
    id := 0
    readreg(core#ID, 1, @id)

PUB glass_atten(ga)
' Set glass attenuation factor
    _glass_att := ga

PUB int_clear(mask)
' Clear interrupts
'   mask bits: (set a bit to clear the interrupt)
'       1: non-persistent interrupt
'       0: als interrupt
    case mask
        %01:
            writereg(core#SF_CLRALSINT, 0, 0)
        %10:
            writereg(core#SF_CLR_NP_INT, 0, 0)
        %11:
            writereg(core#SF_CLRALS_NP_INT, 0, 0)

PUB int_duration(cycles): curr_cyc
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

PUB int_ena(state): curr_state
' Enable non-persistent interrupts
'   Valid values: TRUE (1 or -1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#ENABLE, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#NPIEN
        other:
            return (((curr_state >> core#NPIEN) & 1) == 1)

    state := ((curr_state & core#NPIEN_MASK) | state) & core#ENABLE_MASK
    writereg(core#ENABLE, 1, state)

PUB int_force{}
' Force an ALS Interrupt
' NOTE: An active interrupt will always be visible using interrupt(),
'   however, to be visible on the INT pin, int_ena() or
'  int_latch_ena() must be set to TRUE
    writereg(core#SF_FORCEINT, 0, 0)

PUB int_latch_ena(state): curr_state
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
            return (((curr_state >> core#AIEN) & 1) == 1)

    state := ((curr_state & core#AIEN_MASK) | state) & core#ENABLE_MASK
    writereg(core#ENABLE, 1, state)

PUB int_hi_thresh{}: thresh
' Get interrupt high threshold
    thresh := 0
    if (int_latch_ena(-2))
        readreg(core#AIHTL, 2, @thresh)
    else
        readreg(core#NPAIHTL, 2, @thresh)

PUB int_lo_thresh{}: thresh
' Get interrupt low threshold
    thresh := 0
    if (int_latch_ena(-2))
        readreg(core#AILTL, 2, @thresh)
    else
        readreg(core#NPAILTL, 2, @thresh)

PUB int_set_hi_thresh(thresh)
' Set interrupt high threshold
'   Valid values: 0..65535 (clamped to range)
    thresh := 0 #> thresh <# 65535
    if (int_latch_ena(-2))
        writereg(core#AIHTL, 2, @thresh)
    else
        writereg(core#NPAIHTL, 2, @thresh)

PUB int_set_lo_thresh(thresh)
' Set interrupt low threshold
'   Valid values: 0..65535 (clamped to range)
    thresh := 0 #> thresh <# 65535
    if (int_latch_ena(-2))
        writereg(core#AILTL, 2, @thresh)
    else
        writereg(core#NPAILTL, 2, @thresh)

PUB interrupt{}: flag
' Flag indicating interrupt has been triggered
'   Returns: TRUE (-1) if interrupt triggered, FALSE (0) otherwise
'   NOTE: An active interrupt will always be visible using interrupt(), however, to be visible on
'       the INT pin, int_ena() or int_latch_ena() must be set to TRUE
    flag := 0
    readreg(core#STATUS, 1, @flag)
    return (flag & core#STATUS_MASK)

PUB last_full{}: fsdata
' Returns full-spectrum data from last measurement
    return _full_adc

PUB last_ir{}: irdata
' Returns infra-red data from last measurement
    return _ir_adc

PUB last_lux{}: l
' Return Lux from last measurement (scale = 1000x)
    return ((_full_adc_scl - _ir_adc_scl) * (FPSCALE - (_ir_adc_scl / _full_adc_scl))) / _cpl

PUB lux{}: l
' Return Lux from live measurement (scale = 1000x)
    als_data{}                                  ' read ALS, but discard return val
    return ((_full_adc_scl - _ir_adc_scl) * (FPSCALE - (_ir_adc_scl / _full_adc_scl))) / _cpl

PUB opmode(mode): curr_mode
' Set device operating mode
'   Valid values:
'       STDBY (0): stand-by
'       CONT (1): continuous measurement
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#ENABLE, 1, @curr_mode)
    case mode
        STDBY, CONT:
            mode := ||(mode) << core#AEN
        other:
            return (((curr_mode >> core#AEN) & 1) == 1)

    mode := ((curr_mode & core#AEN_MASK) | mode) & core#ENABLE_MASK
    writereg(core#ENABLE, 1, mode)

PUB pkg_id{}: id
' Returns Package ID
'   Known values: $00
    id := 0
    readreg(core#PID, 1, @id)

PUB powered(state): curr_state
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
            return ((curr_state & 1) == 1)

    state := ((curr_state & core#PON_MASK) | state) & core#ENABLE_MASK
    writereg(core#ENABLE, 1, state)

PUB reset{}
' Resets the TSL2591 (equivalent to POR)
    writereg(core#CONTROL, 1, (1 << core#SRESET))

PUB sleep_after_int(state): curr_state
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
            return (((curr_state >> core#SAI) & 1) == 1)

    state := ((curr_state & core#SAI_MASK) | state) & core#ENABLE_MASK
    writereg(core#ENABLE, 1, state)

PRI update_cpl{}
' Update counts-per-lux, used in Lux calculations
    _cpl := ((_itime * _gain) * FPSCALE) / (_glass_att * _dev_fact)

PRI readreg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt, tmp
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

PRI writereg(reg_nr, nr_bytes, val) | cmd_pkt[2], tmp
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
Copyright 2022 Jesse Burt

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

