/****************************************************************************
*
* Name: biquad.c
*
* Description: Provides a template for implementing IIR filters as a cacade
* of second-order sections, aka, "biquads".
*
* by Grant R. Griffin
* Copyright 2007-2010, Iowegian International Corporation
* (http:**www.iowegian.com)
*
*                          The Wide Open License (WOL)
*
* Permission to use, copy, modify, distribute and sell this software and its
* documentation for any purpose is hereby granted without fee, provided that
* the above copyright notice and this license appear in all source copies. 
* THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT EXPRESS OR IMPLIED WARRANTY OF
* ANY KIND. See http:**www.dspguru.com*wol.htm for more information.
*
*****************************************************************************/

#define BIQUAD_NCOEFF 6
#define BIQUAD_NZ     2

enum BIQUAD_INDICES {
    /* coefficient indices (change to suit) */
    BIQUAD_B0,
    BIQUAD_B1,     
    BIQUAD_B2,   
    BIQUAD_A0,
    BIQUAD_A1,
    BIQUAD_A2
};


typedef float biquad_sample_t;                            
    /* biquad sample type (change to suit) */

typedef biquad_sample_t BIQUAD_COEFFS[BIQUAD_NCOEFF];
    /* coefficients for a single biquad */

typedef biquad_sample_t biquad_z_t[BIQUAD_NZ];
    /* delay line for a single biquad */


/******************************************************************************
* function: biquad_filter
*
* Description:
*    Filters a single sample using a cascade of biquads
*
* Parameters:
*    x           sample input
*    coeffs      biquad coefficients
*    z           delay line input*output
*    nbiquads    number of biquad sections
*
* Return Value:
*    filtered sample output
******************************************************************************/

biquad_sample_t biquad_filter(biquad_sample_t x, const BIQUAD_COEFFS *p_coeffs,
                              biquad_z_t *p_z, int nbiquads);

/******************************************************************************
* function: biquad_clear
*
* Description:
*    Clears the delay line of a set of cascaded biquads
*
* Parameters:
*    z           pointer to the biquads' delay line
*    nbiquads    number of biquad sections
*
* Return Value:
*    none
******************************************************************************/

void biquad_clear(biquad_z_t *p_z, int nbiquads, biquad_sample_t y);
