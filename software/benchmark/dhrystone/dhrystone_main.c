// See LICENSE for license details.

//**************************************************************************
// Dhrystone bencmark
//--------------------------------------------------------------------------
//
// This is the classic Dhrystone synthetic integer benchmark.
//

#pragma GCC optimize ("no-inline")

/* #include <malloc.h> */
/* #include "util.h" */

#include "dhrystone.h"
#include "stdlib.h"
#include <string.h>

/* Global Variables: */
Rec_Pointer     Ptr_Glob,
                Next_Ptr_Glob;
int             Int_Glob;
Boolean         Bool_Glob;
char            Ch_1_Glob,
                Ch_2_Glob;
int             Arr_1_Glob [50];
int             Arr_2_Glob [50] [50];

Enumeration     Func_1 ();
  /* forward declaration necessary since Enumeration may not simply be int */

#ifndef REG
        Boolean Reg = false;
#define REG
        /* REG becomes defined as empty */
        /* i.e. no register variables   */
#else
        Boolean Reg = true;
#undef REG
#define REG register
#endif

/* Variables for time measurement */
long      Begin_Time,
          End_Time,
          User_Time;

/* Variables for instruction count */
long      Begin_Inst,
          End_Inst,
          User_Inst;

int main (int argc, char** argv)
/*****/
  /* main program, corresponds to procedures        */
  /* Main and Proc_0 in the Ada version             */
{
        One_Fifty       Int_1_Loc;
  REG   One_Fifty       Int_2_Loc;
        One_Fifty       Int_3_Loc;
  REG   char            Ch_Index;
        Enumeration     Enum_Loc;
        Str_30          Str_1_Loc;
        Str_30          Str_2_Loc;
  REG   int             Run_Index;
  REG   int             Number_Of_Runs;

  /* Initializations */
  Next_Ptr_Glob = (Rec_Pointer) malloc (sizeof (Rec_Type));
  Ptr_Glob = (Rec_Pointer) malloc (sizeof (Rec_Type));

  Ptr_Glob->Ptr_Comp                    = Next_Ptr_Glob;
  Ptr_Glob->Discr                       = Ident_1;
  Ptr_Glob->variant.var_1.Enum_Comp     = Ident_3;
  Ptr_Glob->variant.var_1.Int_Comp      = 40;
  strcpy (Ptr_Glob->variant.var_1.Str_Comp, 
          "DHRYSTONE PROGRAM, SOME STRING");
  strcpy (Str_1_Loc, "DHRYSTONE PROGRAM, 1'ST STRING");

  Arr_2_Glob [8][7] = 10;
        /* Was missing in published program. Without this statement,    */
        /* Arr_2_Glob [8][7] would have an undefined value.             */
        /* Warning: With 16-Bit processors and Number_Of_Runs > 32000,  */
        /* overflow may occur for this array element.                   */

  /* Arguments */
  Number_Of_Runs = NUMBER_OF_RUNS;
  print_pad("%d",Number_Of_Runs);
  
  /* Start timer & instruction count*/
  Start_Inst();
  Start_Timer();  

  /* Main Loop */
  for (Run_Index = 1; Run_Index <= Number_Of_Runs; ++Run_Index)
  {

      Proc_5();
      Proc_4();
      /* Ch_1_Glob == 'A', Ch_2_Glob == 'B', Bool_Glob == true */
      Int_1_Loc = 2;
      Int_2_Loc = 3;
      strcpy (Str_2_Loc, "DHRYSTONE PROGRAM, 2'ND STRING");
      Enum_Loc = Ident_2;
      Bool_Glob = ! Func_2 (Str_1_Loc, Str_2_Loc);
      /* Bool_Glob == 1 */
      while (Int_1_Loc < Int_2_Loc)  /* loop body executed once */
      {
          Int_3_Loc = 5 * Int_1_Loc - Int_2_Loc;
          /* Int_3_Loc == 7 */
          Proc_7 (Int_1_Loc, Int_2_Loc, &Int_3_Loc);
          /* Int_3_Loc == 7 */
          Int_1_Loc += 1;
      } /* while */
      /* Int_1_Loc == 3, Int_2_Loc == 3, Int_3_Loc == 7 */
      Proc_8 (Arr_1_Glob, Arr_2_Glob, Int_1_Loc, Int_3_Loc);
      /* Int_Glob == 5 */
      Proc_1 (Ptr_Glob);
      for (Ch_Index = 'A'; Ch_Index <= Ch_2_Glob; ++Ch_Index)
          /* loop body executed twice */
      {
          if (Enum_Loc == Func_1 (Ch_Index, 'C'))
              /* then, not executed */
          {
              Proc_6 (Ident_1, &Enum_Loc);
              strcpy (Str_2_Loc, "DHRYSTONE PROGRAM, 3'RD STRING");
              Int_2_Loc = Run_Index;
              Int_Glob = Run_Index;
          }
      }
      /* Int_1_Loc == 3, Int_2_Loc == 3, Int_3_Loc == 7 */
      Int_2_Loc = Int_2_Loc * Int_1_Loc;
      Int_1_Loc = Int_2_Loc / Int_3_Loc;
      Int_2_Loc = 7 * (Int_2_Loc - Int_3_Loc) - Int_1_Loc;
      /* Int_1_Loc == 1, Int_2_Loc == 13, Int_3_Loc == 7 */
      Proc_2 (&Int_1_Loc);
      /* Int_1_Loc == 5 */

  } /* Main Loop */


  /* Stop timer & Instruction count */
  Stop_Timer();
  Stop_Inst();
    

  /* Performances */
  User_Time = End_Time - Begin_Time;
  User_Inst = End_Inst - Begin_Inst;
  print_pad("%d", User_Time);
  print_pad("%d", User_Inst);

  /* Verifications */
  print_pad ("%d", Int_Glob);                               // Should be 5   
  print_pad ("%d", Bool_Glob);                              // Should be 1   
  print_pad ("%c", Ch_1_Glob);                              // Should be A   
  print_pad ("%c", Ch_2_Glob);                              // Should be B
  print_pad ("%d", Arr_1_Glob[8]);                          // Should be 7
  print_pad ("%d", Arr_2_Glob[8][7]);                       // Should be Number_Of_Runs + 10
  print_pad ("%d", (int) Ptr_Glob->Ptr_Comp);               // (implementation-dependent)
  print_pad ("%d", Ptr_Glob->Discr);                        // Should be 0
  print_pad ("%d", Ptr_Glob->variant.var_1.Enum_Comp);      // Should be 2
  print_pad ("%d", Ptr_Glob->variant.var_1.Int_Comp);       // Should be 17  
  print_pad ("%s", Ptr_Glob->variant.var_1.Str_Comp);       // Should be "DHRYSTONE PROGRAM, SOME STRING"
  print_pad ("%d", (int) Next_Ptr_Glob->Ptr_Comp);          // (implementation-dependent, same as above)
  print_pad ("%d", Next_Ptr_Glob->Discr);                   // Should be 0
  print_pad ("%d", Next_Ptr_Glob->variant.var_1.Enum_Comp); // Should be 1
  print_pad ("%d", Next_Ptr_Glob->variant.var_1.Int_Comp);  // Should be 18  
  print_pad ("%s", Next_Ptr_Glob->variant.var_1.Str_Comp);  // Should be "DHRYSTONE PROGRAM, SOME STRING"
  print_pad ("%d", Int_1_Loc);                              // Should be 5 
  print_pad ("%d", Int_2_Loc);                              // Should be 13
  print_pad ("%d", Int_3_Loc);                              // Should be 7
  print_pad ("%d", Enum_Loc);                               // Should be 1
  print_pad ("%s", Str_1_Loc);                              // Should be "DHRYSTONE PROGRAM, 1'ST STRING"
  print_pad ("%s", Str_2_Loc);                              // Should be "DHRYSTONE PROGRAM, 2'ND STRING"

  return 0;
}


Proc_1 (Ptr_Val_Par)
/******************/

REG Rec_Pointer Ptr_Val_Par;
    /* executed once */
{
  REG Rec_Pointer Next_Record = Ptr_Val_Par->Ptr_Comp;  
                                        /* == Ptr_Glob_Next */
  /* Local variable, initialized with Ptr_Val_Par->Ptr_Comp,    */
  /* corresponds to "rename" in Ada, "with" in Pascal           */
  
  structassign (*Ptr_Val_Par->Ptr_Comp, *Ptr_Glob); 
  Ptr_Val_Par->variant.var_1.Int_Comp = 5;
  Next_Record->variant.var_1.Int_Comp 
        = Ptr_Val_Par->variant.var_1.Int_Comp;
  Next_Record->Ptr_Comp = Ptr_Val_Par->Ptr_Comp;
  Proc_3 (&Next_Record->Ptr_Comp);
    /* Ptr_Val_Par->Ptr_Comp->Ptr_Comp 
                        == Ptr_Glob->Ptr_Comp */
  if (Next_Record->Discr == Ident_1)
    /* then, executed */
  {
    Next_Record->variant.var_1.Int_Comp = 6;
    Proc_6 (Ptr_Val_Par->variant.var_1.Enum_Comp, 
           &Next_Record->variant.var_1.Enum_Comp);
    Next_Record->Ptr_Comp = Ptr_Glob->Ptr_Comp;
    Proc_7 (Next_Record->variant.var_1.Int_Comp, 10, 
           &Next_Record->variant.var_1.Int_Comp);
  }
  else /* not executed */
    structassign (*Ptr_Val_Par, *Ptr_Val_Par->Ptr_Comp);
} /* Proc_1 */


Proc_2 (Int_Par_Ref)
/******************/
    /* executed once */
    /* *Int_Par_Ref == 1, becomes 4 */

One_Fifty   *Int_Par_Ref;
{
  One_Fifty  Int_Loc;  
  Enumeration   Enum_Loc;

  Int_Loc = *Int_Par_Ref + 10;
  do /* executed once */
    if (Ch_1_Glob == 'A')
      /* then, executed */
    {
      Int_Loc -= 1;
      *Int_Par_Ref = Int_Loc - Int_Glob;
      Enum_Loc = Ident_1;
    } /* if */
  while (Enum_Loc != Ident_1); /* true */
} /* Proc_2 */


Proc_3 (Ptr_Ref_Par)
/******************/
    /* executed once */
    /* Ptr_Ref_Par becomes Ptr_Glob */

Rec_Pointer *Ptr_Ref_Par;

{
  if (Ptr_Glob != Null)
    /* then, executed */
    *Ptr_Ref_Par = Ptr_Glob->Ptr_Comp;
  Proc_7 (10, Int_Glob, &Ptr_Glob->variant.var_1.Int_Comp);
} /* Proc_3 */


Proc_4 () /* without parameters */
/*******/
    /* executed once */
{
  Boolean Bool_Loc;

  Bool_Loc = Ch_1_Glob == 'A';
  Bool_Glob = Bool_Loc | Bool_Glob;
  Ch_2_Glob = 'B';
} /* Proc_4 */


Proc_5 () /* without parameters */
/*******/
    /* executed once */
{
  Ch_1_Glob = 'A';
  Bool_Glob = false;
} /* Proc_5 */
