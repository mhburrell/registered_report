# %%
#efficient_td

import numpy as np
import pandas as pd
import os
from td_sim.td_c import temporal_difference_learning
from scipy.sparse import csc_matrix, lil_matrix, dok_matrix, csr_matrix

#get csc_sim
def get_csc_sim(data_file,in_rep):
    df = pd.read_parquet(data_file)
    dd = df[df['rep'] == in_rep]

    dt = 0.25 #time step in seconds
    max_time = max(dd['times'])+10 #max time in seconds
    time_bins = np.arange(0, max_time, dt)
    #create a pandas frame with time = time_bins and event = NA and remove = 0
    time_id = pd.DataFrame({'time':time_bins,'event':np.nan,'remove':0})

    #from dd, get events and times columns and put into a pandas frame and remove = 1
    event_times = pd.DataFrame({'event':dd['events'],'time':dd['times'],'remove':1})

    #identify omission events and remove rows where events = omission_id
    omission_id = dd['omission_id'].unique()

    #concatenate the two frames and sort by time,event
    time_id = pd.concat([time_id,event_times],axis=0)
    time_id = time_id.sort_values(by=['time','event']).reset_index(drop=True)


    #create two copies of time_id, called withomissions and withoutomissions
    withomissions = time_id.copy()
    withoutomissions = time_id.copy()

    #remove rows where events = omission_id using .loc 
    withoutomissions = withoutomissions.loc[~withoutomissions['event'].isin(omission_id)]

    #for both, fill event values down
    withomissions['event'] = withomissions['event'].ffill()
    withoutomissions['event'] = withoutomissions['event'].ffill()

    #for both, create a new column that is equal to the row number if remove = 1 and is NA otherwise
    withomissions['event_id'] = np.where(withomissions['remove']==1,withomissions.index,np.nan)
    withoutomissions['event_id'] = np.where(withoutomissions['remove']==1,withoutomissions.index,np.nan)

    #fill event_id values down
    withomissions['event_id'] = withomissions['event_id'].ffill()
    withoutomissions['event_id'] = withoutomissions['event_id'].ffill()

    #for both, create a new column called rel_t that is equal to row number - event_id
    withomissions['rel_t'] = withomissions.index - withomissions['event_id']
    withoutomissions['rel_t'] = withoutomissions.index - withoutomissions['event_id']

    #in withomissions, create a column that leads rel_t by 1
    withomissions['rel_t_lead'] = withomissions['rel_t'].shift(-1)

    #filter rows where remove = 1 and rel_t_lead is not equal to 1
    withomissions = withomissions[~((withomissions['remove']==1) & (withomissions['rel_t_lead']!=1))]

    #for both frames, drop rows where remove = 1
    withomissions = withomissions[withomissions['remove']==0]
    withoutomissions = withoutomissions[withoutomissions['remove']==0]

    #reset index
    withomissions = withomissions.reset_index(drop=True)
    withoutomissions = withoutomissions.reset_index(drop=True)

    #find locations in withomissions where rel_t is 1
    #create a vector of the same length as withomissions, with zeros where rel_t is not 1
    #and incrementing numbers where rel_t is 1
    time_id = np.where(withomissions['rel_t']==1,1,0)
    time_id = np.cumsum(time_id)
    time_id[withomissions['rel_t']!=1]=0

    #for with omissions, create a column called t that is equal to the row number
    #then keep only the rows where rel_t is equal to 1
    withomissions['t'] = withomissions.index


    withomissions = withomissions.loc[withomissions['rel_t']==1]

    #keep only the columns event and t for withomissions
    withomissions = withomissions[['event','t']].reset_index(drop=True)

    #create a numpy vector from withomissions of t
    #time_id = np.array(withomissions['t'])

    #for without omissions, keep time, event, rel_t columns
    #drop rows with NA in event column
    withoutomissions = withoutomissions[['time','event','rel_t']]
    withoutomissions = withoutomissions.dropna(subset=['event'])

    #event and rel_t are int
    withoutomissions['event'] = withoutomissions['event'].astype(int)
    withoutomissions['rel_t'] = withoutomissions['rel_t'].astype(int)

    csc_matrix = make_csc_matrix(withoutomissions)

    #create a vector the same height as withoutomissions
    reward_vector = np.zeros(len(withoutomissions), dtype=int)
    #set the value to 1 for rows of withoutomissions where event is 1 and rel_t is 1
    reward_vector[(withoutomissions['event'] == 1) & (withoutomissions['rel_t'] == 1)] = 1


    return csc_matrix, reward_vector, time_id

#%%

def make_csc_matrix(time_id):
    #drop time and get unique event and rel_t
    states = time_id.drop('time',axis=1).drop_duplicates().sort_values(by=['event','rel_t']).reset_index(drop=True)
    n_rows = len(time_id)
    n_cols = len(states)
    #create a sparse matrix with n_rows and n_cols, values will be binary
    time_matrix = dok_matrix((n_rows, n_cols), dtype=int)

    merged = time_id.merge(states.reset_index(), on=['event', 'rel_t'], how='left')

    for idx, state_idx in enumerate(merged['index']):
        time_matrix[idx, state_idx] = 1

    return time_matrix.tocsr()


# %%
if __name__ == "__main__":
    #to run call python new_td_sim.py data_file.parquet
    #read in data_file name from command line
    import sys
    data_file = sys.argv[1]
    rep = sys.argv[2]
    #rep is an integer
    rep = int(rep)
    #data_file = 'fixed_final.parquet'

    #remove the extension to get the name of the file
    save_name = data_file.split('.')[0]

    #print the name of the file
    print(save_name)

    #run over all combinations
    #reps 1 - 10
    #gamma 0.85 to 0.975 in 0.025 steps
    #alpha 0.01, 0.05, 0.1, 0.2

    #reps = range(1,2)
    gamma = [0.2,0.3,0.4,0.5,0.6,0.7,0.75,0.8,0.825,0.85,0.875,0.9,0.925,0.95,0.975,1]
    alpha = [0.001,0.01,0.02,0.05,0.1,0.2,0.25,0.4,0.5]

    import itertools
    import os

    csc_matrix, reward_vector, time_id = get_csc_sim(data_file, rep)
    time_id = time_id[1:].tolist()
    time_id.append(0)

    for g, a in itertools.product(gamma, alpha):
        print("rep: {}, gamma: {}, alpha: {}".format(rep, g, a))
        save_file_name = 'td_{}_rep_{}_gamma_{}_alpha_{}.parquet'.format(save_name, rep, g, a)
        #check if the file exists, if it does, skip
        if os.path.isfile(save_file_name):
            print("file exists, skipping")
            continue

        initial_weights = np.zeros((csc_matrix.shape[1],1))
        #convert reward_vecotr, a, g and initial_weights to float64
        reward_vector = reward_vector.astype(np.float64)
        a = np.float64(a)
        g = np.float64(g)
        initial_weights = initial_weights.astype(np.float64)
        _,rpe,value = temporal_difference_learning(csc_matrix, reward_vector, a, g, initial_weights)

        #write rpe, value to a parquet file
        df = pd.DataFrame({'rpe':rpe,'value':value, 't_id': time_id})
        #add a column t, which is the epoch number, starting at 1
        df['t'] = df.index + 1
        df['rep'] = rep
        df['alpha'] = a
        df['gamma'] = g
        df.to_parquet('td_{}_rep_{}_gamma_{}_alpha_{}.parquet'.format(save_name, rep, g, a))
# %%
