# temporal_difference_learning.pyx
import numpy as onp
cimport numpy as np
from scipy.sparse import csr_matrix
from libc.stdlib cimport malloc, free

# Type definitions for better performance
DTYPE = onp.float64
ctypedef np.float64_t DTYPE_t

def temporal_difference_learning(object states, np.ndarray[DTYPE_t, ndim=1] rewards, double alpha, double gamma, np.ndarray[DTYPE_t, ndim=2] initial_weights):

    cdef int n_states = states.get_shape()[1]  # Number of states
    cdef int t = states.get_shape()[0]         # Number of epochs
    cdef int n_weights = initial_weights.shape[0]

    if n_weights != n_states:
        print('initial_weights is incorrect length')
        return

    cdef np.ndarray[DTYPE_t, ndim=2] w = onp.zeros((n_weights, 1), dtype=DTYPE)
    w[:, 0] = initial_weights[:, 0]
    
    cdef np.ndarray[DTYPE_t, ndim=1] rpe = onp.zeros(t, dtype=DTYPE)
    cdef np.ndarray[DTYPE_t, ndim=1] value = onp.zeros(t, dtype=DTYPE)

    cdef int i
    cdef double r, r_prime
    cdef np.ndarray[DTYPE_t, ndim=1] cue_vector, cue_vector_prime

    for i in range(t-1):
        r = rewards[i]
        r_prime = rewards[i+1]

        cue_vector = states[i, :].toarray().flatten().astype(DTYPE)
        cue_vector_prime = states[i+1, :].toarray().flatten().astype(DTYPE)

        rpe[i] = r + gamma * onp.dot(w[:, 0], cue_vector_prime) - onp.dot(w[:, 0], cue_vector)
        value[i] = onp.dot(w[:, 0], cue_vector)

        w[:, 0] += alpha * rpe[i] * cue_vector


    return w, rpe, value
