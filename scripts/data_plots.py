#!/bin/env python3
#-----------------------------------------------------------------------------
# Project : KeyV
# File    : data_plots.py
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-04-28 Tue>
# Brief   : Script to plot data from csv summary
#-----------------------------------------------------------------------------
# [tcsh]% source setup.csh
# [tcsh]% ./scripts/data_plots.py
#-----------------------------------------------------------------------------
import os
import sys
import numpy as np
import statistics as stats
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker

#-----------------------------------------------------------------------------
#
#                                FUNCTIONS
#
#-----------------------------------------------------------------------------

def Bars(ax, title, x, data, color, val_format='{}'):
    """Basic bar plot"""

    ax.set_title(title, fontdict={'fontsize':font_size_title})
    ax.tick_params(axis='both', labelsize=font_size_title)
    ax.set_ylim(top=max(data) * 1.1)

    bars = ax.bar(x=x, height=data, width=bar_width, color=color, alpha=alpha_dark, linestyle='solid')

    # Add labels on top
    for bar in bars:
        height = bar.get_height()
        ax.annotate(val_format.format(height),
                    xy=(bar.get_x() + bar.get_width() / 2, height),
                    xytext=(0, 3),
                    textcoords="offset points",
                    ha='center', va='bottom',
                    fontsize=font_size_label)

def BarStacked(ax, title, x, data_list, color_list, label_list, val_format='{}'):
    """Stacked bar plot"""

    ax.set_title(title, fontdict={'fontsize':font_size_title})
    ax.tick_params(axis='both', labelsize=font_size_title)

    bars_list = []
    offset = np.zeros(len(data_list[0]))

    for data, color, label in zip(data_list, color_list, label_list):
        bars_list.append(ax.bar(x=x, height=data, bottom=offset, color=color, ec='white', label=label,
                                width=bar_width, alpha=alpha_dark, linestyle='solid', linewidth=0.1))
        offset += data

    ax.set_ylim(top=max(offset) * 1.1)

    # Add labels on top of last bar
    for bar, val in zip(bars_list[-1], offset):
        ax.annotate(val_format.format(val),
                    xy=(bar.get_x() + bar.get_width() / 2, val),
                    xytext=(0, 3),
                    textcoords="offset points",
                    ha='center', va='bottom',
                    fontsize=font_size_label)

    ax.legend(loc='best', fontsize=font_size_label)

#------------------------------------------------------------------------
#
#                                   AREA
#
#------------------------------------------------------------------------
def PlotArea ():
    """Plot area information from area_summary.csv"""

    csv_f    = os.getenv('KEYV_DATA') + "/area_summary.csv"
    figname  = os.getenv('KEYV_DATA') + "/area." + fig_ext

    csv_head = list(np.loadtxt(csv_f, delimiter=',', unpack=True, max_rows=1, dtype=np.str))
    head     = [x for x in csv_head if ( x != 'PROCESSOR' )]
    dat_c    = [csv_head.index(x) for x in csv_head if ( x != 'PROCESSOR' )]
    id_c     = [csv_head.index(x) for x in csv_head if ( x == 'PROCESSOR' )]
    csv_id   = np.loadtxt(csv_f, delimiter=',',unpack=True,skiprows=1,usecols=id_c, dtype=np.str)
    csv_dat  = np.loadtxt(csv_f, delimiter=',', unpack=True, skiprows=1, usecols=dat_c)

    cmb     = csv_dat[head.index('CMB')] + csv_dat[head.index('BUF')]
    seq     = csv_dat[head.index('SEQ')]
    tot     = csv_dat[head.index('TOTAL')]
    grp     = [cmb, seq]
    decode  = csv_dat[head.index('AR-IDECODE')]
    pc      = csv_dat[head.index('AR-PC')]
    rf      = csv_dat[head.index('AR-RF')]
    alu     = csv_dat[head.index('AR-ALU')]
    lsu     = csv_dat[head.index('AR-LSU')]
    sys     = csv_dat[head.index('AR-SYS')]
    perf    = csv_dat[head.index('AR-PERF')]
    rst_s   = csv_dat[head.index('AR-RST-SYNC')]
    perf_s  = csv_dat[head.index('AR-PERF-SYNC')]
    keyring = csv_dat[head.index('AR-KEYRING')]
    xbs     = csv_dat[head.index('AR-XBS')]
    xu0     = csv_dat[head.index('AR-XU0')]
    xu1     = csv_dat[head.index('AR-XU1')]
    xu2     = csv_dat[head.index('AR-XU2')]
    xu3     = csv_dat[head.index('AR-XU3')]
    xu4     = csv_dat[head.index('AR-XU4')]
    xu5     = csv_dat[head.index('AR-XU5')]
    modules = (decode + pc + rf + alu + lsu + sys + perf)
    oth     = cmb + seq - modules
    hier    = [rf, alu, decode, sys, perf, pc, lsu, oth]

    fig         = plt.figure(figsize=fig_size)
    fmt         = '{:.0f}'
    grp_labels  = ['CMB', 'SEQ']
    hier_labels = ['RF', 'ALU', 'DECODE', 'SYS', 'PERF', 'PC', 'LSU', 'OTHER']
    lbl_x       = csv_id
    lbl         = np.arange(len(lbl_x))
    grp_colors  = cmap_vir(np.linspace(0.3, 0.6, len(grp_labels)))
    hier_colors = cmap_civ(np.linspace(0.1, 0.9, len(hier_labels)))

    grp_ax = plt.subplot(121)
    grp_ax.set_xticks(lbl)
    grp_ax.set_xticklabels(lbl_x)
    hier_ax = plt.subplot(122, sharex=grp_ax)
    plt.subplots_adjust(left=0.15, right=0.99, bottom=0.1, top=0.9, hspace=0.3, wspace=0.4)

    BarStacked(grp_ax, 'Area (um2)', lbl, grp, grp_colors, grp_labels, fmt)
    BarStacked(hier_ax, 'Area (um2)', lbl, hier, hier_colors, hier_labels, fmt)

    plt.savefig(figname, dpi=fig_dpi, format=fig_ext, papertype='letter', orientation='landscape')
    plt.close()

#-----------------------------------------------------------------------------
#
#                                BENCHMARKS
#
#-----------------------------------------------------------------------------
def PlotBenchmarks ():
    """Plot benchmark scores & power analysis from benchmarks_summary.csv"""

    csv_f      = os.getenv('KEYV_DATA') + "/benchmarks_summary.csv"
    ps_figname = os.getenv('KEYV_DATA') + "/power_score." + fig_ext
    pg_figname = os.getenv('KEYV_DATA') + "/power_groups." + fig_ext
    pc_figname = os.getenv('KEYV_DATA') + "/power_categories." + fig_ext
    ph_figname = os.getenv('KEYV_DATA') + "/power_hier." + fig_ext

    csv_head = list(np.loadtxt(csv_f, delimiter=',', unpack=True, max_rows=1, dtype=np.str))
    head     = [x for x in csv_head if ( x != 'PROCESSOR' and x != 'BENCHMARK' )]
    dat_c    = [csv_head.index(x) for x in csv_head if ( x != 'PROCESSOR' and x != 'BENCHMARK' )]
    id_c     = [csv_head.index(x) for x in csv_head if ( x == 'PROCESSOR' or x == 'BENCHMARK' )]
    csv_id   = np.loadtxt(csv_f, delimiter=',', unpack=True, skiprows=1, usecols=id_c, dtype=np.str)
    csv_dat  = np.loadtxt(csv_f, delimiter=',', unpack=True, skiprows=1, usecols=dat_c)
    dat_dh   = csv_dat[:, csv_id[1] == 'dhrystone']
    dat_cm   = csv_dat[:, csv_id[1] == 'coremark']
    lbl_dh   = csv_id[0, csv_id[1]  == 'dhrystone']
    lbl_cm   = csv_id[0, csv_id[1]  == 'coremark']
    lbl_x    = lbl_dh
    lbl      = np.arange(len(lbl_x))

    #------------------------------------------------------------------------
    # Dhrystone
    #------------------------------------------------------------------------
    dh_exec      = dat_dh[head.index('PERIOD')] * dat_dh[head.index('CYCLES')]
    dh_tot       = dat_dh[head.index('PWR-TOT')] * 1e3
    dh_score     = 1 / (dh_exec * 1757)
    dh_score_pwr = dh_score / dh_tot
    dh_seq       = (dat_dh[head.index('PWR-SEQ')] + dat_dh[head.index('PWR-REG')]) * 1e3
    dh_ct        = dat_dh[head.index('PWR-CT')] * 1e3
    dh_cmb       = dat_dh[head.index('PWR-CMB')] * 1e3
    dh_grp       = [dh_ct, dh_seq, dh_cmb]
    dh_int       = dat_dh[head.index('PWR-INT')] * 1e3
    dh_sw        = dat_dh[head.index('PWR-SWITCH')] * 1e3
    dh_lk        = dat_dh[head.index('PWR-LEAK')] * 1e3
    dh_cat       = [dh_int, dh_lk, dh_sw]
    dh_decode    = dat_dh[head.index('PWR-IDECODE')] * 1e3
    dh_pc        = dat_dh[head.index('PWR-PC')] * 1e3
    dh_rf        = dat_dh[head.index('PWR-RF')] * 1e3
    dh_alu       = dat_dh[head.index('PWR-ALU')] * 1e3
    dh_lsu       = dat_dh[head.index('PWR-LSU')] * 1e3
    dh_sys       = dat_dh[head.index('PWR-SYS')] * 1e3
    dh_perf      = dat_dh[head.index('PWR-PERF')] * 1e3
    dh_rst_s     = dat_dh[head.index('PWR-RST-SYNC')] * 1e3
    dh_perf_s    = dat_dh[head.index('PWR-PERF-SYNC')] * 1e3
    dh_keyring   = dat_dh[head.index('PWR-KEYRING')] * 1e3
    dh_xbs       = dat_dh[head.index('PWR-XBS')] * 1e3
    dh_xu0       = dat_dh[head.index('PWR-XU0')] * 1e3
    dh_xu1       = dat_dh[head.index('PWR-XU1')] * 1e3
    dh_xu2       = dat_dh[head.index('PWR-XU2')] * 1e3
    dh_xu3       = dat_dh[head.index('PWR-XU3')] * 1e3
    dh_xu4       = dat_dh[head.index('PWR-XU4')] * 1e3
    dh_xu5       = dat_dh[head.index('PWR-XU5')] * 1e3
    dh_modules   = (dh_decode + dh_pc + dh_rf + dh_alu + dh_lsu + dh_sys + dh_perf)
    dh_oth       = dh_tot - dh_modules
    dh_hier      = [dh_rf, dh_alu, dh_decode, dh_sys, dh_perf, dh_pc, dh_lsu, dh_oth]

    #------------------------------------------------------------------------
    # CoreMark
    #------------------------------------------------------------------------
    cm_exec      = dat_cm[head.index('PERIOD')] * dat_cm[head.index('CYCLES')]
    cm_tot       = dat_cm[head.index('PWR-TOT')] * 1e3
    cm_score     = 1 / cm_exec
    cm_score_pwr = cm_score / cm_tot
    cm_seq       = (dat_cm[head.index('PWR-SEQ')] + dat_cm[head.index('PWR-REG')]) * 1e3
    cm_ct        = dat_cm[head.index('PWR-CT')] * 1e3
    cm_cmb       = dat_cm[head.index('PWR-CMB')] * 1e3
    cm_grp       = [cm_ct, cm_seq, cm_cmb]
    cm_int       = dat_cm[head.index('PWR-INT')] * 1e3
    cm_sw        = dat_cm[head.index('PWR-SWITCH')] * 1e3
    cm_lk        = dat_cm[head.index('PWR-LEAK')] * 1e3
    cm_cat       = [cm_int, cm_lk, cm_sw]
    cm_decode    = dat_cm[head.index('PWR-IDECODE')] * 1e3
    cm_pc        = dat_cm[head.index('PWR-PC')] * 1e3
    cm_rf        = dat_cm[head.index('PWR-RF')] * 1e3
    cm_alu       = dat_cm[head.index('PWR-ALU')] * 1e3
    cm_lsu       = dat_cm[head.index('PWR-LSU')] * 1e3
    cm_sys       = dat_cm[head.index('PWR-SYS')] * 1e3
    cm_perf      = dat_cm[head.index('PWR-SYS')] * 1e3
    cm_rst_s     = dat_cm[head.index('PWR-RST-SYNC')] * 1e3
    cm_perf_s    = dat_cm[head.index('PWR-PERF-SYNC')] * 1e3
    cm_keyring   = dat_cm[head.index('PWR-KEYRING')] * 1e3
    cm_xbs       = dat_cm[head.index('PWR-XBS')] * 1e3
    cm_xu0       = dat_cm[head.index('PWR-XU0')] * 1e3
    cm_xu1       = dat_cm[head.index('PWR-XU1')] * 1e3
    cm_xu2       = dat_cm[head.index('PWR-XU2')] * 1e3
    cm_xu3       = dat_cm[head.index('PWR-XU3')] * 1e3
    cm_xu4       = dat_cm[head.index('PWR-XU4')] * 1e3
    cm_xu5       = dat_cm[head.index('PWR-XU5')] * 1e3
    cm_modules   = (cm_decode + cm_pc + cm_rf + cm_alu + cm_lsu + cm_sys + cm_perf)
    cm_oth       = cm_tot - cm_modules
    cm_hier      = [cm_rf, cm_alu, cm_decode, cm_sys, cm_perf, cm_pc, cm_lsu, cm_oth]

    #------------------------------------------------------------------------
    # Scores + Score/Power
    #------------------------------------------------------------------------
    ps_fig      = plt.figure(figsize=fig_size)
    ps_format   = '{:.2f}'
    ps_s_dh_color = cmap_civ(np.linspace(0.1, 0.2, 1))
    ps_s_cm_color = cmap_vir(np.linspace(0.5, 0.6, 1))
    ps_dh_color = cmap_civ(np.linspace(0.3, 0.4, 1))
    ps_cm_color = cmap_vir(np.linspace(0.7, 0.8, 1))

    ps_s_dh_ax = plt.subplot(221)
    ps_s_dh_ax.set_xticks(lbl)
    ps_s_dh_ax.set_xticklabels(lbl_x)
    ps_s_cm_ax = plt.subplot(222, sharex=ps_s_dh_ax)
    ps_dh_ax = plt.subplot(223, sharex=ps_s_dh_ax)
    ps_cm_ax = plt.subplot(224, sharex=ps_s_dh_ax)
    plt.subplots_adjust(left=0.1, right=0.99, bottom=0.1, top=0.9, hspace=0.3)

    Bars(ps_s_dh_ax, 'Dhrystone (DMIPS)', lbl, dh_score, ps_s_dh_color, ps_format)
    Bars(ps_s_cm_ax, 'Coremark (CM)', lbl, cm_score, ps_s_cm_color, ps_format)
    Bars(ps_dh_ax, 'Dhrystone (DMIPS/mW)', lbl, dh_score_pwr, ps_dh_color, ps_format)
    Bars(ps_cm_ax, 'Coremark (CM/mW)', lbl, cm_score_pwr, ps_cm_color, ps_format)

    plt.savefig(ps_figname, dpi=fig_dpi, format=fig_ext, papertype='letter', orientation='landscape')
    plt.close()

    #------------------------------------------------------------------------
    # Power Groups
    #------------------------------------------------------------------------
    pg_fig       = plt.figure(figsize=fig_size)
    pg_labels    = ['CT', 'SEQ', 'CMB']
    pg_format    = '{:.2f}'
    pg_dh_colors = cmap_civ(np.linspace(0.1, 0.9, len(pg_labels)))
    pg_cm_colors = cmap_vir(np.linspace(0.2, 0.8, len(pg_labels)))

    pg_dh_ax = plt.subplot(121)
    pg_dh_ax.set_xticks(lbl)
    pg_dh_ax.set_xticklabels(lbl_x)
    pg_cm_ax = plt.subplot(122, sharex=pg_dh_ax)
    plt.subplots_adjust(left=0.05, right=0.99, bottom=0.1, top=0.9, hspace=0.3)

    BarStacked(pg_dh_ax, 'Dhrystone (mW)', lbl, dh_grp, pg_dh_colors, pg_labels, pg_format)
    BarStacked(pg_cm_ax, 'Coremark (mW)', lbl, cm_grp, pg_cm_colors, pg_labels, pg_format)

    plt.savefig(pg_figname, dpi=fig_dpi, format=fig_ext, papertype='letter', orientation='landscape')
    plt.close()

    #------------------------------------------------------------------------
    # Power Categories
    #------------------------------------------------------------------------
    pc_fig       = plt.figure(figsize=fig_size)
    pc_labels    = ['INTERNAL', 'LEAKAGE', 'SWITCH']
    pc_format    = '{:.2f}'
    pc_dh_colors = cmap_civ(np.linspace(0.1, 0.9, len(pc_labels)))
    pc_cm_colors = cmap_vir(np.linspace(0.2, 0.8, len(pc_labels)))

    pc_dh_ax = plt.subplot(121)
    pc_dh_ax.set_xticks(lbl)
    pc_dh_ax.set_xticklabels(lbl_x)
    pc_cm_ax = plt.subplot(122, sharex=pc_dh_ax)
    plt.subplots_adjust(left=0.05, right=0.99, bottom=0.1, top=0.9)

    BarStacked(pc_dh_ax, 'Dhrystone (mW)', lbl, dh_cat, pc_dh_colors, pc_labels, pc_format)
    BarStacked(pc_cm_ax, 'Coremark (mW)', lbl, cm_cat, pc_cm_colors, pc_labels, pc_format)

    plt.savefig(pc_figname, dpi=fig_dpi, format=fig_ext, papertype='letter', orientation='landscape')
    plt.close()

    #------------------------------------------------------------------------
    # Power Hierarchy
    #------------------------------------------------------------------------
    ph_fig       = plt.figure(figsize=fig_size)
    ph_labels    = ['RF', 'ALU', 'DECODE', 'SYS', 'PERF', 'PC', 'LSU', 'OTHER']
    ph_format    = '{:.2f}'
    ph_dh_colors = cmap_civ(np.linspace(0.1, 0.9, len(ph_labels)))
    ph_cm_colors = cmap_vir(np.linspace(0.2, 0.8, len(ph_labels)))

    ph_dh_ax = plt.subplot(121)
    ph_dh_ax.set_xticks(lbl)
    ph_dh_ax.set_xticklabels(lbl_x)
    ph_cm_ax = plt.subplot(122, sharex=ph_dh_ax)
    plt.subplots_adjust(left=0.05, right=0.99, bottom=0.1, top=0.9)

    BarStacked(ph_dh_ax, 'Dhrystone (mW)', lbl, dh_hier, ph_dh_colors, ph_labels, ph_format)
    BarStacked(ph_cm_ax, 'Coremark (mW)', lbl, cm_hier, ph_cm_colors, ph_labels, ph_format)

    plt.savefig(ph_figname, dpi=fig_dpi, format=fig_ext, papertype='letter', orientation='landscape')
    plt.close()


#-----------------------------------------------------------------------------
#
#                                   STA
#
#-----------------------------------------------------------------------------
def PlotSta ():
    """Plot a gantt-like chart showing KeyV STA results for each clock"""

    csv_f   = os.getenv('KEYV_DATA') + "/sta_summary.csv"
    figname = os.getenv('KEYV_DATA') + "/sta_avg." + fig_ext

    csv_head = list(np.loadtxt(csv_f, delimiter=',', unpack=True, max_rows=1, dtype=np.str))
    head     = [x for x in csv_head if ( x != 'LAUNCH' and x != 'CAPTURE' )]
    dat_c    = [csv_head.index(x) for x in csv_head if ( x != 'LAUNCH' and x != 'CAPTURE' )]
    id_c     = [csv_head.index(x) for x in csv_head if ( x == 'LAUNCH' or x == 'CAPTURE' )]
    csv_id   = np.loadtxt(csv_f, delimiter=',', unpack=True, skiprows=1, usecols=id_c, dtype=np.str)
    csv_dat  = np.loadtxt(csv_f, delimiter=',', unpack=True, skiprows=1, usecols=dat_c)

    setup_delay_dat = csv_dat[head.index('SETUP DELAY')]
    setup_slack_dat = csv_dat[head.index('SETUP SLACK')]
    hold_delay_dat  = csv_dat[head.index('HOLD DELAY')]
    hold_slack_dat  = csv_dat[head.index('HOLD SLACK')]
    lbl_launch      = csv_id[0, :]
    lbl_capture     = csv_id[1, :]

    mask_left  = [i for i in range(0, len(lbl_launch)-3, 4)]
    mask_up    = [i for i in range(1, len(lbl_launch)-2, 4)]
    mask_right = [i for i in range(2, len(lbl_launch)-1, 4)]
    mask_down  = [i for i in range(3, len(lbl_launch)-0, 4)]

    setup_dleft           = setup_delay_dat[mask_left]
    setup_dup             = setup_delay_dat[mask_up]
    hold_dright           = hold_delay_dat[mask_right]
    hold_ddown            = hold_delay_dat[mask_down]
    setup_sleft           = setup_slack_dat[mask_left]
    setup_sup             = setup_slack_dat[mask_up]
    hold_sright           = hold_slack_dat[mask_right]
    hold_sdown            = hold_slack_dat[mask_down]
    setup_lbl_capture     = lbl_capture[mask_left]
    setup_lbl_launch_left = lbl_launch[mask_left]
    setup_lbl_launch_up   = lbl_launch[mask_up]
    hold_lbl_capture      = lbl_launch[mask_right]
    hold_lbl_launch_right = lbl_launch[mask_right]
    hold_lbl_launch_down  = lbl_launch[mask_down]

    setup_dl = [setup_dleft[i]-setup_sleft[i] if setup_dleft[i] > 0 else 0
                for i in range(len(setup_dleft))]

    setup_sl = [setup_sleft[i] if setup_dleft[i] > 0 else 0 for i in range(len(setup_sleft))]

    setup_du = [setup_dup[i]-setup_sup[i] if setup_dup[i] > 0 else 0
                for i in range(len(setup_dup))]

    setup_su = [setup_sup[i] if setup_dup[i] > 0 else 0 for i in range(len(setup_sup))]

    hold_dr = [hold_dright[i]-hold_sright[i] if hold_dright[i] > 0 else 0
                for i in range(len(hold_dright))]

    hold_sr = [hold_sright[i] if hold_dright[i] > 0 else 0 for i in range(len(hold_sright))]

    hold_dd = [hold_ddown[i]-hold_sdown[i] if hold_ddown[i] > 0 else 0
                for i in range(len(hold_ddown))]

    hold_sd = [hold_sdown[i] if hold_ddown[i] > 0 else 0 for i in range(len(hold_sdown))]

    setup_del_left = np.array([setup_dl[0:6], setup_dl[6:12], setup_dl[12:18]])
    setup_del_up   = np.array([setup_du[0:6], setup_du[6:12], setup_du[12:18]])
    hold_del_right = np.array([hold_dr[0:6], hold_dr[6:12], hold_dr[12:18]])
    hold_del_down  = np.array([hold_dd[0:6], hold_dd[6:12], hold_dd[12:18]])
    setup_sla_left = np.array([setup_sl[0:6], setup_sl[6:12], setup_sl[12:18]])
    setup_sla_up   = np.array([setup_su[0:6], setup_su[6:12], setup_su[12:18]])
    hold_sla_right = np.array([hold_sr[0:6], hold_sr[6:12], hold_sr[12:18]])
    hold_sla_down  = np.array([hold_sd[0:6], hold_sd[6:12], hold_sd[12:18]])

    mean_setup_dl = np.mean(setup_del_left, axis=0)
    mean_setup_du = np.mean(setup_del_up, axis=0)
    mean_hold_dr  = np.mean(hold_del_right, axis=0)
    mean_hold_dd  = np.mean(hold_del_down, axis=0)
    mean_setup_sl = np.mean(setup_sla_left, axis=0)
    mean_setup_su = np.mean(setup_sla_up, axis=0)
    mean_hold_sr  = np.mean(hold_sla_right, axis=0)
    mean_hold_sd  = np.mean(hold_sla_down, axis=0)

    std_setup_l = np.std(setup_del_left + setup_sla_left, axis=0)
    std_setup_u = np.std(setup_del_up + setup_sla_up, axis=0)
    std_hold_r  = np.std(hold_del_right + hold_sla_right, axis=0)
    std_hold_d  = np.std(hold_del_down + hold_sla_down, axis=0)

    fig = plt.figure(figsize=(15,10))
    fig.subplots_adjust(top=0.9,bottom=0.1,left=0.1,right=0.9)

    labels = ['F', 'D', 'R', 'E', 'M', 'W']
    x = np.arange(len(labels))
    b = bar_width / 2

    setup_ax = plt.subplot(211)
    setup_ax.set_title('Setup', fontdict={'fontsize':font_size_title})
    setup_ax.set_xticks(x)
    setup_ax.set_xticklabels(labels)
    setup_ax.tick_params(axis='both', labelsize=font_size_label)
    setup_ax.grid(True, axis='y', color='lightgrey', ls=':', zorder=0)

    setup_bars = [
        setup_ax.bar(x=x-1.1*b, height=mean_setup_dl, bottom=0, width=b, label='Data Arrival Time',
                     align='edge', color='steelblue', alpha=alpha_dark, zorder=3),

        setup_ax.bar(x=x-1.1*b, height=mean_setup_sl, bottom=mean_setup_dl, width=b, label='Slack',
                     align='edge', color='steelblue', alpha=alpha_light, zorder=3,
                     yerr=std_setup_l, capsize=2),

        setup_ax.bar(x=x+0.1*b, height=mean_setup_du, bottom=0, width=b,
                     align='edge', color='steelblue', alpha=alpha_dark, zorder=3),

        setup_ax.bar(x=x+0.1*b, height=mean_setup_su, bottom=mean_setup_du, width=b,
                     align='edge', color='steelblue', alpha=alpha_light, zorder=3,
                     yerr=std_setup_u, capsize=2)
        ]

    hold_ax = plt.subplot(212, sharex=setup_ax)
    hold_ax.set_title('Hold', fontdict={'fontsize':font_size_title})
    hold_ax.set_xticks(x)
    hold_ax.set_xticklabels(labels)
    hold_ax.tick_params(axis='both', labelsize=font_size_label)
    hold_ax.grid(True, axis='y', color='lightgrey', ls=':', zorder=0)

    hold_bars = [
        hold_ax.bar(x=x-1.1*b, height=mean_hold_dr, bottom=0, width=b, label='Data Arrival Time',
                    align='edge', color='seagreen', alpha=alpha_dark, zorder=3),

        hold_ax.bar(x=x-1.1*b, height=mean_hold_sr, bottom=mean_hold_dr, width=b, label='Slack',
                    align='edge', color='seagreen', alpha=alpha_light, zorder=3,
                    yerr=std_hold_r, capsize=2),

        hold_ax.bar(x=x+0.1*b, height=mean_hold_dd, bottom=0, width=b,
                    align='edge', color='seagreen', alpha=alpha_dark, zorder=3),

        hold_ax.bar(x=x+0.1*b, height=mean_hold_sd, bottom=mean_hold_dd, width=b,
                    align='edge', color='seagreen', alpha=alpha_light, zorder=3,
                    yerr=std_hold_d, capsize=2)
    ]

    setup_start, setup_end = setup_ax.get_ylim()
    setup_ax.set_yticks(np.arange(setup_start, setup_end, 0.5))
    setup_ax.legend(loc='best', fontsize=font_size_label)
    setup_ax.set_ylabel('ns')

    hold_start, hold_end = hold_ax.get_ylim()
    hold_ax.set_yticks(np.arange(hold_start, hold_end, 0.5))
    hold_ax.legend(loc='best', fontsize=font_size_label)
    hold_ax.set_ylabel('ns')

    plt.savefig(figname, dpi=fig_dpi, format=fig_ext, papertype='letter', orientation='landscape')
    plt.close()

#-----------------------------------------------------------------------------
#
#                                  MAIN
#
#-----------------------------------------------------------------------------
if __name__ == '__main__':

    # Verify the environment
    try: os.environ['KEYV_HOME']
    except KeyError:
        print("Setup the environment with setup.csh prior to running this script")
        raise

    #------------------------------------------------------------------------
    # Global Parameters
    #------------------------------------------------------------------------
    fig_size        = (7,7)
    fig_size_half   = (4,7)
    fig_dpi         = 200
    fig_ext         = 'png'
    font_size_label = 12
    font_size_title = 14
    alpha_dark      = 0.85
    alpha_light     = 0.55
    bar_width       = 0.7
    bar_align       = 'edge'
    cmap_civ        = plt.cm.get_cmap('cividis', 64)
    cmap_vir        = plt.cm.get_cmap('viridis', 64)

    #------------------------------------------------------------------------
    # Plots
    #------------------------------------------------------------------------
    PlotArea()
    PlotBenchmarks()
    PlotSta()
