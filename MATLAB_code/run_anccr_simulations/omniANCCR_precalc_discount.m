function out_table = omniANCCR_precalc_discount(in_struct,w,threshold)

Mij = in_struct.cond_average;
Mi = in_struct.average_trace;
Dij = in_struct.cond_average_replacing';

% Subtract baseline elig. from avg. elig. to find successor rep.
PRC = Mij-repmat(Mi,1,numel(Mi));
% Calculate predecessor rep from successor rep.
SRC = PRC.*repmat(Mi',numel(Mi),1)./repmat(Mi,1,numel(Mi));
SRC(isnan(SRC))=0;

% Calculate net contingency, weighted sum of SRC/PRC
NC = w*SRC+(1-w)*PRC;

out_table = table;
out_table.event = (1:numel(Mi))';
out_table.DA = zeros(size(out_table.event));
%out_table.discount_factor = repmat(discount_factor,size(out_table.event));
out_table.threshold = repmat(threshold,size(out_table.event));
out_table.w = repmat(w,size(out_table.event));

% Indicator for whether an event is associated with another event
for je = 1:numel(Mi)
    Iedge = NC(:,je)>threshold;
    Iedge(je) = false;

    % calculate ANCCR for every event
    % Rjj is externally driven; the magnitude of stimulus an animal just experienced
    R = zeros(size(Dij));
    ANCCR = R;
    R(:,1)=1;
    %R(:,3:4)=1;

    Delta = Dij(:,je);

    for ke = 1:numel(Mi)
        % Update edge indicator
        Iedge_ke = NC(:,ke)>threshold;
        Iedge_ke(ke) = false;
        % update ANCCR
        ANCCR(ke,:) = NC(ke,:).*R(ke,:);
        ANCCR(ke,:) = ANCCR(ke,:) - sum(ANCCR.*Delta.*repmat(Iedge_ke,1,numel(Mi)));
    end



    out_table.DA(je) = sum(ANCCR(je,:));
end
