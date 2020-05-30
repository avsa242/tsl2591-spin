# tsl2591-spin 
--------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the AMS TSL2591 Lux Sensor

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* I2C connection up to 400kHz
* Read all sensor channels together, or individually
* Set interrupt thresholds (persistent and non-persistent)
* Set integration time
* Set gain multiplier
* Optionally sleep after interrupts
* Force an interrupt

## Requirements

P1/SPIN1:
* spin-standard-library
* P1/SPIN1: 1 extra core/cog for the PASM I2C driver

P2/SPIN2:
* p2-spin-standard-library

## Compiler Compatibility

* P1/SPIN1: OpenSpin (tested with 1.00.81)
* P2/SPIN2: FastSpin (tested with 4.1.10-beta)
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* Very early in development - may malfunction or outright fail to build
* Luminosity calculation is currently unverified

## TODO

- [x] Clean up the demo object
- [ ] Verify luminosity readings against certified/calibrated device
- [ ] Implement better/multiple LUX calculations
