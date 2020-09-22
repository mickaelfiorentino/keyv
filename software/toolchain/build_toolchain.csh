#!/usr/bin/env tcsh
#-----------------------------------------------------------------------------
# Project    : Key-V
# Description: RV32I in-order KeyRing microarchitecture
#-----------------------------------------------------------------------------
# File       : build_toolchain.csh
# Author     : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab        : grm@polymtl
# Created    : 2019-04-10
# Last update: 2019-04-10
#-----------------------------------------------------------------------------
# Description: Build RISCV toolchain : 
#              + Binutils, Newlib, GCC
#              + RV32IM
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------
setenv RISCV_ISA      rv32im
setenv RISCV_TARGET   riscv32-unknown-elf
setenv RISCV_GCC      gcc-8.3.0
setenv RISCV_BINUTILS binutils-2.32
setenv RISCV_NEWLIB   newlib-3.1.0
setenv TOOLCHAIN_DIR  ./
setenv LIB_DIR        `readlink -f ${TOOLCHAIN_DIR}/lib`
setenv BUILD_DIR      `readlink -f ${TOOLCHAIN_DIR}/build`
setenv INSTALL_DIR    `readlink -f ${TOOLCHAIN_DIR}/${RISCV_ISA}`

#-----------------------------------------------------------------------------
# DOWNLOAD & EXTRACT 
#-----------------------------------------------------------------------------

mkdir -p ${LIB_DIR}
cd ${LIB_DIR}

# Binutils
if ( ! -d ${RISCV_BINUTILS} ) then
    wget     http://ftpmirror.gnu.org/binutils/${RISCV_BINUTILS}.tar.gz 
    tar -xvf ${RISCV_BINUTILS}.tar.gz
    rm  -rf  ${RISCV_BINUTILS}.tar.gz 
endif

# GCC
if ( ! -d ${RISCV_GCC} ) then
    wget     http://ftpmirror.gnu.org/gcc/${RISCV_GCC}/${RISCV_GCC}.tar.gz
    tar -xvf ${RISCV_GCC}.tar.gz
    rm  -rf  ${RISCV_GCC}.tar.gz
endif

# Newlib
if ( ! -d ${RISCV_NEWLIB} ) then
    wget     ftp://sourceware.org/pub/newlib/${RISCV_NEWLIB}.tar.gz
    tar -xvf ${RISCV_NEWLIB}.tar.gz    
    rm  -rf  ${RISCV_NEWLIB}.tar.gz    
endif

#-----------------------------------------------------------------------------
# BUILD 
#-----------------------------------------------------------------------------

set N=`nproc`
mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

# Binutils
if ( ! -d ${RISCV_BINUTILS} ) then

    mkdir ${RISCV_BINUTILS}
    cd ${RISCV_BINUTILS}
    
    ${LIB_DIR}/${RISCV_BINUTILS}/configure \
        --prefix=${INSTALL_DIR}  \
        --with-arch=${RISCV_ISA} \
        --target=${RISCV_TARGET} \
        --disable-multilib

    make -j$N && make install
    cd ${BUILD_DIR}
      
endif

# GCC & Newlib 
if ( !(-d ${RISCV_GCC}) || !(-d ${RISCV_NEWLIB}) ) then

    rm -rf ${RISCV_GCC} && mkdir ${RISCV_GCC}
    rm -rf ${RISCV_NEWLIB} && mkdir ${RISCV_NEWLIB} 

    cd ${RISCV_GCC}
    ${LIB_DIR}/${RISCV_GCC}/configure \
        --prefix=${INSTALL_DIR}  \        
        --with-arch=${RISCV_ISA} \
        --target=${RISCV_TARGET} \
        --with-newlib --disable-multilib --enable-languages=c
        
    make -j$N && make install
    cd ${BUILD_DIR}

    cd ${RISCV_NEWLIB}
    ${LIB_DIR}/${RISCV_NEWLIB}/configure \
        --prefix=${INSTALL_DIR} \
        --target=${RISCV_TARGET}

    make -j$N && make install
    cd ${BUILD_DIR}

    cd ${RISCV_GCC}
    ${LIB_DIR}/${RISCV_GCC}/configure \
        --prefix=${INSTALL_DIR}  \
        --with-arch=${RISCV_ISA} \
        --target=${RISCV_TARGET} \
        --with-newlib --disable-multilib --enable-languages=c
        
    make -j$N && make install
    cd ${BUILD_DIR}
          
endif


