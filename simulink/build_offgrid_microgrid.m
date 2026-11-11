function build_offgrid_microgrid()
% BUILD_OFFGRID_MICROGRID  Builds and runs a phasor-mode Simscape Electrical
% (Specialized Power Systems) model of the off-grid microgrid found by HOMER
% (Case B): 28 kW diesel generator + PV/battery inverter + 10 rural houses.
% Scenario: evening load step 10 kW -> 25 kW at t = 5 s.
% Run 1: diesel only.  Run 2: diesel + battery inverter (frequency droop).
% Outputs: offgrid_microgrid.slx, microgrid_load_step_results.png, results printed.
%
% Md Sazzadur Rahman, LUT University. Energy system modelling project (2025 rebuild).

mdl  = 'offgrid_microgrid';
here = fileparts(mfilename('fullpath')); cd(here);
fprintf('\n=== Building %s in %s ===\n', mdl, here);

% ---------------- system data ----------------
Sn   = 35e3;      % diesel generator rating, VA (28 kW at pf 0.8)
Vn   = 400;       % line-line voltage, V
fn   = 50;        % frequency, Hz
H    = 1.0;       % generator + engine inertia constant, s
R    = 0.05;      % diesel governor droop (5 %)
Tg   = 0.05;      % governor time constant, s
Te   = 0.5;       % diesel engine time constant, s
Pbase= 10e3;      % base load, W
Pstep= 15e3;      % evening load step, W
tStep= 5;         % load step time, s
Rb   = 0.02;      % battery inverter droop (2 %), on generator base
Tb   = 0.05;      % battery inverter response time, s
Pbmax= 18.6e3;    % battery inverter rating from HOMER, W
Kavr = 5;         % integral gain of simple voltage regulator
Tstop= 15;

% ---------------- 1) discover machine measurement signal names ----------------
load_system('sps_lib');
L.pg   = libpath('powergui');
L.sm   = libpath('Simplified Synchronous Machine pu Units');
L.vi   = libpath('Three-Phase V-I Measurement');
L.rlc  = libpath('Three-Phase Series RLC Load');
L.brk  = libpath('Three-Phase Breaker');
L.dyn  = libpath('Three-Phase Dynamic Load');
disp(L)

[wName, PeName] = machineSignalNames(L, Sn, Vn, fn);
fprintf('Machine signals used: speed = "%s", electrical power = "%s"\n', wName, PeName);

% ---------------- 2) new model ----------------
if bdIsLoaded(mdl), close_system(mdl,0); end
if exist(fullfile(here,[mdl '.slx']),'file'), delete(fullfile(here,[mdl '.slx'])); end
new_system(mdl); open_system(mdl); setappdata(0,'BOM_MDL',mdl);
set_param(mdl,'StopTime',num2str(Tstop),'Solver','ode23tb','MaxStep','0.005', ...
    'ReturnWorkspaceOutputs','on');

% ---- power side ----
pg  = add(L.pg , 'powergui',          [ 40  30 120  70]);
set_param(pg,'SimulationMode','Phasor'); setfreq(pg,fn);
gen = add(L.sm , 'Diesel generator',  [300 140 380 240]);
setp(gen,'Nominal power', sprintf('[%g %g %g]',Sn,Vn,fn));
setp(gen,'Inertia',       sprintf('[%g 0 2]',H));
setp(gen,'Internal impedance','[0.02 0.3]');
vi  = add(L.vi , 'Bus measurement',   [470 140 520 240]);
ld1 = add(L.rlc, 'Base load 10 kW',   [640  60 700 120]);
brk = add(L.brk, 'Evening load switch',[620 180 680 240]);
ld2 = add(L.rlc, 'Evening load 15 kW',[760 180 820 240]);
for b = [ld1 ld2]
    setp(b,'phase-to-phase voltage',num2str(Vn)); setp(b,'Nominal frequency',num2str(fn));
    setp(b,'Inductive','0'); setp(b,'Capacitive','0');
end
setp(ld1,'Active power',num2str(Pbase)); setp(ld2,'Active power',num2str(Pstep));
setp(brk,'Initial status','open'); setp(brk,'Switching times',sprintf('[%g]',tStep));
bat = add(L.dyn, 'Battery inverter (PV+battery)', [640 300 720 380]);
setp(bat,'Nominal L-L voltage',sprintf('[%g %g]',Vn,fn));
setp(bat,'Active and reactive power at initial','[0 10]');
setp(bat,'External control','on');
setp(bat,'[np, nq]','[0 0]'); setp(bat,'Initial positive-sequence','[1 0]');

P = @(h) get_param(h,'PortHandles');
g = P(gen); v = P(vi); a = P(ld1); s = P(brk); c = P(ld2); d = P(bat);
genABC = pick3(g); viIn = v.LConn(1:3); viOut = v.RConn(1:3);
for k=1:3
    add_line(mdl, genABC(k), viIn(k), 'autorouting','on');
    add_line(mdl, viOut(k), a.LConn(k), 'autorouting','on');
    add_line(mdl, viOut(k), s.LConn(k), 'autorouting','on');
    add_line(mdl, s.RConn(k), c.LConn(k), 'autorouting','on');
    add_line(mdl, viOut(k), d.LConn(k), 'autorouting','on');
end

% ---- measurements ----
bs  = add('simulink/Signal Routing/Bus Selector','Machine signals',[460 300 470 360]);
set_param(bs,'OutputSignals',[wName ',' PeName]);
add_line(mdl,[get_param(gen,'Name') '/1'],[get_param(bs,'Name') '/1'],'autorouting','on');

% ---- diesel governor:  w -> droop -> governor -> engine -> Pm ----
wref = add('simulink/Sources/Constant','Speed ref 1 pu',[40 420 80 450]); set_param(wref,'Value','1');
e1   = add('simulink/Math Operations/Sum','Speed error',[120 420 140 450]); set_param(e1,'Inputs','+-');
kd   = add('simulink/Math Operations/Gain','Diesel droop',[170 420 210 450]); set_param(kd,'Gain',sprintf('1/%g',R));
gov  = add('simulink/Continuous/Transfer Fcn','Governor',[240 415 300 455]); set_param(gov,'Numerator','1','Denominator',sprintf('[%g 1]',Tg));
eng  = add('simulink/Continuous/Transfer Fcn','Diesel engine',[330 415 390 455]); set_param(eng,'Numerator','1','Denominator',sprintf('[%g 1]',Te));
pm0  = add('simulink/Sources/Constant','Pm initial',[330 470 370 500]); set_param(pm0,'Value',sprintf('%g',Pbase/Sn));
spm  = add('simulink/Math Operations/Sum','Pm sum',[420 420 440 450]); set_param(spm,'Inputs','++');
satp = add('simulink/Discontinuities/Saturation','Engine limit',[470 420 510 450]); set_param(satp,'UpperLimit','1.1','LowerLimit','0');
link(bs,1,e1,2); link(wref,1,e1,1); link(e1,1,kd,1); link(kd,1,gov,1); link(gov,1,eng,1);
link(eng,1,spm,1); link(pm0,1,spm,2); link(spm,1,satp,1); link(satp,1,gen,1);

% ---- simple voltage regulator:  E = 1 + Kavr * integral(1 - Vt) ----
mag  = add('simulink/Math Operations/Complex to Magnitude-Angle','|Vabc|',[560 260 600 290]); set_param(mag,'Output','Magnitude');
sel  = add('simulink/Signal Routing/Selector','Phase a',[620 260 650 290]); set_param(sel,'Indices','1','InputPortWidth','3');
vpu  = add('simulink/Math Operations/Gain','Vt pu',[680 260 720 290]); set_param(vpu,'Gain',sprintf('1/(%g*sqrt(2/3))',Vn));
vref = add('simulink/Sources/Constant','V ref 1 pu',[680 520 720 550]); set_param(vref,'Value','1');
ev   = add('simulink/Math Operations/Sum','Voltage error',[760 520 780 550]); set_param(ev,'Inputs','+-');
ka   = add('simulink/Math Operations/Gain','AVR gain',[810 520 850 550]); set_param(ka,'Gain',num2str(Kavr));
ia   = add('simulink/Continuous/Integrator','AVR integrator',[880 520 910 550]); set_param(ia,'InitialCondition','1','LimitOutput','on','UpperSaturationLimit','2','LowerSaturationLimit','0.5');
add_line(mdl,[get_param(vi,'Name') '/1'],[get_param(mag,'Name') '/1'],'autorouting','on');
link(mag,1,sel,1); link(sel,1,vpu,1); link(vref,1,ev,1); link(vpu,1,ev,2); link(ev,1,ka,1); link(ka,1,ia,1); link(ia,1,gen,2);

% ---- battery inverter: frequency droop -> P command -> dynamic load (negative = injection) ----
kb   = add('simulink/Math Operations/Gain','Battery droop',[170 560 210 590]); set_param(kb,'Gain',sprintf('1/%g*%g',Rb,Sn));
ten  = add('simulink/Math Operations/Gain','Battery enable',[240 560 280 590]); set_param(ten,'Gain','1');
tbf  = add('simulink/Continuous/Transfer Fcn','Inverter response',[310 555 370 595]); set_param(tbf,'Numerator','1','Denominator',sprintf('[%g 1]',Tb));
sb   = add('simulink/Discontinuities/Saturation','Inverter limit 18.6 kW',[400 560 440 590]); set_param(sb,'UpperLimit',num2str(Pbmax),'LowerLimit',num2str(-Pbmax));
neg  = add('simulink/Math Operations/Gain','Injection = -load',[470 560 510 590]); set_param(neg,'Gain','-1');
q0   = add('simulink/Sources/Constant','Q = 0',[470 610 510 640]); set_param(q0,'Value','10');
mx   = add('simulink/Signal Routing/Mux','PQ',[550 560 555 640]); set_param(mx,'Inputs','2');
link(e1,1,kb,1); link(kb,1,ten,1); link(ten,1,tbf,1); link(tbf,1,sb,1); link(sb,1,neg,1); link(neg,1,mx,1); link(q0,1,mx,2); link(mx,1,bat,1);

% ---- outputs ----
fHz = add('simulink/Math Operations/Gain','f (Hz)',[980 300 1020 330]); set_param(fHz,'Gain',num2str(fn));
pkw = add('simulink/Math Operations/Gain','P diesel (kW)',[980 360 1020 390]); set_param(pkw,'Gain',sprintf('%g/1000',Sn));
bkw = add('simulink/Math Operations/Gain','P battery (kW)',[980 600 1020 630]); set_param(bkw,'Gain','1/1000');
link(bs,1,fHz,1); link(bs,2,pkw,1); link(sb,1,bkw,1);
tw = @(nm,src,pos) towk(nm,src,pos);
tw('f_Hz',fHz,[1060 300 1120 330]); tw('V_pu',vpu,[1060 250 1120 280]);
tw('Pdiesel_kW',pkw,[1060 360 1120 390]); tw('Pbattery_kW',bkw,[1060 600 1120 630]);
sc = add('simulink/Sinks/Scope','Scope',[1180 280 1220 400]); set_param(sc,'NumInputPorts','4');
link(fHz,1,sc,1); link(vpu,1,sc,2); link(pkw,1,sc,3); link(bkw,1,sc,4);
save_system(mdl, fullfile(here,[mdl '.slx']));
fprintf('Model saved: %s.slx\n', mdl);

% ---------------- 3) simulate: diesel only, then diesel + battery ----------------
set_param(ten,'Gain','0'); r1 = sim(mdl);
set_param(ten,'Gain','1'); r2 = sim(mdl);
save_system(mdl);

S1 = summarise(r1,tStep); S2 = summarise(r2,tStep); pre=S1.t<tStep; pre2=S1.t>4 & S1.t<tStep; fprintf('\nStart-up 0-5 s: f %.3f to %.3f Hz; at 4-5 s: f %.4f Hz, V %.4f pu, diesel %.2f kW\n',min(S1.f(pre)),max(S1.f(pre)),mean(S1.f(pre2)),mean(S1.v(pre2)),mean(S1.p(pre2)));
fprintf('\n%-34s %14s %18s\n','Result (load step 10 -> 25 kW)','Diesel only','Diesel + battery');
fprintf('%-34s %14.2f %18.2f\n','Frequency nadir (Hz)',S1.fmin,S2.fmin);
fprintf('%-34s %14.2f %18.2f\n','Frequency after step, steady (Hz)',S1.fss,S2.fss);
fprintf('%-34s %14.3f %18.3f\n','Voltage minimum (pu)',S1.vmin,S2.vmin);
fprintf('%-34s %14.1f %18.1f\n','Diesel power, steady (kW)',S1.pd,S2.pd);
fprintf('%-34s %14.1f %18.1f\n','Battery power, steady (kW)',S1.pb,S2.pb);
fprintf('Hand check: steady drop = dP/(1/R[+1/Rb]) -> %.2f Hz (diesel) and %.2f Hz (with battery)\n', ...
    fn*(Pstep/Sn)/(1/R), fn*(Pstep/Sn)/(1/R+1/Rb));

% ---------------- 4) plots ----------------
fig = figure('Color','w','Position',[100 100 900 750]);
ax1 = subplot(3,1,1); plot(S1.t,S1.f,'LineWidth',1.5); hold on; plot(S2.t,S2.f,'LineWidth',1.5);
yline(49,'--k','49 Hz'); ylabel('Frequency (Hz)'); grid on; legend('Diesel only','Diesel + battery','Location','southeast');
title('Off-grid microgrid, Lappeenranta: evening load step 10 \rightarrow 25 kW');
ax2 = subplot(3,1,2); plot(S1.t,S1.v,'LineWidth',1.5); hold on; plot(S2.t,S2.v,'LineWidth',1.5);
ylabel('Bus voltage (pu)'); grid on; ylim([0.85 1.05]);
ax3 = subplot(3,1,3); plot(S1.t,S1.p,'LineWidth',1.5); hold on; plot(S2.t,S2.p,'LineWidth',1.5); plot(S2.t,S2.b,'LineWidth',1.5);
ylabel('Power (kW)'); xlabel('Time (s)'); grid on; legend('Diesel (diesel only)','Diesel (with battery)','Battery','Location','east');
linkaxes([ax1 ax2 ax3],'x'); xlim([tStep-1 Tstop]);
exportgraphics(fig, fullfile(here,'microgrid_load_step_results.png'),'Resolution',200);
fprintf('Plot saved: microgrid_load_step_results.png\n=== Done ===\n');
end

% ===================== helpers =====================
function p = libpath(name)
r = find_system('sps_lib','LookUnderMasks','on','FollowLinks','on','Name',name);
if isempty(r)
    r = find_system('sps_lib','LookUnderMasks','on','FollowLinks','on','RegExp','on','Name',['^' regexprep(name,'\s+','.*')]);
end
if isempty(r), error('Block "%s" not found in sps_lib', name); end
[~,i] = min(cellfun(@numel,r)); p = r{i};
end

function h = add(lib,name,pos)
mdl = getappdata(0,'BOM_MDL'); h = add_block(lib,[mdl '/' name],'Position',pos);
end

function setp(blk,promptPart,val)
dp = get_param(blk,'DialogParameters'); f = fieldnames(dp);
for i=1:numel(f)
    if contains(lower(dp.(f{i}).Prompt),lower(promptPart))
        set_param(blk,f{i},val); return
    end
end
warning('Setting "%s" not found in block "%s"', promptPart, get_param(blk,'Name'));
end

function link(a,pa,b,pb)
mdl = getappdata(0,'BOM_MDL');
add_line(mdl,[get_param(a,'Name') '/' num2str(pa)],[get_param(b,'Name') '/' num2str(pb)],'autorouting','on');
end

function towk(var,src,pos)
mdl = getappdata(0,'BOM_MDL');
h = add_block('simulink/Sinks/To Workspace',[mdl '/' var],'Position',pos);
set_param(h,'VariableName',var,'SaveFormat','Structure With Time');
link(src,1,h,1);
end

function ports = pick3(ph)
if numel(ph.RConn) >= 3, ports = ph.RConn(1:3); else, ports = ph.LConn(1:3); end
end

function [wName,PeName] = machineSignalNames(L,Sn,Vn,fn)
t = 'tmp_sm_probe'; if bdIsLoaded(t), close_system(t,0); end
new_system(t); load_system(t);
pg = add_block(L.pg,[t '/powergui']); set_param(pg,'SimulationMode','Phasor'); setfreq(pg,fn);
sm = add_block(L.sm,[t '/SM']); ld = add_block(L.rlc,[t '/Load']); setp(ld,'Inductive','0'); setp(ld,'Capacitive','0'); setp(ld,'phase-to-phase voltage',num2str(Vn)); setp(ld,'Nominal frequency',num2str(fn));
dp = get_param(sm,'DialogParameters'); f = fieldnames(dp);
for i=1:numel(f), if contains(lower(dp.(f{i}).Prompt),'nominal power'), set_param(sm,f{i},sprintf('[%g %g %g]',Sn,Vn,fn)); end, end
c1 = add_block('simulink/Sources/Constant',[t '/Pm']); set_param(c1,'Value','0.3');
c2 = add_block('simulink/Sources/Constant',[t '/E']);  set_param(c2,'Value','1');
tm = add_block('simulink/Sinks/Terminator',[t '/T']);
add_line(t,'Pm/1','SM/1'); add_line(t,'E/1','SM/2'); add_line(t,'SM/1','T/1');
g = get_param(sm,'PortHandles'); l = get_param(ld,'PortHandles'); gp = pick3(g);
for k=1:3, add_line(t,gp(k),l.LConn(k)); end
set_param(t,'SimulationCommand','update');
h = get_param(g.Outport(1),'SignalHierarchy');
names = flat(h,'');
close_system(t,0);
fprintf('Machine measurement signals: %s\n', strjoin(names,', '));
leaf = regexprep(names,'.*\.','');
iw = find(ismember(lower(leaf),{'w','wm','w_m','omega'}),1);
if isempty(iw), iw = find(contains(lower(names),'speed') & ~contains(lower(leaf),'dw'),1); end
ip = find(strcmpi(leaf,'Pe'),1);
if isempty(ip), ip = find(contains(lower(names),'power') | contains(names,'Pe'),1); end
if isempty(iw) || isempty(ip), error('Could not identify speed / Pe in: %s', strjoin(names,', ')); end
wName = names{iw}; PeName = names{ip};
end

function n = flat(h,prefix)
n = {};
for i=1:numel(h.Children)
    c = h.Children(i); nm = c.SignalName; if ~isempty(prefix), nm = [prefix '.' nm]; end
    if isempty(c.Children), n{end+1} = nm; else, n = [n flat(c,nm)]; end %#ok<AGROW>
end
end

function S = summarise(r,tStep)
f = r.get('f_Hz'); v = r.get('V_pu'); p = r.get('Pdiesel_kW'); b = r.get('Pbattery_kW');
S.t = f.time; S.f = f.signals.values(:); S.v = v.signals.values(:); S.p = p.signals.values(:); S.b = b.signals.values(:);
after = S.t > tStep; last = S.t > S.t(end)-1;
S.fmin = min(S.f(after)); S.fss = mean(S.f(last)); S.vmin = min(S.v(S.t > tStep+0.01));
S.pd = mean(S.p(last)); S.pb = mean(S.b(last));
end
function setfreq(pg,fn)
dp=get_param(pg,'DialogParameters'); f=fieldnames(dp);
for i=1:numel(f), if contains(lower([f{i} ' ' dp.(f{i}).Prompt]),'freq'), try, set_param(pg,f{i},num2str(fn)); catch, end, end, end
end
