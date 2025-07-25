function sim_results = simout_2_csv_recurs(simout, fileName)
%SIMOUT_2_CSV_RECURS Save Simulink simulation output to disk as .CSV file -
%recursion-based
%{
simout_2_csv_recurs.m
Julian Bell, JTEC Energy
2024-01-29

This function takes data saved into a simout variable from a Simulink
model, restructures it, and saves it as a CSV file.

Elements of this code shamelessly copied from convert_simout_2_table.m by
billtubs
(https://github.com/billtubbs/ml-data-utils/blob/d7ca006f21448bcd0e91f12180c835710a26b186/convert_simout_2_table.m)

This version does this recursively


% TODO: Add inputs, outputs, expectations for simout variable
%}

%% Generate container for data and fieldnames
persistent selectedData;
selectedData = containers.Map();
persistent colNames;
colNames = containers.Map();
lt = false;

%% Create timeseries for experiment
% Create datetime vector
dt = simout.tout(2)-simout.tout(1);
t_vect = (simout.expStartTime:seconds(dt):(seconds(dt)*(numel(simout.tout)-1))+simout.expStartTime)';
t_range = timerange(simout.curExpStartTime,simout.expEndTime);

% Add elapsed time vector to maps
selectedData('elapsedTime') = timetable(t_vect, simout.tout);
colNames('elapsedTime') = 'elapsedTime';

% Generate blank timeseries so we can synchronize undersampled timeseries to it
t_ser = timeseries(0,simout.tout);
t_ser.data(1) = 1; % Set first and last elements to one so that synchronizations cover entire duration
t_ser.data(end) = 1;

%% Get data field from Simulation Output structure and add to table using recursive functions
recursFieldRead(simout.data, 'data');

%% Collect and synchronize all timetables from selectedData container
dataCell = values(selectedData);
sim_results = synchronize(dataCell{:},t_vect);
% Extract just the results from this latest run
sim_results = sim_results(t_range,:);

%% Save table to CSV
writetimetable(sim_results, string(fileName) + '.csv');
sim_results_complete = struct();
sim_results_complete.data = sim_results;
sim_results_complete.curExpStartTime = simout.curExpStartTime;
sim_results_complete.expStartTime = simout.expStartTime;
sim_results_complete.expEndTime = simout.expEndTime;
save(fileName + ".mat","sim_results_complete");

%% Nested recursion functions
% Nesting to give access to base workspace
    function recursFieldRead(var, varName)
        if isa(var,'struct')
            subVarNames = fieldnames(var);
            nSubVars = numel(subVarNames);
            % For fields in struct
            for i = 1:nSubVars
                % Call this function on it
                recursFieldRead(var.(subVarNames{i}),subVarNames{i});
            end
        elseif isa(var,'timeseries')
            % Call tsExtract on it
            tsExtract(var, varName)
        end
    end
    
    function tsExtract(var, varName)
        temp_TT = timeseries2timetable(var);
        temp_TT.Time = temp_TT.Time + simout.expStartTime;
        temp_TT.Properties.VariableNames{1} = varName;
        colNames(varName) = varName;
        selectedData(varName) = temp_TT;
    end

end