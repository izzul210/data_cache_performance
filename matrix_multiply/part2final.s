sizeN:    .word 128
zero:
	    .double 0.0

.text 
  .global _start 
_start:
   BL CONFIG_VIRTUAL_MEMORY

   // Step 1-3: configure PMN0,PMN1,PMN2 to count cycles
   MOV R0, #0 // Write 0 into R0 then PMSELR
   MCR p15, 0, R0, c9, c12, 5 // Write 0 into PMSELR selects PMN0
   MOV R1, #0x11 // Event 0x11 is CPU cycles
   MCR p15, 0, R1, c9, c13, 1 // Write 0x11 into PMXEVTYPER (PMN0 measure CPU cycles) 

   MOV R0, #1 // Write 1 into R0 then PMSELR
   MCR p15, 0, R0, c9, c12, 5 // Write 1 into PMSELR selects PMN1
   MOV R1, #0x3 // Event 0x3 is Level 1 data cache misses
   MCR p15, 0, R1, c9, c13, 1 // Write 0x3 into PMXEVTYPER (PMN1 measure L1 data cache misses) 

   MOV R0, #2 // Write 2 into R0 then PMSELR
   MCR p15, 0, R0, c9, c12, 5 // Write 2 into PMSELR selects PMN2
   MOV R1, #0x6 // Event 0x6 is Number of load instructions executed
   MCR p15, 0, R1, c9, c13, 1 // Write 0x6 into PMXEVTYPER (PMN2 measure Number of load instructions executed) 

   // Step 4: enable PMN0,PMN1,PMN2
   mov R0, #7 // PMN0,PMN1,PMN2 is bit 0,1 & 2 of PMCNTENSET 
   MCR p15, 0, R0, c9, c12, 1 // Setting bit 0 of PMCNTENSET enables PMN0,PMN1,PMN2
   

   // Step 5: clear all counters and start counters
   mov r0, #3 // bits 0 (start counters) and 1 (reset counters)
   MCR p15, 0, r0, c9, c12, 0 // Setting PMCR to 3


   // Step 6: code we wish to profile using hardware counters 
     //r3 = i, r4 = j, r5 = k, r6 = address of C[i][j], r12 = address of A[i][k] and B[k][j], r7 = sizeN, r9= zero//
 
  //128*128 = 16384 = 0x4000//
  LDR r0, =0x01000000    //load matrx C in R0
  LDR r1, =0x01004000    //load matrix A in R1
  LDR r2, =0x01008000    //load matrix B in R2

  SUB sp,sp,#24       //creates room on stack for 5 registers
  STR r4, [sp,#12]    //save R4 on stack 
  STR r5, [sp, #8]    //save R5 on stack
  STR r6, [sp, #4]    //save R6 on stack
  STR r7, [sp, #0]    //save R7 on stack
  STR r8, [sp, #16]   //save R8 on stack
  STR r9, [sp, #20]   //save R9 on stack

  LDR r9, =zero   //load value 0.0 in r9
  LDR r7, sizeN             //load size N into R7
      .word 0xED995B00         //FLDD D5, [r9, #0] ;D5 = 0.0

  MOV r3, #0           //i = 0
  L1: MOV r4, #0       //j = 0
      
  L2: MOV r5, #0       //k = 0
      .word 0xED994B00         //FLDD D4, [r9, #0] ;D4 = 0.0

  //for C[i][j]//
  MUL r8, r3, r7            //i*N
  ADD r6, r8, r4            //i*N + j
  ADD r6, r0, r6, LSL#3     //r6 = byte address of C[i][j]
   .word 0xED961B00         //FLDD D1, [r6, #0] ;D1 = 8 bytes of C[i][j]

   //A[i][k] & B[k][j]//
   L3: 
   MUL r8, r3, r7           //i*N
   ADD r12, r8, r5           //i*N + k
   ADD r12, r1, r12, LSL#3   //r12 = byte address of A[i][k]
   .word 0xED9C2B00          //FLDD D2, [r12, #0] ;D2 = 8 bytes of A[i][k]

   MUL r8, r5, r7            //k*N
   ADD r12, r8, r4           //k*N + j
   ADD r12, r2, r12, LSL#3   //r12 = byte address of B[k][j]
   .word 0xED9C3B00          //FLDD D3, [r12, #0] ;D3 = 8 bytes of B[k][j]

    .word 0xEE222B03       //FMULD D2, D3, D2   ;D2 = A[i][k]*B[k][j]
	.word 0xEE344B02	   //FADD  D4, D4, D2   ;D4(sum) = sum + A[i][k]*B[k][j]
    .word 0xEE341B05       //FADD D1, D4, D5    ;D1(C[i][j]) = sum + 0
	

	ADD r5,r5,#1          //k++
	CMP r5, r7            
	BLT L3                //if (k < N) go to L3
	.word 0xED861B00      //FSTD D1,[r6,#0]  ;C[i][j] = D1
	 
	ADD r4,r4,#1         //j++
	CMP r4, r7 
	BLT L2               //if (j < N) go to L2
	
	ADD r3,r3,#1         //i++
	CMP r3, r7            
	BLT L1               //if (i < N) go to L1

    
    LDR r4, [sp,#12]    //save R4 on stack 
    LDR r5, [sp, #8]    //save R5 on stack
    LDR r6, [sp, #4]    //save R6 on stack
    LDR r7, [sp, #0]    //save R7 on stack
    LDR r8, [sp, #16]   //save R8 on stack
	LDR r9, [sp, #20]   //save R9 on stack
	ADD sp,sp,#24       //creates room on stack for 5 registers




   // Step 7: stop counters
   mov r0, #0 
   MCR p15, 0, r0, c9, c12, 0 // Write 0 to PMCR to stop counters

   // Step 8-10: Select PMN0 and read out result into R3, PMN1 result into R4, PMN2 result into R5 
   mov r0, #0 // PMN0
   MCR p15, 0, R0, c9, c12, 5 // Write 0 to PMSELR
   MRC p15, 0, R3, c9, c13, 2 // Read PMXEVCNTR into R3 

   mov r0, #1 // PMN1
   MCR p15, 0, R0, c9, c12, 5 // Write 0 to PMSELR
   MRC p15, 0, R4, c9, c13, 2 // Read PMXEVCNTR into R4 

   mov r0, #2 // PMN2
   MCR p15, 0, R0, c9, c12, 5 // Write 0 to PMSELR
   MRC p15, 0, R5, c9, c13, 2 // Read PMXEVCNTR into R5
   

end: b end // wait here 

