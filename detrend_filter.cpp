#include "detrend_filter.h"

// detrend_biquads

float detrend_biquads[DETREND_BIQUADS_SIZE][6] = {
    {
         1.0000000000000000e+000,     // B0
        -1.0000000000000000e+000,     // B1
         0.0000000000000000e+000,     // B2
         1.0000000000000000e+000,     // A0
        -9.8340998054256923e-001,     // A1
         0.0000000000000000e+000      // A2
    }
};
// detrend_biquads gain

float detrend_biquads_g  =  9.9170499027128467e-001;


