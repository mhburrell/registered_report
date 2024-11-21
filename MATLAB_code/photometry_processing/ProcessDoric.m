% Processes doric files to produce dF/F
% MGC 12/19/2022

% MGC 3/3/2023: Added option for number of ROIs and number of channels
%   also changed dF/F calculation to be more efficient (rolling baseline
%   computed in increments of 1 second and then interpolated, instead of for
%   every bin)

paths = struct;
paths.doric_data = 'D:\Doric\';
paths.save_data = 'D:\Doric\processed\';
paths.libmc = 'C:\code\libmc\';
addpath(genpath(paths.libmc));
 
opt = struct;
opt.sessions = {...
    'MC195_20240822_OdorWater_VariableProbability_FreeRewards_NovelOdor',...
};

opt.iti_offset = 1; % seconds past sync pulse onset to exclude from iti period
opt.smooth_signals = true; % if true, smooths before subtracting isosbestic
opt.smooth_sigma = 50; % in ms (only used if opt.smooth_signals = true);
% opt.numROI = 1;
opt.numROI = 2;
% opt.RoiName = {'VTA'};
opt.RoiName = {'VTA','DLS'};
opt.tdTom = false; % not implemented currently (tdTomato channel)
opt.thresh_z_low = -7; % for removing negative outliers in signal channels (bug with Doric Rig1)
opt.thresh_z_high = 30; % for removing positive outliers in isosbestic channels (bug with Doric Rig1)
opt.gap_thresh = 0.2; % in sec; for identifying gaps with missing data (another bug with Doric Rig1)


%% Get doric files
doric_files = dir(fullfile(paths.doric_data,'*.doric'));
doric_files = {doric_files.name}';


%% iterate over sessions
tic
for sesh_num = 1:numel(opt.sessions)

    session = opt.sessions{sesh_num};
    strsplit_this = strsplit(session,'_');
    mouse = strsplit_this{1};
    session_date = strsplit_this{2};
    
    fprintf('Session %d/%d: %s\n',sesh_num,numel(opt.sessions),session);
    
    doric_file = fullfile(paths.doric_data,doric_files(contains(doric_files,session)));
    doric_file = doric_file{1};

    % load photometry data
    dat = struct;
    dat.iso = cell(opt.numROI,1);
    dat.sig = cell(opt.numROI,1);
    dat.t_iso = h5read(doric_file,'/DataAcquisition/BFPD/ROISignals/Series0001/CAM1_EXC1/Time');
    dat.t_sig = h5read(doric_file,'/DataAcquisition/BFPD/ROISignals/Series0001/CAM1_EXC2/Time');
    for roiIdx = 1:opt.numROI
        dat.iso{roiIdx} = h5read(doric_file,...
            sprintf('/DataAcquisition/BFPD/ROISignals/Series0001/CAM1_EXC1/ROI0%d',roiIdx));
        dat.sig{roiIdx} = h5read(doric_file,...
            sprintf('/DataAcquisition/BFPD/ROISignals/Series0001/CAM1_EXC2/ROI0%d',roiIdx));
    end

    % load sync pulse data (Doric)
    dat_sync = struct;
    dat_sync.dio1 = h5read(doric_file,'/DataAcquisition/BFPD/Signals/Series0001/DigitalIO/DIO1');
    dat_sync.t = h5read(doric_file,'/DataAcquisition/BFPD/Signals/Series0001/DigitalIO/Time');
    
    %% extract sync pulse
    sync_idx = find(diff(dat_sync.dio1)==1)+1;
    synct = dat_sync.t(sync_idx);
    
    %% chop off end for some sessions when cord was unplugged before Doric stopped
    if strcmp(session,'MC117_20231014_OdorLaser_FreeWater')
        dat = cut_end(dat,3000); 
    end
    if strcmp(session,'MC104_20231016_OdorLaser_FreeWater')
        dat = cut_end(dat,3135); 
    end
    if strcmp(session,'MC123_20240210_OdorLaser_FreeWater')
        dat = cut_end(dat,3135); 
    end
    if strcmp(session,'MC123_20240221_OdorLaser_FreeWater')
        dat = cut_end(dat,3135); 
    end
    if strcmp(session,'MC121_20240224_OdorLaser_FreeWater')
        dat = cut_end(dat,3135); 
    end
    if strcmp(session,'MC191_20240801_OdorWater_VariableProbability_FreeRewards')
        synct = synct(2:end);
        sync_idx = sync_idx(2:end);
    end
    if strcmp(session,'MC191_20240814_OdorWater_VariableProbability_FreeRewards')
        synct = synct(2:end);
        sync_idx = sync_idx(2:end);
    end
    

    %% process photometry data
    % Convert to DeltaF/F
    iso_orig = cell(opt.numROI,1);
    F_orig = cell(opt.numROI,1);
    for roiIdx = 1:opt.numROI
        iso_orig{roiIdx} = deltaFoverF(dat.iso{roiIdx},dat.t_iso,synct,opt.iti_offset);
        F_orig{roiIdx} = deltaFoverF(dat.sig{roiIdx},dat.t_sig,synct,opt.iti_offset);
    end

    
    %% remove outliers
    % this is to deal with a bug on Doric Rig1 in which there were
    % sporadic positive outliers in the isosbestic channel and negative
    % outliers in the signal channels
    for roiIdx = 1:opt.numROI
        iso_orig{roiIdx} = remove_outliers_z(iso_orig{roiIdx},opt.thresh_z_high,'high');
        F_orig{roiIdx} = remove_outliers_z(F_orig{roiIdx},opt.thresh_z_low,'low');
    end
    
    
    %% interpolate to same time scale
    t = min([dat.t_sig(1) dat.t_iso(1)]):0.001:max([dat.t_sig(end) dat.t_iso(end)]);
    iso = cell(opt.numROI,1);
    F = cell(opt.numROI,1);
    for roiIdx = 1:opt.numROI
        assert(numel(dat.t_iso)==numel(iso_orig{roiIdx}),'num time points mismatch');
        nkeep = min(numel(dat.t_iso),numel(iso_orig{roiIdx}));
        iso{roiIdx} = interp1(dat.t_iso(1:nkeep),iso_orig{roiIdx}(1:nkeep),t);
    
        assert(numel(dat.t_sig)==numel(F_orig{roiIdx}),'num time points mismatch');
        nkeep = min(numel(dat.t_sig),numel(F_orig{roiIdx}));
        F{roiIdx} = interp1(dat.t_sig(1:nkeep),F_orig{roiIdx}(1:nkeep),t);
    end
    
    %% find periods with missing data (happens sometimes on Rig1 Doric system)
    missing_idx_orig = find(diff(dat.t_sig)>opt.gap_thresh);
    missing_idx = []; % indices where data was missing, in interpolated time base
    if ~isempty(missing_idx_orig)
        for mIdx = 1:numel(missing_idx_orig)
            [~,idx1] = min(abs(t-dat.t_sig(missing_idx_orig(mIdx))));
            [~,idx2] = min(abs(t-dat.t_sig(missing_idx_orig(mIdx)+1)));
            missing_idx = [missing_idx idx1:idx2];
            fprintf('\tMissing data: t=%0.1f to t=%0.1f\n',t(idx1),t(idx2));
        end
    end
    
    %% get rid of some leading and ending nans
    for roiIdx = 1:opt.numROI
        iso{roiIdx} = clean_nans(iso{roiIdx});
        F{roiIdx} = clean_nans(F{roiIdx});
    end
    
    %% smooth signals    
    if opt.smooth_signals
        for roiIdx = 1:opt.numROI
            iso{roiIdx} = gauss_smooth(iso{roiIdx},opt.smooth_sigma);
            F{roiIdx} = gauss_smooth(F{roiIdx},opt.smooth_sigma);
        end
    end

    %% Regress out isosbestic channel
    iti_per = get_ITI_period(t,synct,opt.iti_offset);
    F_subtr = cell(opt.numROI,1);
    for roiIdx = 1:opt.numROI
        beta = robustfit(iso{roiIdx}(iti_per),F{roiIdx}(iti_per));
        pred = iso{roiIdx} * beta(2) + beta(1);
        F_subtr{roiIdx} = F{roiIdx} - pred;
        
        figure('Position',[200 200 500 250]);
        subplot(1,2,1);
        plot(iso{roiIdx},F{roiIdx},'Color',[0 0 0 0.1]);
        xlabel('iso'); ylabel('sig');
        title('iso versus sig (dF/F)');
        subplot(1,2,2);
        plot(iso{roiIdx},F_subtr{roiIdx},'Color',[0 0 0 0.1]);
        title('iso versus sig subtr (dF/F)');
        xlabel('iso'); ylabel('sig (subtr)');
        sgtitle(session,'Interpreter','none');
        drawnow;
    end

    
    %% Save processed data
    
    PhotData = struct;
    PhotData.t = t;
    PhotData.iso = iso;
    PhotData.F = F;
    PhotData.F_subtr = F_subtr;
    PhotData.RoiName = opt.RoiName;
    PhotData.dat_orig = dat;
    PhotData.synct = synct;
    PhotData.sync_idx = round(synct*1000);
    PhotData.missing_idx = missing_idx; % indices where data was missing (Rig1 Doric system froze occasionally for ~2-30 sec)

    save(fullfile(paths.save_data,session),'PhotData');

end
toc

%% functions

function f0 = rolling_baseline(y,win,prct,stepsize)

f0 = nan(size(y));
sub_idx = 1:stepsize:numel(y);
for i = sub_idx
    idx_this = max(i-floor(win/2),1):min(numel(y),i+floor(win/2));
    f0(i) = prctile(y(idx_this),prct);
end
f0 = interp1(sub_idx,f0(sub_idx),1:numel(y))';
f0 = clean_nans(f0);


end

function iti_per = get_ITI_period(t,synct,t_offset)

iti_per = true(size(t));
for i = 1:numel(synct)
    iti_per(t>=synct(i) & t<=synct(i)+t_offset) = false;
end

end

function F = deltaFoverF(y,t,synct,iti_offset)

% get ITI times
iti_per = get_ITI_period(t,synct,iti_offset);

% get f0 from a rolling window only including ITI
y_filt = y;
y_filt(~iti_per) = nan;
delt = median(diff(t));
f0 = rolling_baseline(y_filt,30/delt,10,round(1/delt));

% compute deltaF/F
F = (y-f0)./f0;

end

function F_clean = clean_nans(F)
% clean leading and ending nans

% num leading nans
num_leading_nans = find(~isnan(F),1)-1;

% num ending nans
if isrow(F)
    num_ending_nans = find(~isnan(fliplr(F)),1)-1;
elseif iscolumn(F)
    num_ending_nans = find(~isnan(flipud(F)),1)-1;
end

F_clean = F;
F_clean(1:num_leading_nans) = F(num_leading_nans+1);
F_clean(end-num_ending_nans+1:end) = F(end-num_ending_nans);

end

function y_new = remove_outliers_z(y,thresh,tail)
% removes outliers, either one or both tails

yz = zscore(y);

x = 1:numel(y);
if strcmp(tail,'both')
    keep = yz>thresh(1) & yz<thresh(2);
    fprintf('\t%d outliers removed (z-score<%0.2f)\n',sum(yz<thresh(1)),thresh(1));
    fprintf('\t%d outliers removed (z-score>%0.2f)\n',sum(yz>thresh(2)),thresh(2));
elseif strcmp(tail,'low')
    keep = yz>thresh;
    fprintf('\t%d outliers removed (z-score<%0.2f)\n',sum(yz<thresh),thresh);
elseif strcmp(tail,'high')
    keep = yz<thresh;
    fprintf('\t%d outliers removed (z-score>%0.2f)\n',sum(yz>thresh),thresh);
end
y_new = interp1(x(keep),y(keep),x);

end

function dat = cut_end(dat,cutoff) 
% for cutting off the end of sessions e.g. when patch cord got unplugged
% cutoff is in seconds; everything after that is removed

kp_iso = dat.t_iso<cutoff;
kp_sig = dat.t_sig<cutoff;

dat.t_iso = dat.t_iso(kp_iso);
dat.t_sig = dat.t_sig(kp_sig);

for roiIdx = 1:numel(dat.iso)
    dat.iso{roiIdx} = dat.iso{roiIdx}(kp_iso);
    dat.sig{roiIdx} = dat.sig{roiIdx}(kp_sig);
end

end