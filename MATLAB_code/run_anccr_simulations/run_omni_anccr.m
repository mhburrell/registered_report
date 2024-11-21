function run_omni_anccr(array_index,input_file,save_directory)

trial_table = parquetread(input_file);
%trial_table  = trial_table(trial_table.rep<81,:);

% IRI = mean(trial_table.IRI);
% Tratio = (0.05:0.05:5);
% T = Tratio*IRI;
%discount_factor=exp(-1./T);

discount_factor = 0.5:0.005:0.999;
%n_params = length(discount_factor);
n_chunks = 12;

%divide the discount factors into chunks
param_chunk = cell(n_chunks,1);
for i = 1:n_chunks
    param_chunk{i} = discount_factor(i:n_chunks:end);
end
param_chunk = param_chunk{array_index};
for g = 1:length(param_chunk)

    discount_factor = param_chunk(g);

    w = 0:0.05:1;
    theta = 0:0.01:0.5;

    [w,theta] = ndgrid(w,theta);
    vars = {w,theta};
    vars = cellfun(@(x) x(:), vars, 'UniformOutput', false);
    [w,theta] = vars{:};

    reps = unique(trial_table.rep);

    for i = 1:length(reps)
        rep = reps(i);
        file_name = sprintf('omni_results_g_%.6f_rep_%u.parquet',discount_factor,rep);
        %check if file exists in save_directory
        if isfile(fullfile(save_directory,file_name))
            continue
        end
        disp(file_name);
        elog = trial_table(trial_table.rep==rep,:);
        ephases = unique(trial_table.ephase);
        phase_results = cell(length(ephases),1);
        for j = 1:length(ephases)
            ephase = ephases(j);
            in_eventlog = elog(elog.ephase==ephase,:);
            disc_sum = compute_trace_averages(in_eventlog.events,in_eventlog.times,discount_factor);
            param_results = cell(length(w),1);
            for k = 1:length(w)
                param_results{k} = omniANCCR_precalc_discount(disc_sum,w(k),theta(k));
            end
            result = vertcat(param_results{:});
            result.ephase(:)=ephase;
            phase_results{j}=result;
        end
        result = vertcat(phase_results{:});
        result.rep(:)=rep;
        result.discount_factor(:)=discount_factor;
        parquetwrite(fullfile(save_directory,file_name),result);
    end
end
