# slx_ALICAT

## About
slx_ALICAT is a simple toolbox that enables interaction with ALICAT devices. The toolbox can be used to read and control Alicat mass flow, pressure, BASIS, and CODA controllers/meters over serial communication in Simulink. This toolbox aims to be as user-friendly as possible, so that users can quickly set up Simulink models to read and command Alicat devices. The toolbox is quite powerful, however, and can communicate with multiple Alicats simultaneously, is compatible with several different Alicat devices, and provides access to Simulink & MATLAB's extensive library of control & processing functionality.

Much of the functionality in this toolbox is implemented in base Simulink, so speed/determinism is not guaranteed, and this has not been tested with Simulink real-time products.

slx_ALICAT is developed by Julian Bell and Gavin Williamson at [JTEC Energy](https://jtecenergy.com/). This blockset is licensed under the BSD 4-Clause license.

## How it Works:
slx_ALICAT automatically takes care of a significant amount of housekeeping associated with setting up and Alicat—connecting to the device, enabling the totalizer, choosing the control loop variable, etc. This allows engineers to focus on data collection even quicker. It also has very low supporting hardware and software requirements—it runs in a normal Simulink model (not real-time) and does not require any expensive specialized toolkits or computer platforms to work. 

The core concept of the toolbox is that you start by adding a block to your model that represents your Alicat device—whether it's a flow meter, pressure meter, or a controller. The configuration of the Alicat can then be specified by double-clicking the block and selecting the appropriate mask parameters. The inputs of the block can be used to control the setpoint, set the batch size, and reset the totalizer. Simulink can be set up to run at a certain pace, which allows you to control the rate of your data aquisition. Details on how to set this up, along with an example model, can be found in the library's help documentation after the toolbox has been installed. 

Example: Let's say you want to vary the setpoint of an Alicat MC Series mass flow controller while recording the process conditions (temperature, mass flow rate, etc.). You would first add an ALICAT_Flow block. You would then set up the connection and configuration of the device through the block's mask (enabling totalizer, choosing gas type, choosing control loop variable, etc.). You would then connect constant blocks to the inputs to control the setpiont and batch size. The output could then be collected to plot and/or save the collected process parameters. 

## Features
* Read Alicat mass flow meters, pressure meters, CODA devcies, and BASIS devices
* Control and read Alicat flow controllers, pressure controllers, CODA controllers, and BASIS controllers
* Configure Alicat devices (specific parameters will only appear when applicable to selected device)
  * Communication port
  * Gas type
  * Setpoint Variable
  * Enable batching 
  * Data logging options
    * Enable totalizer
    * Enable valve drive recording
  * Enable Alicat Controller
    * This gives you the option for a controller to just be read as a meter through Simulink (It can still be controlled through the screen interface)
* An example model showing how to use the slx_ALICAT toolbox to collect data
* Connect to several Alicat devices from one model

## Limitations and Restrictions:
Currently, the toolbox supports only Alicat-compatible serial commands using ASCII over RS-232 and RS-485 communication protocols. To connect to an Alicat device from your computer, you must specify the appropriate COM port. 

## Repository Notes 
This repository contains the MATLAB Project file where slx_ALICAT was originally developed. You can pull the repository and open up the MATLAB Project if you're interested in developing the toolbox further, or your can just download the toolbox file from the latest release version which will enable you to install the library as a MATLAB add-on.

## Roadmap 
As of July 2025, there is no plan to add additional features to slx_ALICAT - it does what we need for our purposes at JTEC. However, community contributions are welcome and solicited! Please let us know if you make substantial improvements or expansions - we'd love to see them.

## Citation 

MATLAB File Exchange: [![View slx_ALICAT on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/181590-slx_alicat)

If you find this codebase REALLY useful, you can [buy Julian](https://www.paypal.com/paypalme/julianlelandbell) or [buy Gavin](https://paypal.me/GavinWilliamson255) a coffee!
