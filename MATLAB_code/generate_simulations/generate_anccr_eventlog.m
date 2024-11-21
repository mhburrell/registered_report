function e_struct = generate_anccr_eventlog(n_trials,cue_prop,cue_rew_prob,iti)

isi = 2;
reward_id = 1;
fixed_iti = 3.1;
exp_iti_mean = iti;
max_iti = iti*3;

% n_trials = 4000;
% n_rewarded_cues = 4;
% n_unrewarded_cues = 2;

%p_reward = 1;

cue_ids = (1:length(cue_prop))+1;
omission_id = max(cue_ids)+1;

trials = randsample(cue_ids,n_trials,true,cue_prop);

for i = 1:n_trials
    cue = trials(i);
    p_reward = cue_rew_prob(cue-1);
    rew = binornd(1,p_reward);
    if rew
        outcome = reward_id;
    else
        outcome = omission_id;
        %probabilistic removal
        omission_p = binornd(1,p_reward);
        if ~omission_p
            p_reward = 0;
        end
        if p_reward ==0 
            outcome = nan;
        end
    end

    if i == 1
        eventlog = [cue,3,0];
        outcome_row = [outcome,3+isi,rew];
        eventlog = [eventlog;outcome_row];
    else
        prev_time = eventlog(end,2);
        iti_rnd = min(exprnd(exp_iti_mean),max_iti);
        iti = fixed_iti+iti_rnd;
        new_events = [cue,prev_time+iti,0;
                      outcome,prev_time+iti+isi,rew];
        eventlog = [eventlog; new_events];
    end
end


%remove rows with nans
nanrows = isnan(eventlog(:,1));
eventlog(nanrows,:) = [];

rew_times = eventlog(eventlog(:,3)==1,2);
IRI = mean(diff(rew_times));
omidx = [omission_id, reward_id];

e_struct = struct;
e_struct.eventlog = eventlog;
e_struct.IRI = IRI;
e_struct.omidx = omidx;
