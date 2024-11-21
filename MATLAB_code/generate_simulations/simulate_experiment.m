function trial_table = simulate_experiment
n_trials = 4000;

trial_table = table;
iti = 30;
for i = 1:100
    rng(i);
    e1 = generate_anccr_eventlog(n_trials,[0.375,0.5,0,0.125],[1,0.25,0,0],iti);
    e2 = generate_anccr_eventlog(n_trials,[0.3,0.2083,0.2,0.2917],[1,0.6,0.375,0],iti);
    e3 = generate_anccr_eventlog(n_trials,[0.20,0.17,0.46,0.17],[1,0.75,0.375,0],iti);
    e4 = generate_anccr_eventlog(n_trials,[0.20,0.17,0.46,0.17],[1,0.75,0.375,0],iti);
    e_table = join_event_struct(e1,e2,e3,e4);
    e_table.rep(:) = i;
    trial_table = [trial_table;e_table];
end
trial_table.t_id = (1:height(trial_table))';

cues = trial_table(trial_table.events~=1&trial_table.events~=6,:);
cues.times = cues.times - 3;
cues.events = repmat(7,size(cues.ephase));
big_tt = [trial_table;cues];
big_tt = sortrows(big_tt,[7,2]);
big_tt.t_id = (1:height(big_tt))';

e4_7 = find(big_tt.ephase==4&big_tt.events==7);
remove_id = randsample(e4_7,length(e4_7)*.15);
big_tt(remove_id,:)=[];

trial_table = big_tt;
