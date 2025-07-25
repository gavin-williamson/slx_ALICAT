function y=saveTestResults(u)

y=1;
if u==1
    evalin('base','set_param(gcs,"SimulationCommand","WriteDataLogs");');
    evalin('base','expEndTime = datetime("now","Format","dd-MMM-uuuu HH:mm:ss.SSS");');
    evalin('base','out.expStartTime = expStartTime;');
    evalin('base','out.curExpStartTime = nextExpStartTime;')
    evalin('base','out.expEndTime = expEndTime;');
    evalin('base','s = string(expEndTime);');
    evalin('base','s = regexprep(s,"[ ,-,:,.]","");');
    evalin('base','expFileName = "LabJackDataCollection_"+ s;');
    evalin('base', 'simout_2_csv_recurs(out,expFileName);');
    evalin('base','nextExpStartTime = expEndTime;');
end
