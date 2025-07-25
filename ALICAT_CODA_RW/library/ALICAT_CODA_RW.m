function ALICAT_CODA_RW(block)
%ALICAT_RW: A Level 2 S-function to control and/or read an ALICAT CODA
%devices
%   This function is the corresponding .m file for the level 2 s-function block
%   titled ALICAT__CODA_RW. This function communicates over serial with the
%   ALICAT. The gas type, device type, data logging options, and control 
%   options can be set before the simulation starts. The batch limit
%   and control setpoint can be updated while the simulation is running,
%   and the totalizer can also be reset to 0. The function outputs the
%   readings of the ALICAT. The outputs of the ALICAT can be configured
%   before the simulaiton starts. Block works with both ALICAT controllers
%   and meters.
%
%   Input Ports:
%       1) Totalizer Reset: reset switch for the totalizer which resets to
%           totalizer to 0 when the input changes from 0 to 1. Input should
%           be a constant of 0 unless totalizer is being reset. [double]
%       2) Batch Limit: Limit to which the totalizer/batch size is set
%           [double]
%       3) Control setpoint: setpoint used to control the ALICAT based on
%           the variable set in the Register Parameters [double]
%
%   Output Ports:
%       1) Density: Density of process gas [double]
%       2) Temperature: temperature reading from ALICAT [double]
%       3) Volumetric Flow: volumetric flow reading from ALICAT [double]
%       4) Mass Flow: mass flow reading from ALICAT [double]
%       5) STP Volumetric Flow: volumetric flow at standard temperature and
%           pressure reading from ALICAT [double]
%       6) Totalized Flow: totalized flow reading from ALICAT [double]
%       7) Totalized Time: totalized time reading from ALICAT [double]
%       8) Setpoint: setpoint value of variable using to control the ALICAT
%           [double]
%       9) Valve Drive: used to measure how open the valve is, measured in
%           percent [double]
%       7) BatchRem: reamining value left in the batch if batching is enable on 
%           ALICAT [double]
%
%   Register Parameters: 
%       1) Port: COM port of ALICAT device is connected to [string]
%       2) Device Identifier: unit id of ALICAT device [char]
%       3) Gas Type: active gas set on ALICAT Device (Current options:
%           Hydrogen, Nitrogen, and Air)
%       4) Enable Batching: check box to determine whether the batching is
%           enabled 
%       5) Setpoint Variable: variable used to control the ALICAT (Current
%           options: Mass Flow, Volumetric Flow, and Standardized Volumetric Flow) 
%       6) Enable ALICAT Controller: Select whether if you will control the
%           ALICAT through Simulink or just read data
%       7) Device Type: Checkbox to select whether the ALICAT is a controller or a
%           meter
%       8) Totalizer Variable: determines if totalizer variable is mass
%       flow rate or volumetric flow rate (feature not currently enabled)
%       9) Enable Valve Drive Recording: Checkbox to turn on valve drive data logging
%           and display
%
%
%   Author: Gavin Williamson
%   Email: gwilliamson@jtecenergy.com
%   Date: 07/09/2025

%%
%% The setup method is used to set up the basic attributes of the
%% S-function such as ports, parameters, etc. Do not add any other
%% calls to the main body of the function.
%%
setup(block);

%endfunction

%% Function: setup ===================================================
%% Abstract:
%%   Set up the basic characteristics of the S-function block such as:
%%   - Input ports
%%   - Output ports
%%   - Dialog parameters
%%   - Options
%%
%%   Required         : Yes
%%   C MEX counterpart: mdlInitializeSizes
%%

function setup(block)

% Register number of ports
block.NumInputPorts  = 3;  %see function notes for order and description of each parameter
block.NumOutputPorts = 10;  %see function notes for order and description of each parameter

% Setup port properties to be inherited or dynamic
block.SetPreCompInpPortInfoToDynamic;
block.SetPreCompOutPortInfoToDynamic;

% % Override input port properties
%block.InputPort(1).Dimensions        = 1;
% block.InputPort(1).DatatypeID  = 0;  % double
% block.InputPort(1).Complexity  = 'Real';
% block.InputPort(1).DirectFeedthrough = true;
% S
% % Override output port properties
% block.OutputPort(1).Dimensions       = 1;
% block.OutputPort(1).DatatypeID  = 0; % double
% block.OutputPort(1).Complexity  = 'Real';

% Register parameters
block.NumDialogPrms     = 9; %see function notes for order and description of each parameter

% Register sample times
%  [0 offset]            : Continuous sample time
%  [positive_num offset] : Discrete sample time
%
%  [-1, 0]               : Inherited sample time
%  [-2, 0]               : Variable sample time
block.SampleTimes = [0 0];

% Specify the block simStateCompliance. The allowed values are:
%    'UnknownSimState', < The default setting; warn and assume DefaultSimState
%    'DefaultSimState', < Same sim state as a built-in block
%    'HasNoSimState',   < No sim state
%    'CustomSimState',  < Has GetSimState and SetSimState methods
%    'DisallowSimState' < Error out when saving or restoring the model sim state
block.SimStateCompliance = 'DefaultSimState';

%% -----------------------------------------------------------------
%% The MATLAB S-function uses an internal registry for all
%% block methods. You should register all relevant methods
%% (optional and required) as illustrated below. You may choose
%% any suitable name for the methods and implement these methods
%% as local functions within the same file. See comments
%% provided for each function for more information.
%% -----------------------------------------------------------------

block.RegBlockMethod('PostPropagationSetup',    @DoPostPropSetup);
block.RegBlockMethod('InitializeConditions', @InitializeConditions);
block.RegBlockMethod('Start', @Start);
block.RegBlockMethod('Outputs', @Outputs);     % Required
block.RegBlockMethod('Update', @Update);
block.RegBlockMethod('SetInputPortSamplingMode',@SetInpPortFrameData);
block.RegBlockMethod('Derivatives', @Derivatives);
block.RegBlockMethod('Terminate', @Terminate);

end
%end setup

%%
%% PostPropagationSetup:
%%   Functionality    : Setup work areas and state variables. Can
%%                      also register run-time methods here
%%   Required         : No
%%   C MEX counterpart: mdlSetWorkWidths
%%
function DoPostPropSetup(block)
block.NumDworks = 6;
  
  block.Dwork(1).Name            = 'iter';
  block.Dwork(1).Dimensions      = 1;
  block.Dwork(1).DatatypeID      = 0;      % double
  block.Dwork(1).Complexity      = 'Real'; % real
  block.Dwork(1).UsedAsDiscState = true;

  block.Dwork(2).Name            = 'indx_sp';
  block.Dwork(2).Dimensions      = 1;
  block.Dwork(2).DatatypeID      = 0;      % double
  block.Dwork(2).Complexity      = 'Real'; % real
  block.Dwork(2).UsedAsDiscState = true;

  block.Dwork(3).Name            = 'totlzer_stpt';
  block.Dwork(3).Dimensions      = 1;
  block.Dwork(3).DatatypeID      = 0;      % double
  block.Dwork(3).Complexity      = 'Real'; % real
  block.Dwork(3).UsedAsDiscState = true;

  block.Dwork(4).Name            = 'cntrl_stpt';
  block.Dwork(4).Dimensions      = 1;
  block.Dwork(4).DatatypeID      = 0;      % double
  block.Dwork(4).Complexity      = 'Real'; % real
  block.Dwork(4).UsedAsDiscState = true;

  block.Dwork(5).Name            = 'cntrl_typ';
  block.Dwork(5).Dimensions      = 1;
  block.Dwork(5).DatatypeID      = 0;      % double
  block.Dwork(5).Complexity      = 'Real'; % real
  block.Dwork(5).UsedAsDiscState = true;

  block.Dwork(6).Name            = 'sticky_bttn';
  block.Dwork(6).Dimensions      = 1;
  block.Dwork(6).DatatypeID      = 0;      % double
  block.Dwork(6).Complexity      = 'Real'; % real
  block.Dwork(6).UsedAsDiscState = true;

end

%%
%% InitializeConditions:
%%   Functionality    : Called at the start of simulation and if it is 
%%                      present in an enabled subsystem configured to reset 
%%                      states, it will be called when the enabled subsystem
%%                      restarts execution to reset the states.
%%   Required         : No
%%   C MEX counterpart: mdlInitializeConditions
%%

%intialized variables used to connect to the device
function InitializeConditions(block)

end
%end InitializeConditions


%%
%% Start:
%%   Functionality    : Called once at start of model execution. If you
%%                      have states that should be initialized once, this 
%%                      is the place to do it.
%%   Required         : No
%%   C MEX counterpart: mdlStart
%%
persistent dict indx
function Start(block)
block.Dwork(1).Data = 0; %keep track of 1st iteration
nm = char(block.DialogPrm(2).Data); %device identifier

    if isempty(indx)
        indx=0;

        %connect device
        device = serialport(block.DialogPrm(1).Data,19200, 'TimeOut',0.9) ;
        configureTerminator(device,"CR");
        disp(['ALICAT ', nm, ' connected'])

        %initialize dictionary
        dict= dictionary(indx,device);


    else
        %connect device
        device = serialport(block.DialogPrm(1).Data,19200, 'TimeOut',0.9) ;
        configureTerminator(device,"CR");
        disp(['ALICAT ', nm, ' connected'])

        dict(indx) = device; %add new connection to dictionary
    end
    
    block.Dwork(2).Data=indx; %save specific dictionary indx
    indx = indx +1;
end
%end Start

%%
%% Outputs:
%%   Functionality    : Called to generate block outputs in
%%                      simulation step
%%   Required         : Yes
%%   C MEX counterpart: mdlOutputs
    function L =Out2db(line,block)
        %function splits serial string read by device into indivual
        %variables and converts them to doubles so that they can be written
        %out of the block
        spltlin = strsplit(line,' ');
        try 
            L.Density = double(spltlin(2));
            L.Temp = double(spltlin(3));
            L.VolFlw = double(spltlin(4));
            L.MasFlw = double(spltlin(5));

        if block.DialogPrm(7).Data==1 %if device is a controller
            L.Stpt = double(spltlin(6));
            L.TotFLw = double(spltlin(7));
            L.TotT = double(spltlin(8));
            if block.DialogPrm(4).Data ==1 && block.DialogPrm(9).Data ==1  %if batching and valve drive recording is enabled
                L.BatchRem = double(spltlin(9));
                L.VlvDr = double(spltlin(10)); 
                L.STPVolFlw = double(spltlin(11));
            elseif block.DialogPrm(4).Data ==1 && block.DialogPrm(9).Data ==0  %if batching enable and valve drive recording is disabled
                L.BatchRem = double(spltlin(9));
                L.VlvDr = nan;
                L.STPVolFlw = double(spltlin(10));
            elseif block.DialogPrm(4).Data ==0 && block.DialogPrm(9).Data ==1  %if batching disable and valve drive recording is enabled
                L.BatchRem = nan;
                L.VlvDr = double(spltlin(9));
                L.STPVolFlw = double(spltlin(10));
            else %batching and valve drive both disabled
                L.BatchRem = nan;
                L.VlvDr = nan;
                L.STPVolFlw = double(spltlin(9)); 
            end
        else
            L.TotFLw = double(spltlin(6));
            L.TotT = double(spltlin(7));
            L.STPVolFlw = double(spltlin(8));
            L.BatchRem = nan;
            L.VlvDr = nan;
            L.Stpt = nan;
        end
        catch
            warning("Read Line from Alicat was not formatted correctly: " + line)
        end

    end
    function gs_num = gas_chooser(gs_str)
        % function assigns selected gas to the gas number provided in ALICAT
        % documentation so that the correct gas type can be set for the
        % device
        switch gs_str
            case 'Hydrogen'
                gs_num = '6';
            case 'Nitrogen'
                gs_num = '8';
            case 'Air'
                gs_num = '0';
            otherwise
                gs_num = '6';
                warning("Invalid Gas selected, gas set to H2 as default")
        end
    end
    function contrl_typ = decide_cntrl_typ(cntrl_typ_str)
        %function determine sthe setpoint variable use to control the
        %ALICAT and the loop control variable number.
        switch cntrl_typ_str
            case 'Mass Flow'
                contrl_typ = 0;
            case 'Volumetric Flow'
                contrl_typ = 1;
            case 'Standardized Volumetric Flow'
                contrl_typ = 2;
            otherwise
                warning("Setpoint could not be changed; caused by invalid Setpoint Variable chosen")
        end

    end

            
function Outputs(block)
    nm = char(block.DialogPrm(2).Data); %device identifier
    device = dict(block.Dwork(2).Data);
    
    % code run during 1st iteration of block 
    if block.Dwork(1).Data ==0

        block.Dwork(1).Data = block.Dwork(1).Data+1; %ensure initialization code is not run again
       
        %set gas type
        gs_num = gas_chooser(block.DialogPrm(3).Data);
        writeline(device,[nm,'CFG GASID ',gs_num]);
        readline(device);
        disp(['Gas set as ' , block.DialogPrm(3).Data])


        block.Dwork(6).Data= 0; %this variable ensures that reset button is not stuck
        block.Dwork(3).Data = -pi; %this is set so that the variable is initialized and updates during the first iteration

        %setting up totalizer
        if block.DialogPrm(8).Data ==1
            try 
                writeline(device,[nm,'CFG TOTV 0']);
                readline(device);
            catch
                warning("Totalizer variable could not be set to mass flow rate")
            end
        elseif block.DialogPrm(8).Data ==2
            try
                writeline(device,[nm,'CFG TOTV 1']);
                readline(device);
            catch
                warning("Totalizer variable could not be set to volumetric flow rate")
            end
        else
            warning("Invalid totalizer variable setting. Current setting not changed")
        end

        
        if block.DialogPrm(6).Data==1 %if controlling is enabled
            %disabling batching
            if block.DialogPrm(4).Data == 0 && block.DialogPrm(6).Data==1
                try
                    writeline(device,[nm, 'TB 1 0']);
                    readline(device);
                    disp("Batching disabled")
                catch
                    warning("Batching was unable to be disabled")
                end
            end

            %initialize setpoint
            %cntrl_typ = decide_cntrl_typ(block.DialogPrm(5).Data);
            %block.Dwork(5).Data=cntrl_typ';

            try
                % ensure control loop is enabled
                writeline(device,[nm,'C']);
                readline(device);
                % ensure setpot source is digital
                writeline(device,[nm, 'CFG SPS 0'])
                readline(device);
                % %%selected control loop variable (FUNCTIONALITY IS
                % CURRENLTY DISABLLED %%
                %writeline(device,[nm,'CFG LVAR ',num2str(cntrl_typ)])
                %readline(device)
                % set control loop setpoint
                writeline(device,[nm,'S ',num2str(block.InputPort(3).Data)] )
                readline(device);
                disp(['Setpoint set to ', num2str((block.InputPort(3).Data))])
            catch
                warning('Setpoint could not be written to device')
            end

            block.Dwork(4).Data = block.InputPort(3).Data; %save control_stpt

        end %end of setup during 1st iter when controlling ALICAT is enabled
        
        Data_config = 1+2+4+8+32+64+512;%enable standard data recording variables

        if block.DialogPrm(7).Data==1 %enable setpoint recording if controller
            Data_config = Data_config + 16;
        end
        if block.DialogPrm(9).Data==1%enable valve drive recording 
            Data_config = Data_config + 256;
        end
        if block.DialogPrm(4).Data==1%enable batch remaining recording 
            Data_config = Data_config + 128;
        end

        try 
            writeline(device, [nm, 'CFG Data ', num2str(Data_config)]);
            readline(device);
        catch
            warning("Updated data configuration could not be writtent to device")
        end

    end %end of initial configuration

    % resetting totalizer

    if block.InputPort(1).Data==1 && block.Dwork(6).Data == 0 
        try
            writeline(device,[nm,'T'])
            readline(device);
            block.Dwork(6).Data = 1;
            disp("Totalizer Reset")
        catch
            warning("Totalizer could not be reset")
        end
    elseif block.InputPort(1).Data ==0 && block.Dwork(6).Data ==1 %ensures that button doesn't stick and continually resets
        block.Dwork(6).Data=0;
    end

    if block.DialogPrm(6).Data==1 %%only runs if control of ALICAT is enabled

        %updating batch size
        if block.DialogPrm(4).Data == 1 && block.InputPort(2).Data ~= block.Dwork(3).Data
            try
                writeline(device,[nm,'TB 1 ',num2str(block.InputPort(2).Data)])
                readline(device);
                block.Dwork(3).Data = block.InputPort(2).Data;
                disp("Batching setpoint updated")
            catch
                warning("Unable to change batch volume")
            end
        end
        %% check if setpoint can be updated %%
        %updating setpoint
        cntrl_stpt = block.Dwork(4).Data;
        if block.InputPort(3).Data ~= cntrl_stpt %if setpoint has changed
            try
                writeline(device,[nm,'S ',num2str(block.InputPort(3).Data)])
                readline(device);
                block.Dwork(4).Data = block.InputPort(3).Data;
                disp([block.DialogPrm(2).Data, ' setpoint has been updated'])
            catch
                warning("Unable to change setpoint")
            end
        end
    end

%writing data out
try 
    writeline(device,nm)
    data_str = readline(device);
    L = Out2db(data_str,block);
    block.OutputPort(1).Data = L.Density;
    block.OutputPort(2).Data = L.Temp;
    block.OutputPort(3).Data = L.VolFlw;
    block.OutputPort(4).Data = L.MasFlw;
    block.OutputPort(5).Data = L.STPVolFlw;
    block.OutputPort(6).Data = L.TotFLw;
    block.OutputPort(7).Data = L.TotT;
    block.OutputPort(8).Data = L.Stpt;
    block.OutputPort(9).Data = L.VlvDr;
    block.OutputPort(10).Data = L.BatchRem;
catch
    warning("Alicat could not be read or written to")
end


end


%end Outputs

%%
%% Update:
%%   Functionality    : Called to update discrete states
%%                      during simulation step
%%   Required         : No
%%   C MEX counterpart: mdlUpdate
%%
function Update(block)

end
%end Update

%%
%% Derivatives:
%%   Functionality    : Called to update derivatives of
%%                      continuous states during simulation step
%%   Required         : No
%%   C MEX counterpart: mdlDerivatives
%%
function Derivatives(block)
end
%end Derivatives

%% Set the sampling of the input ports
function SetInpPortFrameData(block, idx,fd)
    block.InputPort(idx).SamplingMode = fd;
    for i = 1:block.NumOutputPorts
        block.OutputPort(i).SamplingMode = fd;
    end
end
% end SetInpPortFrameData
%%
%% Terminate:
%%   Functionality    : Called at the end of simulation for cleanup
%%   Required         : No
%%   C MEX counterpart: mdlTerminate
%%
function Terminate(block)
    %clear persistent variables
    Vars=whos;
    PersistentVars=Vars([Vars.persistent]);
    PersistentVarNames={PersistentVars.name};
    clear(PersistentVarNames{:});
end
%end Terminate

end