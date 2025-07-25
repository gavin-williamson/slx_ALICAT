function ALICAT_PRESS_RW(block)
%ALICAT_RW: A Level 2 S-function to control and/or read an ALICAT Pressures
%   devices
%   This function is the corresponding .m file for the level 2 s-function block
%   titled ALICAT_PRESS_RW. This function communicates over serial with the
%   ALICAT pressure devices. The gas type, device type, data logging options, and control 
%   options can be set before the simulation starts. The function outputs the
%   readings of the ALICAT. The outputs of the ALICAT can be configured
%   before the simulaiton starts. Block works with both ALICAT controllers
%   and meters.
%
%   Input Ports:
%       1) Control setpoint: setpoint used to control the ALICAT based on
%           the variable set in the Register Parameters [double]
%
%   Output Ports:
%       1) P_abs: absolute pressure reading from ALICAT [double]
%       2) Setpoint: setpoint value of variable using to control the ALICAT
%           [double]
%       3) Totalized Flow: totalized flow reading from ALICAT [double]
%
%   Register Parameters: 
%       1) Port: COM port of ALICAT device is connected to [string]
%       2) Device Identifier: unit id of ALICAT device [char]
%       3) Setpoint Variable: variable used to control the ALICAT (Current
%           options: Absolute Pressure and Valve Drive) 
%           *If set to "Valve Drive", "Control Setpoint" should be set to 
%               the percentage open on the range of 0-100. Where 0 
%               corresponds to closed and 100 corresponds to fully open.
%       4) Enable ALICAT Controller: Select whether if you will control the
%           ALICAT through Simulink or just read data
%       5) Device Type: Checkbox to select whether the ALICAT is a controller or a
%           meter
%       6) Enable Valve Drive Recording: Checkbox to turn on valve drive data logging
%           and display
%       7) Two Valve Controller: Checkbox to indicate if the device is a
%           two valve controller enabling each valve to be controlled using
%           valve drive control setting
%
%
%   Author: Gavin Williamson
%   Email: gwilliamson@jtecenergy.com
%   Date: 03/17/2025

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
block.NumInputPorts  = 1;  %see function notes for order and description of each parameter
block.NumOutputPorts = 3;  %see function notes for order and description of each parameter

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
block.NumDialogPrms     = 7; %see function notes for order and description of each parameter

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
block.NumDworks = 4;
  
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

  block.Dwork(3).Name            = 'cntrl_stpt';
  block.Dwork(3).Dimensions      = 1;
  block.Dwork(3).DatatypeID      = 0;      % double
  block.Dwork(3).Complexity      = 'Real'; % real
  block.Dwork(3).UsedAsDiscState = true;

  block.Dwork(4).Name            = 'cntrl_typ';
  block.Dwork(4).Dimensions      = 2;
  block.Dwork(4).DatatypeID      = 0;      % double
  block.Dwork(4).Complexity      = 'Real'; % real
  block.Dwork(4).UsedAsDiscState = true;

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
            L.PSIA = double(spltlin(2));
            if block.DialogPrm(5).Data==1 %device is controller type
                L.Stpt = double(spltlin(3));
            else
                L.Stpt = NaN;
            end
            if block.DialogPrm(5).Data==1 && block.DialogPrm(6).Data==1%controller type and vavle drive is on
                L.VlvDr = double(spltlin(4));
            else
                L.VlvDr = NaN;
            end
        catch
            warning("Read Line from Alicat was not formatted correctly: " + line)
        end

    end
    function contrl_typ = decide_cntrl_typ(cntrl_typ_str)
        %function determine sthe setpoint variable use to control the
        %ALICAT and the loop control variable number (if applicable). The output
        %is a 1X2 double vector where the first position determines the
        %type of setpoint and the 2nd position if the loop control variable
        %list of possible outputs:
        %[1, n] - corresponds to a loon control variable being set where n
            %corresponds to the loop_variable value number provided by
            %ALICAT
        %[2,0] - corresponds to the valve position open being set
        switch cntrl_typ_str
            case 'Absolute Pressure'
                contrl_typ = [1,34];
            case 'Valve Drive'
                contrl_typ = [2,0];
            otherwise
                warning("Setpoint could not be changed; caused by invalid Setpoint Variable chosen")
        end

    end
    function vlv_st = vlv_stpt_scl(vlv_in,vlv_st_curr,vlv_typ)
        % takes in the new valve position (as a %open) and the current
        % valve position and converts them to the ALICAT range of 0-65535.
        % Only updates valve st if new position is between 0-100%. If
        % not, the output state is the current state (only if that is
        % between 0-100%). If the controller is a two valve type then a
        % negative input can be used to control the right valve.
        % IF NEITHER VALVE STATE IS VALID THE VALVE IS CLOSED
        if vlv_in >=0 && vlv_in <=100 
            vlv_st = num2str(round((vlv_in/100) * 65535));
        elseif abs(vlv_in) >=0 && abs(vlv_in) <=100 && vlv_typ==1
            vlv_st = num2str(round((vlv_in/100) * 65535));
        elseif vlv_st_curr >=0 && vlv_st_curr <=100
            warning("Invalid valve setpoint unchanged. Setpoint must be 0<=stpt<=100")
            vlv_st =num2str(vlv_st_curr);
        else
            warning("Invalid valve setpoint. Valve closed")
            vlv_st ='0';
        end
    end
            
function Outputs(block)
    nm = char(block.DialogPrm(2).Data); %device identifier
    device = dict(block.Dwork(2).Data);
    
    % code run during 1st iteration of block 
    if block.Dwork(1).Data ==0

        block.Dwork(1).Data = block.Dwork(1).Data+1; %ensure initialization code is not run again

        if block.DialogPrm(4).Data==1 %if controlling is enabled

            %initialize setpoint
            cntrl_typ = decide_cntrl_typ(block.DialogPrm(3).Data);
            block.Dwork(4).Data=cntrl_typ';
            if cntrl_typ(1) == 1 %selected a control loop variable
                try
                    % ensure control loop is enabled
                    writeline(device,[nm,'C']);
                    readline(device);
                    % selected control loop variable
                    writeline(device,[nm,'LV ',num2str(cntrl_typ(2))])
                    readline(device);
                    % set control loop setpoint
                    writeline(device,[nm,'S ',num2str(block.InputPort(1).Data)] )
                    readline(device);
                    disp([block.DialogPrm(3).Data, ' setpoint set to ', num2str((block.InputPort(1).Data))])
                catch
                    warning('Setpoint could not be written to device')
                end
            elseif cntrl_typ(1) == 2 %selected control by valve drive
                try
                    % set device to hold so valve position can be controlled
                    writeline(device, [nm,'H'])
                    readline(device);
                    % calculate valve stpt on 0-65535 scale
                    vlv_stpt = vlv_stpt_scl(block.InputPort(1).Data,0,block.DialogPrm(7).Data); % VALVE IS SET TO CLOSE IF INITIAL SETPOINT IS INVALID
                    % change valve position
                    writeline(device, [nm, 'W12=',vlv_stpt]);
                    readline(device);
                    disp(['Valve set to ', num2str(block.InputPort(1).Data),'% open'])
                catch
                    warning('Setpoint could not be written to device')
                end
            else
                warning("Control type of setpoint variable could not be determined")
            end
            block.Dwork(3).Data = block.InputPort(1).Data; %save control_stpt

        end %end of setup during 1st iter when controlling ALICAT is enabled

        if block.DialogPrm(4).Data ==1 %setting Valve Drive Recording          
            if block.DialogPrm(6).Data==1
                try
                    writeline(device,[nm,'W19= 32779']);
                    readline(device);
                catch
                    warning("Data Logging of Valve Drive could not be enabled")
                end
                try
                    writeline(device,[nm,'FPS 5 6 2 13 0 0 -2']);
                    readline(device);
                catch
                    warning("Valve drive display could not be turned on")
                end
            else
                try
                    writeline(device,[nm,'W19= 11']);
                    readline(device);
                catch
                    warning("Data Logging of Valve Drive could not be diabled")
                end
                try
                    writeline(device,[nm,'FPS 5 6 2 1']);
                    readline(device);
                catch
                    warning("Valve drive display could not be turned off")
                end
            end
        end

    end


    if block.DialogPrm(4).Data==1 %%only runs if control of ALICAT is enabled

        %updating setpoint
        cntrl_stpt = block.Dwork(3).Data;
        cntrl_typ = block.Dwork(4).Data;
        if cntrl_typ(1) ==1 && block.InputPort(1).Data ~= cntrl_stpt %if using control loop variable
            try
                writeline(device,[nm,'S ',num2str(block.InputPort(1).Data)])
                readline(device);
                block.Dwork(3).Data = block.InputPort(1).Data;
                disp([block.DialogPrm(3).Data, ' setpoint has been updated'])
            catch
                warning("Unable to change setpoint")
            end
        elseif cntrl_typ(1)==2 && block.InputPort(1).Data ~=cntrl_stpt %if congrolling valve position
            try
                vlv_stpt = vlv_stpt_scl(block.InputPort(1).Data,cntrl_stpt,block.DialogPrm(7).Data);
                writeline(device, [nm, 'W12=',vlv_stpt]);
                readline(device);
                block.Dwork(3).Data = block.InputPort(1).Data;
            catch
                warning("Unable to change valve drive setpoint")
            end
        end
    end

%writing data out
try 
    writeline(device,nm)
    data_str = readline(device);
    L = Out2db(data_str,block);
    block.OutputPort(1).Data = L.PSIA;
    block.OutputPort(2).Data = L.Stpt;
    block.OutputPort(3).Data = L.VlvDr;
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