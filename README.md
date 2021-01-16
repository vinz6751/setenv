# setenv
This small program sets or displays the ATARI ST's TOS operating system's "the env" variable (located at address 0x4be). This can then be inherited by other programs using this variable thereafter.
It works the following way:
* With filename provided on as command line argument:
  Set the the_env TOS environment to the content of the file. The file must look like
  MYVAR1=myvalue<cr>c<lf>
  MYVAR2=myvalue<cr>c<lf>
  It will display the newly set environment before exiting.
* Without argument:
  If the "the_env" is not null, display the environment.
  Else try to set it from the contents of the "setenv.txt" file, located in the current directory (for auto folders, that means boot-drive root).
  
The program is designed to use as little memory as possible so it is convenient to use even with floppy disks. Therefore in memory it is laid out like this:
	Basepage
	jump to program code
	buffer where the environment is loaded from the file. this has a max length
	program code
When the program loads a file, it loads it into its buffer, sets the TOS's "the_env" to that buffer, then shrinks memorys to the minimum, then terminates as resident. So the program's code is stripped to save memory.
The size of the buffer is defined as a constant in the source file, defaulting to 256 bytes.	

The rationale for making this program is to support a change in the free operating system EmuTOS such that it becomes possible to set the PATH for the embedded CLI EmuCON2.
The program was written with Hisoft's Devpack in M68000 assembly language.
