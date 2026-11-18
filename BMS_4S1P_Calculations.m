function results = BMS_4S1P_Calculations(outputDir)
%BMS_4S1P_CALCULATIONS Reproduce the documented engineering calculations.
% results = BMS_4S1P_Calculations
% Base MATLAB only. These are analytical examples, NOT a Simscape run.
% Current is positive during discharge; SOC is a fraction (0 to 1).
if nargin < 1
    outputDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
        'results','calculations');
end
if ~isfolder(outputDir), mkdir(outputDir); end
Ns=4; Np=1; Qcell=3.03; VnomCell=3.6; Rload=20;
results.nominalVoltage_V = Ns*VnomCell;
results.capacity_Ah = Np*Qcell; % Series connection does not add Ah.
results.nominalEnergy_Wh = results.nominalVoltage_V*results.capacity_Ah;
results.nominalEnergy_J = results.nominalEnergy_Wh*3600;
V=[14.4;16.8;16.31]; I=V/Rload; P=V.^2/Rload;
results.load = table(V,I,P,I/Qcell,'VariableNames', ...
    {'Voltage_V','Current_A','Power_W','C_rate_per_h'});
% Illustration: fixed 0.8 A, unlike the time-varying resistor load.
Ts=1; t=(0:Ts:600)'; Idis=0.8*ones(size(t));
zHistorical=zeros(size(t)); zHistorical(1)=0.8;
zCurrent=zeros(size(t)); zCurrent(1)=0.825;
for k=1:numel(t)-1
    dz=Idis(k)*Ts/(3600*Qcell);
    zHistorical(k+1)=zHistorical(k)-dz;
    zCurrent(k+1)=zCurrent(k)-dz;
end
results.socExample=table(t,Idis,zHistorical,zCurrent, ...
    'VariableNames',{'Time_s','AssumedCurrent_A','HistoricalInitialSOC','SavedInitialSOC'});
results.removedCharge_Ah=0.8*600/3600;
results.SOC_drop=results.removedCharge_Ah/Qcell;
results.historicalTraceImpliedCurrent_A=(0.8-0.755)*3600*Qcell/600;
results.idealRuntimeFrom80Percent_h=0.8*Qcell/0.8;
% Ideal shunt, zero switch resistance, voltage held at 4.2 V.
Rb=82; Vcell=4.2;
results.bleedCurrent_A=Vcell/Rb;
results.bleedPower_W=Vcell^2/Rb;
results.bleedTimeFor3PercentagePoints_min=0.03*Qcell/results.bleedCurrent_A*60;
results.bleedTimeFor40PercentagePoints_h=0.4*Qcell/results.bleedCurrent_A;
results.SOH_availableCapacity_Ah=[3.03;2.424];
results.SOH_percent=100*results.SOH_availableCapacity_Ah/Qcell;
% Original strict logic; equality does not trip; discharge overcurrent only.
scenario={'Normal';'Overvoltage';'Undervoltage';'Overcurrent'; ...
    'OV equality';'UV equality';'OC equality';'Negative current limitation'};
testV=[14.4;16.9;9.9;14.4;16.8;10;14.4;14.4];
testI=[0.72;0.8;0.5;8.1;0.8;0.5;8;-9];
fault=(testV>16.8)|(testV<10)|(testI>8);
expected=logical([0;1;1;1;0;0;0;0]);
results.protection=table(scenario,testV,testI,fault,expected, ...
    'VariableNames',{'Scenario','PackVoltage_V','PackCurrent_A','Fault','Expected'});
assert(results.capacity_Ah==3.03,'Series capacity check failed');
assert(abs(zHistorical(end)-(0.8-0.8*600/(3600*Qcell)))<1e-12, ...
    'Coulomb integration check failed');
assert(all(fault==expected),'Protection comparison check failed');
assert(abs(results.SOH_percent(2)-80)<1e-12,'SOH arithmetic failed');
writetable(results.load,fullfile(outputDir,'load_calculations.csv'));
writetable(results.socExample,fullfile(outputDir,'analytical_SOC_example.csv'));
writetable(results.protection,fullfile(outputDir,'protection_logic_checks.csv'));
save(fullfile(outputDir,'BMS_4S1P_calculations.mat'),'results');
fid=fopen(fullfile(outputDir,'calculation_summary.txt'),'w');
assert(fid>=0,'Could not create calculation summary');
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'Analytical examples, not a Simscape simulation\n');
fprintf(fid,'Nominal pack: %.3f V, %.3f Ah, %.6f Wh\n',results.nominalVoltage_V,results.capacity_Ah,results.nominalEnergy_Wh);
fprintf(fid,'Fixed 0.8 A for 600 s: SOC drop %.9f\n',results.SOC_drop);
fprintf(fid,'SOC final with z0=.8: %.9f; with z0=.825: %.9f\n',zHistorical(end),zCurrent(end));
fprintf(fid,'82 ohm at 4.2 V: %.9f A, %.9f W\n',results.bleedCurrent_A,results.bleedPower_W);
fprintf(fid,'Ideal 3 percentage point bleed time: %.6f min\n',results.bleedTimeFor3PercentagePoints_min);
fprintf(fid,'Ideal 40 percentage point bleed time: %.6f h\n',results.bleedTimeFor40PercentagePoints_h);
fprintf(fid,'Assertions passed: series capacity, charge integral, thresholds, SOH.\n');
disp(results.load); disp(results.protection);
fprintf('Calculations and assertions complete. Files: %s\n',outputDir);
end
