# setenv
This small program sets the ATARI ST's BIOS "the env" variable (located at address 0x4be) and injects it into the basepage of the program executed via the exec_os vector (i.e. the GEM). This environment can then be inherited by other programs using this variable thereafter as the AES passes it along.

It works the following way:
* With filename provided on as command line argument:
  Set the the_env TOS environment to the content of the file. The file must look like
  ```
  MYVAR1=myvalue<cr><lf>
  MYVAR2=myvalue<cr><lf>
  ```

* Without argument:
  The environment is loaded from the file "setenv.txt" file, located in the current directory (for auto folder programs, that means boot-drive root).
  
The program is designed to use as little memory as possible so it is convenient to use even with floppy disks. 
When the program loads a file, it loads it into its buffer, sets the TOS's "the_env" to that buffer, patches the environment pointer in the BASEPAGE of the OS, then shrinks memorys to the minimum, then terminates as resident. So some of the program's code to load/parse file is stripped to save memory.

The rationale for making this program is to support a change in the free operating system EmuTOS such that it becomes possible to set the PATH for the embedded CLI EmuCON2.
The program was written with Hisoft's Devpack in M68000 assembly language.
