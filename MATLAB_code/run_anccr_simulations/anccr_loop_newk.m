function [Delta, Eij, Mij, PRC, SRC, NC, ANCCR, Mi, DA, Rs, Ei] = anccr_loop(ntime, k, T, eventlog, omidx, omtrue, Delta, Eij, Mij, PRC, SRC, NC, numevents, exact_mean_or_not, alpha, gamma, ANCCR, nstimuli, Imct, Mi, minimumrate, R, w, nevent_for_edge, threshold, optolog, DA, beta, Rs, alpha_r, ss, samplingtime, Ei, samplinginterval, nextt, numsampling)
%%
if isnan(k)
    mean_iri = mean(diff(eventlog(eventlog(:,3)==1,2)));
    if ~isstruct(alpha)
        k = (1-(1-alpha)^(samplinginterval/mean_iri))/alpha;
    end
end

for jt = 1:ntime
    %if isnan(k)
    %k = 1-(1-alpha)^(samplinginterval/
    %k = 1/T(jt);
    %if jt == 1
    %    k = 0.01;
    %else
    %    k = samplinginterval/(eventlog(jt,2)-eventlog(jt,1));
    %end
    %end
    skip = false;
    je = eventlog(jt,1);

    if ismember(je,omidx(:,1))
        if ~omtrue(omidx(:,1)==je)
            if jt-1==0
                pause(0.01);
            end
            Delta(:,jt) = Delta(:,jt-1);
            Eij(:,jt) = Eij(:,jt-1);
            Mij(:,:,jt) = Mij(:,:,jt-1);
            PRC(:,:,jt) = PRC(:,:,jt-1);
            SRC(:,:,jt) = SRC(:,:,jt-1);
            NC(:,:,jt) = NC(:,:,jt-1);
            skip = true;
        end
    end

    if ~skip
        numevents(je) = numevents(je)+1;
        if exact_mean_or_not == 0
            if ~isstruct(alpha)
                alphat = alpha;
            else
                % if alpha is structure, alpha exponentially decreases from
                % alpha.init to alpha.min w/ alpha.exponent decrease constant
                alphat = exp(-alpha.exponent*(jt-0))*(alpha.init-alpha.min)+alpha.min;
            end
        else
            alphat = 1/numevents(je);
        end

        if jt>1
            % update delta w/prev value
            Delta(:,jt) = Delta(:,jt-1)*gamma(jt)^(eventlog(jt,2)-eventlog(jt-1,2));
            % update instantaneous elig. trace w/prev value
            Eij(:,jt) = Eij(:,jt-1)*gamma(jt)^(eventlog(jt,2)-eventlog(jt-1,2));
            % update average elig. trace w/prev value
            Mij(:,:,jt) = Mij(:,:,jt-1);
            % update anccr w/prev value
            ANCCR(~ismember(1:nstimuli,je),:,jt) = ANCCR(~ismember(1:nstimuli,je),:,jt-1);
        end
        % Indicator for whether event has recently happened
        % Delta resets to one at every instance of event w/o cumulative sum
        Delta(je,jt) = 1;
        % Increment inst. elig. trace by 1 for event that occurred
        Eij(je,jt) = Eij(je,jt)+1;
        % Update avg. elig. trace
        Mij(:,je,jt) = Mij(:,je,jt)+alphat*(Eij(:,jt)-Mij(:,je,jt)).*Imct(je);

        % Subtract baseline elig. from avg. elig. to find successor rep.
        PRC(:,:,jt) = Mij(:,:,jt)-repmat(Mi(:,jt),1,nstimuli);
        % Calculate predecessor rep from successor rep.
        SRC(:,:,jt) = PRC(:,:,jt).*repmat(Mi(:,jt)',nstimuli,1)./repmat(Mi(:,jt),1,nstimuli);
        % Zero out values that may approach -Inf
        belowminrate = Mi(:,jt)/T(jt)<minimumrate;
        SRC(belowminrate,:,jt) = 0;

        % something to make sure only calculating contingency and R after experiencing
        % first outcome
        PRC(numevents==0,:,jt) = 0;
        PRC(:,numevents==0,jt) = 0;
        SRC(numevents==0,:,jt) = 0;
        SRC(:,numevents==0,jt) = 0;
        R(:,numevents==0) = 0;
        R(numevents==0,:) = 0;

        % Calculate net contingency, weighted sum of SRC/PRC
        NC(:,:,jt) = w*SRC(:,:,jt)+(1-w)*PRC(:,:,jt);

        % Indicator for whether an event is associated with another event
        startIdx = max(1,jt-nevent_for_edge);
        Iedge = mean(NC(:,je,startIdx:jt),3)>threshold;
        Iedge(je) = false;

        % once the cause of reward state is revealed, omission state of that
        % reward state can be used for calculation of ANCCR. Before that,
        % omission state is ignored
        if ismember(je,omidx(:,2)) && sum(Iedge)>0
            omtrue(omidx(:,2)==je) = omtrue(omidx(:,2)==je) | true;
        end

        % calculate ANCCR for every event
        % Rjj is externally driven; the magnitude of stimulus an animal just experienced
        R(je,je) = eventlog(jt,3);

        for ke = 1:nstimuli
            % Update edge indicator
            if nevent_for_edge ==0
                Iedge_ke=NC(:,ke,jt)>threshold;
            else
                Iedge_ke = mean(NC(:,ke,startIdx:jt),3)>threshold;
            end
            Iedge_ke(ke) = false;
            % update ANCCR
            ANCCR(ke,:,jt) = NC(ke,:,jt).*R(ke,:)-...
                sum(ANCCR(:,:,jt).*Delta(:,jt).*repmat(Iedge_ke,1,nstimuli));
        end


        if ~(optolog(jt,1) == 1) % If target is not inhibited, normal DA
            DA(jt) = sum(ANCCR(je,:,jt).*Imct');
        else % If target is inhibited, replace DA
            DA(jt) = optolog(jt,2);
        end

        if ismember(je,omidx(:,1))
            je_om = find(je==omidx(:,1));
            % if the current state is omission of j, R(omission,j) = R(j,j)
            R(je,omidx(je_om,2)) = R(omidx(je_om,2),omidx(je_om,2));
            % omission state is an MCT
            Imct(je) = true;
        end
        % This must come after opto s.t. Imct is not formed before opto applied
        Imct(je) = Imct(je) | DA(jt)+beta(je)>threshold;

        % Update estimated reward value
        Rs(:,:,jt) = R;
        if DA(jt)>=0
            % For positive DA response, use standard update rule
            R(:,je) = R(:,je)+alpha_r*(eventlog(jt, 3)-R(:,je));
        else
            % For negative DA response, use overprediction update rule
            if any(Iedge)
                R(Iedge,je) = R(Iedge,je) -...
                    alpha_r*R(Iedge,je).*((Delta(Iedge,jt)./numevents(Iedge)) ./ sum((Delta(Iedge,jt)./numevents(Iedge))));
            else
                R(:,je) = R(:,je);
            end
        end

    end

    % Update sample eligibility trace (Mi-)
    if jt<ntime
        % Time to sample baseline b/t events
        % subsamplingtime2 = samplingtime(samplingtime>=eventlog(jt,2) & samplingtime<eventlog(jt+1,2));

        if ntime-jt==1
            ss_idx = ss{jt};
            ss_idx = ss_idx(1:end-1);
            subsamplingtime = samplingtime(ss_idx);
        else
            subsamplingtime = samplingtime(ss{jt});
        end

        Ei(:,jt+1) = Ei(:,jt)*gamma(jt)^samplinginterval;
        if ~isempty(subsamplingtime)
            for jjt = nextt:jt
                if ismember(eventlog(jjt,1),omidx(:,1))
                    if ~omtrue(omidx(:,1)==eventlog(jjt,1))
                        continue
                    end
                end
                Ei(eventlog(jjt,1),jt+1) = Ei(eventlog(jjt,1),jt+1)+...
                    gamma(jt).^(subsamplingtime(1)-eventlog(jjt,2));
            end
            nextt = jt+1;
        end

        % update alpha of sample eligibility trace
        if exact_mean_or_not == 0
            if ~isstruct(alpha)
                alphat = alpha;
            else
                alphat = exp(-alpha.exponent*(jt-0))*(alpha.init-alpha.min)+alpha.min;
                if isnan(k)
                    k = (1-(1-alphat)^(samplinginterval/mean_iri))/alphat;


                end
            end
        else
            alphat = 1/(numsampling+1);
        end

        % Update avg. sample eligibility trace
        Mi(:,jt+1) = Mi(:,jt)+k*alphat*(Ei(:,jt+1)-Mi(:,jt));
        for iit = 2:length(subsamplingtime)
            if exact_mean_or_not == 0
                if ~isstruct(alpha)
                    alphat = alpha;
                else
                    alphat = exp(-alpha.exponent*(jt-0))*(alpha.init-alpha.min)+alpha.min;
                end
            else
                alphat = 1/(numsampling+iit);
            end

            Ei(:,jt+1) = Ei(:,jt+1)*gamma(jt)^samplinginterval;
            Mi(:,jt+1) = Mi(:,jt+1)+k*alphat*(Ei(:,jt+1)-Mi(:,jt+1));
        end
        numsampling = numsampling+length(subsamplingtime);
    end
end
end