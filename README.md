# tsl2591-spin 
--------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the AMS TSL2591 Lux Sensor

## Salient Features

* I2C connection up to 400kHz
* Read all sensor channels together, or individually
* Set interrupt thresholds (persistent and non-persistent)
* Set integration time
* Set gain multiplier
* Optionally sleep after interrupts
* Force an interrupt

## Requirements

* P1/SPIN1: 1 extra core/cog for the PASM I2C driver
* P2/SPIN2: N/A

## Compiler Compatibility

* P1: OpenSpin (tested with 1.00.81)
* P2: FastSpin (tested with 4.0.3-beta)

## Limitations

* Very early in development - may malfunction or outright fail to build
* Luminosity calculation is currently unverified

## TODO

- [x] Clean up the demo object
- [ ] Verify luminosity readings against certified/calibrated device
- [ ] Implement better/multiple LUX calculations
