#!/usr/bin/env python
#
# Copyright 2008,2009 Free Software Foundation, Inc.
# 
# This file is part of GNU Radio
# 
# GNU Radio is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either asversion 3, or (at your option)
# any later version.
# 
# GNU Radio is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with GNU Radio; see the file COPYING.  If not, write to
# the Free Software Foundation, Inc., 51 Franklin Street,
# Boston, MA 02110-1301, USA.

import sys
from common import *

########################################################################
# Template for raw text data describing registers
# name addr[bit range inclusive] default optional enums
########################################################################
REGS_DATA_TMPL="""\
########################################################################
## address 0
########################################################################
sdio_bidirectional      0[7]     0      input, io
lsb_msb_first           0[6]     0      msb, lsb
soft_reset              0[5]     0
sleep_mode              0[4]     0
power_down_mode         0[3]     0
x_1r_2r_mode            0[2]     0      2r, 1r
pll_lock_indicator      0[1]     0
########################################################################
## address 1
########################################################################
filter_interp_rate      1[6:7]   0      1x, 2x, 4x, 8x
modulation_mode         1[4:5]   0      none, fs_2, fs_4, fs_8
zero_stuff_mode         1[3]     0
mix_mode                1[2]     1      complex, real
modulation_form         1[1]     0      e_minus_jwt, e_plus_jwt
data_clk_pll_lock_sel   1[0]     0      pll_lock, data_clk
########################################################################
## address 2
########################################################################
signed_input_data       2[7]     0      signed, unsigned
two_port_mode           2[6]     0      two_port, one_port
dataclk_driver_strength 2[5]     0      weak, strong
dataclk_invert          2[4]     0
oneportclk_invert       2[2]     0
iqsel_invert            2[1]     0
iq_first                2[0]     0      i_first, q_first
########################################################################
## address 3
########################################################################
data_rate_clock_output  3[7]     0      pll_lock, spi_sdo
pll_divide_ratio        3[0:1]   0      div1, div2, div4, div8
########################################################################
## address 4
########################################################################
pll_state               4[7]     0      off, on
auto_cp_control         4[6]     0      dis, enb
pll_cp_control          4[0:2]   0      50ua=0, 100ua=1, 200ua=2, 400ua=3, 800ua=7
########################################################################
## address 5 and 9
########################################################################
idac_fine_gain_adjust   5[0:7]   0
qdac_fine_gain_adjust   9[0:7]   0
########################################################################
## address 6 and A
########################################################################
idac_coarse_gain_adjust 6[0:3]   0
qdac_coarse_gain_adjust A[0:3]   0
########################################################################
## address 7, 8 and B, C
########################################################################
idac_offset_adjust_msb  7[0:7]   0
idac_offset_adjust_lsb  8[0:1]   0
idac_ioffset_direction  8[7]     0     out_a, out_b
qdac_offset_adjust_msb  B[0:7]   0
qdac_offset_adjust_lsb  C[0:1]   0
qdac_ioffset_direction  C[7]     0     out_a, out_b
"""

########################################################################
# Header and Source templates below
########################################################################
HEADER_TEXT="""
#import time

/***********************************************************************
 * This file was generated by $file on $time.strftime("%c")
 **********************************************************************/

\#ifndef INCLUDED_AD9777_REGS_HPP
\#define INCLUDED_AD9777_REGS_HPP

\#include <boost/cstdint.hpp>

struct ad9777_regs_t{
#for $reg in $regs
    #if $reg.get_enums()
    enum $(reg.get_name())_t{
        #for $i, $enum in enumerate($reg.get_enums())
        #set $end_comma = ',' if $i < len($reg.get_enums())-1 else ''
        $(reg.get_name().upper())_$(enum[0].upper()) = $enum[1]$end_comma
        #end for
    } $reg.get_name();
    #else
    boost::$reg.get_stdint_type() $reg.get_name();
    #end if
#end for

    ad9777_regs_t(void){
#for $reg in $regs
        $reg.get_name() = $reg.get_default();
#end for
    }

    boost::uint8_t get_reg(boost::uint8_t addr){
        boost::uint8_t reg = 0;
        switch(addr){
        #for $addr in sorted(set(map(lambda r: r.get_addr(), $regs)))
        case $addr:
            #for $reg in filter(lambda r: r.get_addr() == addr, $regs)
            reg |= (boost::uint8_t($reg.get_name()) & $reg.get_mask()) << $reg.get_shift();
            #end for
            break;
        #end for
        }
        return reg;
    }

    boost::uint16_t get_write_reg(boost::uint8_t addr){
        return (boost::uint16_t(addr) << 8) | get_reg(addr);
    }

    boost::uint16_t get_read_reg(boost::uint8_t addr){
        return (boost::uint16_t(addr) << 8) | (1 << 7);
    }
};

\#endif /* INCLUDED_AD9777_REGS_HPP */
"""

if __name__ == '__main__':
    regs = map(reg, parse_tmpl(REGS_DATA_TMPL).splitlines())
    open(sys.argv[1], 'w').write(parse_tmpl(HEADER_TEXT, regs=regs, file=__file__))
