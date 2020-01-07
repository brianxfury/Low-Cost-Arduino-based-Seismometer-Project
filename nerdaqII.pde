//
// nerdaqII  version 0.30  6 September 2012  Martin L. Smith
//
// This code replaces bsudaq and includes additional filtering capability
// documented below. 
//
//
// I Oversampling a/d
//
// for a 16 MHz clock, the adc rate is 9615.4 sps and the 512-stack is
// 18.78 sps.  the final sample rate is our only assurance that we
// haven't skipped interrupts.
//
// we actually use a 1024-long window stepped at 512.  using the
// double window should (i think) put the rectangular window's first
// spectral zero at the nyquist frequency for the final sample rate.
//
// 24 July 2011  went to 4 x 512 windows.  the aggregate window is 2048 points
//   and is stepped at 512.  the first zero should be at 18.78/4 or about
//   4.7 Hz.
//
// worth noting that we use the 512 window to set the output sample rate
// while the number of 512s that are combined scales the spectral response.
//
//
// II Denoising Filter (N)
//
// N is a low-pass filter with a transition zone of 0.25 to 2.5Hz.
// It's function is simply to remove some high-frequency electronic noise
// without introducing objectionable ringing..
// We hope it won't substantially alter seismic signals.
// It's implemented as a 16-tap minimum-phase FIR with a design stopband
// attenuation of 30 dB and an achieved attenuation of 40+ dB.
// This is not the filter used in bsudaq.
//
//
// III Detrending Filter (B)
//
// B is a 2 pole IIR butterworth high-pass with a 30 second cutoff.  It's
// function is to remove baseline drift and ameliorate step offsets.  It
// should not alter seismic signals.
//
//
// IV Long-period Boost Filter (L)
//
// L is an second-order butterworth band-pass filter with cutoffs of 0.1 and
// 0.05 Hz and a stopband attenuation of 60 dB.  It's function is to boost signals
// at periods of 5-20 seconds by an amount set by the adjustable
// boost factor, BfdB, below.
//
//
// V Boost Factor, BfdB
//
// BfdB is a scale factor, specified in dB, by which the output of the
// long-period boost filter, L, is multiplied before be combined with the
// non-boosted output.  It's value roughly determines how much longer-period
// surface waves are boosted before being added to the body wave data.
// It's specified in dB so BfdB = 0 corresponds to a multiplier of 1.0 and
// BfdB = 20 corresponds to a mutiplier of 10.0.
//

#include <avr/io.h>
#include <avr/interrupt.h>


// debugging support

// add free memory info to output stream
#include "MemoryFree.h"
#define FREEMEMCHECK
#undef FREEMEMCHECK

// allow/suppress detrend filter
const int do_detrend = 1;


// arduino definitions

const int ledPin = 13;

// global variables for oversampling and the running window

volatile unsigned long runningsum;
volatile unsigned short runningcount;
volatile unsigned long prev3;
volatile unsigned long prev2;
volatile unsigned long prev1;
volatile unsigned long current_sum;

volatile boolean next_sample_ready;
volatile unsigned int next_sample;

//
// coefficients for filter N
//
extern "C" {
#include "denoise_filter.h"
};

const unsigned int ncoeff = sizeof(coeff) / sizeof(coeff[0]);
float lagarray[ncoeff];
unsigned short first_adc = 10; // initial samples to skip
unsigned short first_loop = 1; // deal with the first composite sample


// load defs for the two iir biquad sets

extern "C" {
#include "biquad.h"
#include "boost_filter.h"
#include "detrend_filter.h"
};

biquad_z_t boost_z[BOOST_BIQUADS_SIZE];
biquad_z_t detrend_z[DETREND_BIQUADS_SIZE];


// the boost factor and filter mode: not const so we can alter them at
// runtime though at the moment we just keep them fixed.

float BfdB = 20.0;
int filtermode = 4;
float Bfmult;


void initADC() {

  // don't depend on global initializers
  runningsum = 0;
  runningcount = 0;
  prev1 = prev2 = prev3 = 0;
  current_sum = 0;

  next_sample_ready = false;
  next_sample = 0;

  // internal AVcc ref, no left adj, channel 0
  ADMUX = _BV(REFS0);
    
  // ACME off, free-running mode
  ADCSRB = 0;

  // enable ad, intr, auto
  // set divisor to 128
  // start first conversion
  ADCSRA = _BV(ADEN) | _BV(ADIE) | _BV(ADATE)
    | _BV(ADPS0) | _BV(ADPS1) | _BV(ADPS2)
    | _BV(ADSC);
}


ISR(ADC_vect) {
  byte low = ADCL;
  byte high = ADCH;
  if(first_adc) {
    --first_adc;
    return;
  }
  runningsum += low + (high << 8);
  if(++runningcount == 512) {
    if(first_loop)
      prev3 = prev2 = prev1 = runningsum;
    else {
      prev3 = prev2;
      prev2 = prev1;
      prev1 = current_sum;
    }
    current_sum = runningsum;
    // if we sum two we have to unshift 4
    // if we sum four we have to unshift 5
    next_sample =
      (unsigned int) ((current_sum + prev1 + prev2 + prev3) >> 5);
    runningsum = 0;
    runningcount = 0;
    next_sample_ready = true;
  }
}


void setup() {
  unsigned int i;
  Serial.begin(9600);
  Serial.flush();
  first_loop = 1;
  first_adc = 10;
  initADC();
  pinMode(ledPin, OUTPUT);
  digitalWrite(ledPin, HIGH);
}


float process_sample(const float y) {
    float z;
    float fL;
    unsigned int i;

    if(filtermode == 1)
        return y;

    if(first_loop) {

      first_loop = 0;
      
        // flood the lag array with the first value
        for(i = 1; i < ncoeff; i++)
            lagarray[i] = y;

        // initialize the biquad delay lines
        biquad_clear(detrend_z, DETREND_BIQUADS_SIZE, (biquad_sample_t) y);
        biquad_clear(boost_z, BOOST_BIQUADS_SIZE, (biquad_sample_t) y);

        // compute the multiplicative gain factor
        Bfmult = pow(10.0, BfdB / 20.0);

    } else {
      
        // update the bucket brigade
        for(i = ncoeff - 1; i > 0; i--)
            lagarray[i] = lagarray[i - 1];
	lagarray[0] = y;

    }

    // apply N to the raw sample series
    z = 0.0;
    for(i = 0; i < ncoeff; i++)
        z += lagarray[i] * coeff[i];

    if(filtermode == 2)
        return z;

    // apply B to the output of N (if allowed)
    if(do_detrend)
        z = biquad_filter(z, detrend_biquads, detrend_z, DETREND_BIQUADS_SIZE)
            * detrend_biquads_g;

    if(filtermode == 3)
        return z;

    // apply L to the output of BN
    fL = biquad_filter(z, boost_biquads, boost_z, BOOST_BIQUADS_SIZE)
        * boost_biquads_g;
    // compute and return the weighted trace
    return z + Bfmult * fL;
}


// we drive the led pin (13) high during inter-sample idle times.  i hope that
// we'll be able to tell if we have enough cpu overhead by looking to see if
// the led is flashing at 18.78 Hz.

// the halfscale correction adjusts the B filter output to be 32768
// instead of 0.

// for version 0.1 of the code, freeMemory() returns 1319 (out of a
// maximum of 2000).

void loop() {
  unsigned int filtered_signal;
  const float halfscale = 32768.0;

  if(next_sample_ready == false) {
      digitalWrite(ledPin, HIGH);
      return;
  }
  digitalWrite(ledPin, LOW);
  next_sample_ready = false;

  filtered_signal = (unsigned int) (process_sample(float(next_sample)
                                                   - halfscale) + halfscale);

  #ifdef FREEMEMCHECK
  Serial.print(freeMemory(), DEC);
  Serial.print("  ");
  #endif

  Serial.println(filtered_signal, DEC);
  Serial.flush();
}
