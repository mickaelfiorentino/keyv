/*****************************************************************************
* Project    : Key-V                                                           
* Description: RV32IM in-order KeyRing microarchitecture                       
******************************************************************************
* File       : link.ld
* Author     : Mickaël FIORENTINO  <mickael.fiorentino@polymtl.ca>             
* Company    : grm@polymtl                                                     
* Created    : 2017-07-01                                                      
* Last update: <2019-04-12 Fri>
****************************************************************************** 
* Description: Linker script defining memory map
******************************************************************************/

OUTPUT_ARCH( "riscv" )

MEMORY
{
    IMEM  : ORIGIN = 0,   LENGTH = 32K 
    DMEM  : ORIGIN = 32K, LENGTH = 32K 
    IOPAD : ORIGIN = 64K, LENGTH = 1K
}

   /* define beginning and ending of data memory spaces */
   _heap_start    = ORIGIN(DMEM);
   _stack_start   = ORIGIN(DMEM) + LENGTH(DMEM);
   _iopad_start   = ORIGIN(IOPAD);

ENTRY(start)

SECTIONS
{
    /***********************
     * IMEM
     ***********************/
    . = ORIGIN(IMEM);
    
    .text ALIGN(4):
    {
        *(.text .text*)    
        . += 20; 
    } > IMEM

    .rodata ALIGN(4):
    {
        *(.rodata .rodata*)
    } > IMEM   
    
    .bss ALIGN(4):
    {
        *(.bss .bss*)
        *(.sbss .sbss*)
    } > IMEM

    /***********************
     * DMEM
     ***********************/
    . = ORIGIN(DMEM);

    .data ALIGN(4): 
    {
        *(.data .data*)        
        *(.sdata .sdata*) 
    } > DMEM

    /***********************
     * IOPAD
     ***********************/
    . = ORIGIN(IOPAD);
    
    .iopad ALIGN(4):
    {
        . += LENGTH(IOPAD);
    } > IOPAD
    
    _end_of_memory = .;
}
