%generate parameter space to be tested
%run before using run_anccr_model.m 

Tratio = [0.1:0.1:1.4,2,5];
alpha_anccr = [0.01,0.02,0.05,0.1,0.2];
k = [nan]; %nan uses new definition
w = 0:0.1:1;
theta = [0.1:0.1:0.8];
alpha_r = [0.01,0.1,0.2,1];

[Tratio,alpha_anccr,k,w,theta,alpha_r] = ndgrid(Tratio,alpha_anccr,k,w,theta,alpha_r);
vars = {Tratio, alpha_anccr, k, w, theta, alpha_r};
vars = cellfun(@(x) x(:), vars, 'UniformOutput', false);
[Tratio, alpha_anccr, k, w, theta, alpha_r] = vars{:};

param_table = table(Tratio, alpha_anccr, k, w, theta, alpha_r);
param_table.p_id = (1:height(param_table))';

parquetwrite('anccr_param_table.parquet',param_table);