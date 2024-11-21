#Code for running TD in python
#%% 
import numpy as np
from scipy.sparse import csr_matrix

#if not using numba, comment out the following line and remove njit from the function definition
def temporal_difference_learning(states,rewards,alpha,gamma,initial_weights):

    #n_weights is the number of weights in the model

    n_states = states.get_shape()[1] #number of states

    #initialise weights
    #check if initial_weights is correct length
    n_weights = initial_weights.shape[0]
    if n_weights != n_states:
        print('initial_weights is incorrect length')
        return
    

    #intialise weight matrix, w
    #w is a (n_weights x t) matrix, where t is the number of epochs
    t = states.get_shape()[0]
    w = np.zeros((n_weights,1))
    w = np.ascontiguousarray(w)
    #set initial weights
    w[:,0] = initial_weights[:,0]

    #initialise prediction error and value
    # rpe is a (t x 1) vector, where t is the number of epochs
    # value is a (t x 1) vector, where t is the number of epochs
    rpe = np.zeros((t,1))
    value = np.zeros((t,1))

    #iterate through epochs
    for i in range(t-1):
        r = rewards[i] #reward at epoch i
        r_prime = rewards[i+1] #reward at epoch i+1
        
        #cue_vector = states[i,:]
        cue_vector = np.ascontiguousarray(states[i,:].toarray().flatten())
        #cue_vector_prime = states[i+1,:]
        cue_vector_prime = np.ascontiguousarray(states[i+1,:].toarray().flatten())
        #calculate rpe
        rpe[i] = r + gamma*np.dot(w[:,0],cue_vector_prime) - np.dot(w[:,0],cue_vector)
        #calculate value
        value[i] = np.dot(w[:,0],cue_vector)
        #update weights
        w[:,0] = w[:,0] + alpha*rpe[i]*cue_vector

        #every 100 epochs, print the percentage of epochs completed
        if i % 10000 == 0:
            print(i/t)
        
    return w,rpe,value

#