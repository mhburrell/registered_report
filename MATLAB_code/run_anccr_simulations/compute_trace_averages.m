function out_struct = compute_trace_averages(events_in,times,discount_factor)
    %eventlog contains the following fields:
    %eventlog.events is the event identifier
    %eventlog.times is the time of the event in seconds
    times = times - min(times);

    sampling_rate = 0.1; %seconds
    num_events = max(events_in);
    num_samples = ceil(max(times)/sampling_rate);
    max_time = num_samples*sampling_rate;

    events = zeros(num_events,num_samples);
    for i = 1:num_events
        event_times = times(events_in == i);
        events(i,:) = histcounts(event_times,0:sampling_rate:max_time);
    end

    %compute the discount factor
    if nargin < 2
        discount_factor = 0.99;
    end
    %convert from per second to per sampling rate
    discount_factor = discount_factor^(sampling_rate);

    %compute discount vector
    discount_vector = discount_factor.^(0:num_samples-1);

    %compute the eligibility traces
    traces = zeros(num_events,num_samples);
    for i = 1:num_events
        trace_temp = conv(events(i,:),discount_vector,'full');
        traces(i,:) = trace_temp(1:num_samples);
    end

    %also calculate replacing eligibility traces
    traces_replacing = zeros(num_events,num_samples);
    for i = 1:num_events
        for j = 1:num_samples
            if events(i,j) > 0
                traces_replacing(i,j) = 1;
            else
                traces_replacing(i,j) = discount_factor*traces_replacing(i,max(1,j-1));
            end
        end
    end

    %any_event = sum((events,1) > 0&&events~=;
    %average_trace = mean(traces(:,any_event),2);
    average_trace = mean(traces,2);
    cond_average = zeros(num_events,num_events);
    for i = 1:num_events
        cond_average(i,:) = mean(traces(:,events(i,:) > 0),2);
    end
    cond_average_replacing = zeros(num_events,num_events);
    for i = 1:num_events
        cond_average_replacing(i,:) = mean(traces_replacing(:,events(i,:) > 0),2);
    end
    %replace NaNs with zeros
    average_trace(isnan(average_trace)) = 0;
    cond_average(isnan(cond_average)) = 0;
    cond_average_replacing(isnan(cond_average_replacing)) = 0;

    out_struct = struct('average_trace',average_trace,'cond_average',cond_average','cond_average_replacing',cond_average_replacing);