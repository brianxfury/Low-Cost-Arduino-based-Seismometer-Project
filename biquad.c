/*****************************************************************************
*
* Name: biquad.c
*
* Description: Provides a template for implementing IIR filters as a cacade
* of second-order sections, aka, "biquads".
*
* by Grant R. Griffin
* Copyright 2007-2010, Iowegian International Corporation
* (http://www.iowegian.com)
*
*                          The Wide Open License (WOL)
*
* Permission to use, copy, modify, distribute and sell this software and its
* documentation for any purpose is hereby granted without fee, provided that
* the above copyright notice and this license appear in all source copies. 
* THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT EXPRESS OR IMPLIED WARRANTY OF
* ANY KIND. See http://www.dspguru.com/wol.htm for more information.
*
******************************************************************************/

#include "biquad.h"


/******************************************************************************
* function: _filter
*
* Description:
*    Filters a single sample using a single biquad
*
* Parameters:
*    x           sample input
*    coeffs      biquad coefficients
*    z           delay line input/output
*
* Return Value:
*    filtered sample output
******************************************************************************/

static inline biquad_sample_t _filter(biquad_sample_t x,
                                       const BIQUAD_COEFFS coeffs,
                                       biquad_z_t z)
{
    biquad_sample_t w, y;
   
    w =  -z[0] * coeffs[BIQUAD_A2];
    y =   z[0] * coeffs[BIQUAD_B2];
    w -=  z[1] * coeffs[BIQUAD_A1];
    w +=  x;
    y +=  z[1] * coeffs[BIQUAD_B1];
    y +=     w * coeffs[BIQUAD_B0];
    z[0] = z[1];
    z[1] = w;
   
    return y;
}

/******************************************************************************/
biquad_sample_t biquad_filter(biquad_sample_t x, const BIQUAD_COEFFS *coeffs,
                              biquad_z_t *z, int nbiquads)
{
    int i;

    for (i = 0; i < nbiquads; i++) {
        x = _filter(x, coeffs[i], z[i]);
    }
   
    return x;
}

/******************************************************************************/
void biquad_clear(biquad_z_t *z, int nbiquads, biquad_sample_t initial)
{
    int i, j;
   
    for (i = 0; i < nbiquads; i++) {
        for (j = 0; j < BIQUAD_NZ; j++) {
            z[i][j] = initial;
        }
    }
} 
