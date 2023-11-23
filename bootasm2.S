# When the PC starts, the processor is essentially emulating an 8086 processor, i.e. 
# a 16-bit processor.  So our initial boot loader code is 16-bit code that will 
# eventually switch the processor into 32-bit mode.

# This code is linked to assume a starting address of 0x7C00 which is where the BIOS
# will load a boot segment.

.code16                         # Assemble for 16-bit mode
.globl start
start:
    jmp     real_start

# Write to the console using BIOS.
# 
# Input: SI contains the address of the null-terminated string to be displayed

cons_write:
    movb    $0x0e, %ah           # 0x0e is the INT 10h BIOS call to output the value contained in AL to screen

cons_write_rpt:
    movb    (%si), %al          # Load the byte at the location contained in the SI register into AL   
    inc     %si                 # Add 1 to the value in SI
    cmp     $0, %al             # Compare the value in AL with 0
    jz      cons_write_done     # If it is zero, then we are done
    int     $0x10               # Output the character in AL to the screen
    jmp     cons_write_rpt      # and continue

cons_write_done:                # Something that is called will never return 
    ret                         # until a 'ret' instruction is encountered.  Labels do 
                                # not give a program any structure.  They just give a 
                                # memory location a name that we can use in our code. 

cons_write_crlf:
    movb    $0x0e, %ah          # Output CR
    movb    $0x0d, %al
    int     $0x10
    movb    $0x0a, %al          # Output LF
    int     $0x10
    ret

cons_writeline:
    call    cons_write
    call    cons_write_crlf
    ret    

# The following labels will hold all input funcitonality that is present in the program
user_sector_input: 
    xor     %dx, %dx                    # This register is cleared and will be tasked with holding the user input number
    xor     %bx, %bx                    # The bx registed is cleared to 0 and will be used to store values if an error occurs
record_user_sector_input:
    xor     %ah, %ah                    # Clears ah register ready to use
    int     $0x16                       # interupt is called to get the keyboard input
        
    cmpb    $0x0D, %al                  # Compare the value in AH with 0x0D (code for enter key) 
    je      read_int_finish             # If they are equal and the enter key was pressed, jump to Finish_Integer

    movb    $0x0E, %ah                  # Moves user input from $0x0E into the %ah register ready to display
    int     $0x10                       # Trigger interrupt 0x10 to display the number inputted

    cmpb    $0x30, %al                  # Check the if the value inputted  is equal or above 0
    jb      sector_input_error          # Jump if value enteres is below 0 to the sector_input_error to display an error message

    cmpb    $0x39, %al                  # Check if the value of entered character is equal or below 9
    ja      sector_input_error          # Jump if value entered is above 9 to the sector_input_error to display an error message
    
    imul    $10, %dx                    # Multiplies the values currently in dx by 10
    sub     $0x30, %al                  # Subtracting 30 from al as this converts the ASCII input into an integer to store.        
    movb    $0, %ah                     # Clear the ah register by moving 0 into it
    addb    %al, %dl                    # Adding the value contained in al the new integer to the dl register 

    jmp     record_user_sector_input    # Loops the function to allow the input of multiple digits

read_int_finish:                        # Function returns to the label before
    ret

sector_input_error:   
    movw $1, %bx                                    # adds the value of 1 into the bx register to indicate an error occured.
    call cons_write_crlf                            # Call the cons_write_crlf to go to the next line
    movw $boot_input_error_msg, %si                 # Moves the si register to point at the boot_input_error_msg ready to display
    jmp cons_writeline                              # Jump to the cons_writeline which will display what si is pointing and go to the next line

more_than_4_digit_error:
    call    cons_write_crlf                         # Call the cons_write_crlf to go to the next line
    movw    $more_than_4_digits_error_msg, %si      # Moves the si register to point at the boot_input_error_msg ready to display
    call    cons_write                              # Call cons_write to display the .string message above
    call    cons_write_crlf                         # Call the cons_write_crlf to go to the next line
    jmp     enter_sector                            # Go to the enter_sector label


user_sector_amount_input:
    xor     %dx, %dx                            # This register is cleared and will be tasked with holding the user input number
    xor     %bx, %bx                            # The bx registed is cleared to 0 and will be used to store values if an error occurs

record_user_sector_amount_input:
    xor     %ah, %ah                            # Clears ah register ready to use
    
    int     $0x16                               # interupt is called to get the keyboard input  
    
    cmpb    $0x0D, %al                          # Compare the value in AH with 0x0D (code for enter key) 
    je      finish_sector_amount_input          # If they are equal and the enter key was pressed, jump to Finish_Integer

    movb    $0x0E, %ah                          # Moves user input from $0x0E into the %ah register ready to display
    int     $0x10                               # Trigger interrupt 0x10 to display the number inputted

    cmpb    $0x01, %al                          # Check the if the value inputted  is equal or above 1
    jb      sector_amount_input_error           # Jump if value enteres is below 1 to the sector_amount_input_error to display an error message

    cmpb    $0x39, %al                          # Check if the value of entered character is equal or below 9
    ja      sector_amount_input_error           # Jump if value entered is above 9 to the sector_amount_input_error to display an error message
    
    imul    $10, %dx                            # Multiplies the values currently in dx by 10
    sub     $0x30, %al                          # Subtracting 30 from al as this converts the ASCII input into an integer to store.        
    movb    $0, %ah                             # Clear the ah register by moving 0 into it
    addb    %al, %dl                            # Adding the value contained in al the new integer to the dl register 

    jmp     record_user_sector_amount_input     # Loops the function to allow the input of multiple digits

finish_sector_amount_input: 
    cmpw    $0x00, %dx                  # Compares the user input with 0
    jbe     more_than_23_error          # If input is 0 or below will call more_than_23_error label
    
    cmpw    $0x17, %dx                 # Compares the user input with 23 
    ja      more_than_23_error         # If input was larger than 23 will call the more_than_23_error label
    ret                                # If checks passed will return to the label that called user input

sector_amount_input_error:   
    movw    $1, %bx                         # adds the value of 1 into the bx register to indicate an error occured.
    call    cons_write_crlf                 # Call the cons_write_crlf to go to the next line
    movw    $boot_input_error_msg, %si      # Moves the si register to point at the boot_input_error_msg ready to display
    jmp     cons_writeline                  # Jump to the cons_writeline which will display what si is pointing and go to the next line

more_than_23_error:
    call    cons_write_crlf                         # Call the cons_write_crlf to go to the next line
    movw    $more_than_23_error_msg, %si            # Moves the si register to point at the boot_input_error_msg ready to display
    call    cons_write                              # Call cons_write to display the .string message above
    jmp     enter_amount_of_sector_to_read          # Go to the enter_sector label


read_sector_again_question:
    call    cons_write_crlf                     # Call the cons_write_crlf to go to the next line
    movw    $read_another_sector_msg, %si       # Moves si register to point at the read_another_sector_msg to display
    call    cons_write                          # Call cons_write to display the message above
    xor     %ax, %ax                            # Clears ax register 
    int     $0x16                               # Interrupt call to get keyboard input
    movb    $0x0E, %ah                          # Moves user input from $0x0E into the %ah register ready to display
    int     $0x10                               # Trigger interrupt 0x10 to display the number inputted

    cmpb    $121, %al                           # Compares al with the number value of 121 (ASCII represents y letter)
    je      enter_another_sector                # If equal will go into the enter_another_sector label

    cmpb    $89, %al                            # Compares value inside al with 89 (ASCII represents Y letter)
    je      enter_another_sector                # If equal will go into the enter_another_sector label

    cmpb    $78, %al                            # Compares value inside al with 78 (ASCII represents N letter)
    je      finish_program                      # If equal will go into the finish_program label

    cmpb    $110, %al                           # Compares al with the number value of 110 (ASCII represents n letter)
    je      finish_program                      # If equal will go into the finish_program label

read_sector_again_error:
    call    cons_write_crlf                     # Call the cons_write_crlf to go to the next line
    movw    $read_another_sector_error_msg, %si # Moves si register to point at the read_another_sector_msg to display
    call    cons_write                          # Call cons_write to display the message above
    call    read_sector_again_question          # calls read_sector_again_question to start the user input again

finish_program: 
    call    cons_write_crlf                     # Call the cons_write_crlf to go to the next line
    call    endless_loop                        # Calls endless_loop to end the program

enter_another_sector:   
    call    cons_write_crlf                     # Call the cons_write_crlf to go to the next line
    call    enter_sector                        # Calls enter_sector to start the program again

# End of input functionality code

real_start:
    movb    %dl, (boot_device) # Boot device number is passed in DL from BIOS. Save it hear since DL might get trashed

    movw    $boot_message, %si  # Display our boot message
    call    cons_writeline

    movw    $booted_from_msg, %si
    call    cons_write

    movb    (boot_device), %dl
    cmp     $0x80, %dl
    jge     harddrive

    movw    $fd, %si
    jmp     finish

harddrive:
    movw    $hd, %si

finish:
    call    cons_writeline
    call    enter_sector

endless_loop:                               # Loop forever more
    jmp     endless_loop    

# The following is the main body of the code it gets the user input for secto to read, amount to read displays all of the sectors
# hex, ascii, offset and then ends when the user asks
enter_sector:
    movw    $boot_enter_sector_msg, %si         # si register points to the enter sector message
    call    cons_write                          # called to display the message si is pointing to
    call    user_sector_input                   # Calls user_sector_input to record what sector user wanst to read

    cmpw    $0x270F, %dx                        # Compares the user input in dx with 9999 (0x270F)
    ja      more_than_4_digit_error             # If input was larger than 9999 it will call the more_than_4_digit_error label 
    
    cmpw    $1, %bx                             # Compares the 1 value with bx to see if there is a 1 in bx 
    jz      enter_sector                        # 0 flag is set meaning there was an error so we loop this label to start again
    movw    %dx, (user_entered_sector_to_read)  # Stores user input which is currently in dx to user_entered_sector_to_read label             

enter_amount_of_sector_to_read:
    call    cons_write_crlf                             # Call the cons_write_crlf to go to the next line
    movw    $enter_amount_of_sectors_to_read_msg, %si   # si register points to the enter sector message
    call    cons_write                                  # called to display the message si is pointing to
    call    user_sector_amount_input                    # Calls user_sector_amount_input to get user input of how much sectors they want to read

    cmpw    $1, %bx                                     # Compares the 1 value with bx to see if there is a 1 in bx 
    jz      enter_amount_of_sector_to_read              # 0 flag is set meaning there was an error so we loop this label to start again

    movw    %dx, (user_amount_of_sectors_to_display)    # Moves user input which is stored in dx to user_amount_of_sectors_to_display label
    movw    $0xD000, (memory_address)                   # Moves memory address of what we will read to memory_address label
    call    sector_reader                               # Calls sector_reader label


set_up_before_start_display:
    movw    $16, (lines_printed_counter)        # Counter to track how much lines have been printed
    movw    $0, (current_offset)                # Counter to keep track of which offset we are printing                                                                                           #print_line
    
start_display:   
    call    cons_write_crlf                             # Calls cons_write_crlf to move to a new line
    call    read_offset_from_memory                     # Calls read_offset_from_memory 
    addw    $16, (current_offset)                       # Add 16 to current_offset label
    decw     (lines_printed_counter)                    # decrement lines_printed_counter by 1
    cmpw     $0, (lines_printed_counter)                # compare line_printed_counter value with 0
    jnz     start_display                               # Jump if not equal to 0 to start_display
    
    decw     (user_amount_of_sectors_to_display)        # Decrement user_amount_of_sectors_to_display by 1
    cmpw     $0, (user_amount_of_sectors_to_display)    # Compare user_amount_of_sectors_to_display value with 0
    jz      read_sector_again_question                  # Jump if 0 to read_sector_again_question label
    
    call    cons_write_crlf                             # Calls for a new line
    movw    $press_a_key_to_continue_msg, %si           # Points si to the start of the string in press_a_key_to_continue to display
    call    cons_write                                  # Prints what si is pointing to the screen

    movb    $0, %ah                                     # Move 0 into ah
    int     $0x16                                       # Interrupt call waits for keyboard input
    movw    $16, (lines_printed_counter)                # Moves 16 into lins_printed_counter
    jmp     start_display                               # Jump to start_display label

read_offset_from_memory:   
    movw    (current_offset), %bx                # Moves value in current_offset into bx                                                                                                         #readfromsector
    movw    $4, %cx                              # Move 4 into cx to let the cons_write_hex know we want to print 4 characters of offset together
    call    cons_write_hex                       # Call the cons_write_hex to display the offset
    call    input_space                          # Call input_space to enter a space on the screen
    movw    $16, %dx                             # Move 16 into dx to be used as a counter to make sure only 16 bytes of hex are printed

read_hexadecimal_value_from_memory:                                                                                                                     #print_memory_line_in_hex
    movw    (memory_address), %bx                   # Load the current memory address into %bx 
    movb    (%bx), %al                              # Load the byte at the current memory address into al
    movb    %al, %bh                                # Copy the value from %al to %bh for printing
    movw    $2, %cx                                 # Set  %cx to 2 indicating the number of hexadecimal values to print at once
    call    cons_write_hex                          # Call cons_write_hex to print the hexadecimal values on the screen
    call    input_space                             # Call input_space to enter a space on the screen
    dec     %dx                                     # Decrement the counter %dx by 1
    incw     (memory_address)                       # Increment the memory address to point to the next byte
    cmp    $0, %dx                                  # Compare dx with 0 to check if more hex values need to be read
    jnz     read_hexadecimal_value_from_memory      # If not zero, jump to the label to read the next hexadecimal value until it is 0
    subw     $16, (memory_address)                  # Subtract 16 from the memory address so the ASCII values displayed will be the corresponding value of the hex displayedrea
    movw    $16, %dx                                # Move 16 into dx to be used as a counter to make sure only 16 charatcers of ASCII are printed

read_ascii_value_from_memory:
    movw    (memory_address), %bx               # Load the current memory address into %bx 
    movb    (%bx), %al                          # Load the byte at the current memory address into al
    call    write_ascii                         # Call write_ascii to print the ascii values to the screen 
    dec     %dx                                 # Decrement the counter %dx by 1
    incw     (memory_address)                   # Increment the memory address to point to the next byte
    cmp     $0, %dx                             # Compare dx with 0 to check if more hex values need to be read
    jnz     read_ascii_value_from_memory        # If not zero, jump to the label to read the next ascii value until it is 0
    ret


# The following section contains code to display the offset, hexadecimal value and ascii characters
HexChars:  .ascii "0123456789ABCDEF"    # Assign all the hexadecimal characters in a string to use.

cons_write_hex:
	push    %ax                         # Push ax
    push    %bx                         # Push bx
    movb    $0x0E, %ah                  # Use the int10 function to print output a single charcter
		
hexloop:
    cmp     $2, %cx                     # Compare value in cx with 2
    rol     $4, %bx                     # Rotate bx left by 4 bits
    movw    %bx, %si                    # Move what is in bx to si
    and     $0x000F, %si                # Do and to make sure we just have the bottom 4 bits
    movb    HexChars(%si), %al          # Use the input of si as an index into the hex characters table and put it in al
    int	    $0x10                       # Do in int10 to display the hex character
    loop	hexloop                     # Loop around untill cx = 0
    pop     %ax                         # Pop ax
    pop     %bx                         # Pop bx
    ret                                 # Once cx = 0 return to the original function where this one was called from.

input_space:
    push    %ax             # Pushes AX register to the stack.
    movb    $0x0e, %ah      # 0x0e is the INT 10h BIOS call to output the value contained in AL to screen
    movb    $32, %al        # Set al to 32 which is the ASCII code for the space character.
    int     $0x10           # Do in int10 to display the hex character
    pop     %ax             # Pops ax to get the original character back
    ret                     # Return 

write_ascii:
    push    %ax                     # Pushes AX register to the stack.
    movb    $0x0e, %ah              # 0x0e is the INT 10h BIOS call to output the value contained in AL to screen
    cmpb    $32, %al                # Compare if al is larger than 32
    jb      display_less_than_32    # If less than 32 go to the display_less_than_32 label
    jmp     write_to_display        # Jump to the write_to_display label
   
display_less_than_32:
    movb     $95, %al               # Moves 95 into al to be printed (95 ASCII code for underscore character)

write_to_display:                
    int     $0x10                   # Trigger interrupt 0x10 to display the character in AL
    pop     %ax                     # Pop the value from the stack into the AX register
    ret                                 

# This section contains all the code about which sector to read, how much of it to read.
sector_reader: 
    movw    (user_entered_sector_to_read), %bx          # Moves contents of user_entered_sector_to_read into bx
    movw    (user_amount_of_sectors_to_display), %cx    # Moves contents of user_amount_of_sectors_to_display into cx
    movw    $disk_address_packet, %si                   # Move address of the disk address packet into SI
    movw    %cx, 2(%si)                                 # Set the number of blocks to read to be 7
    movw    $0xD000, 4(%si)                             # Set the adddress to read into to be 0xD000
    movw    %bx, 8(%si)                                 # Set the first block to read to be block 1
    movb    $0x42, %ah                                  # 0x42 is the int 13h BIOS function to read the disk using LBA addressing
	movb	(boot_device), %dl                          # Retrieve the ID of our boot device and put in DL	
    int     $0x13                                       # Read the disk
    jc      read_failed	                                # The carry flag will be set if an error occured
    movb    (0xD000), %al                               # Move memory address into al
    imul    $2, %cx                                     # Multiply value inside cx by 2
    movw    %cx, (user_amount_of_sectors_to_display)    # move value of cx into user_amount_of_sectors_to_display
    ret                                                 # return
 
 read_failed:	                      
	movw 	$read_failed_msg, %si           # Moves si pointer to point at read_failed_msg
    call    cons_writeline                  # Calls cons_writeline to display message
	
	mov 	$cannot_continue_msg, %si	    # Moves si pointer to point at cannot_continue_msg
    call    cons_writeline                  # Calls cons_writeline to display message

disk_address_packet:
    .byte   0x10
    .byte   0
    .word   0
    .long   0
    .long   0
    .long   0

# Program data

boot_device:
    .byte   0
memory_address:
    .word   0
lines_printed_counter:
    .word   0
current_offset:
    .word   0
user_entered_sector_to_read:
    .word   0
user_amount_of_sectors_to_display:
    .word   0


boot_message:     
    .string "Boot Loader Stage 2 loaded"             
booted_from_msg:
    .string "Booting from "
fd: .string "floppy disk"
hd: .string "hard drive"
boot_enter_sector_msg:       
    .string "Enter the sector number to read: "
boot_input_error_msg: 
    .string "Please enter an digit that is either or between 0 and 9."
read_failed_msg:
    .string "Unable to read stage 2 of the boot process"
cannot_continue_msg:
    .string "Cannot continue boot process"
press_a_key_to_continue_msg:
    .string "Press a key to continue..."
more_than_4_digits_error_msg:
    .string "Only enter sectors between 0-9999 (4 digits maximum)"
enter_amount_of_sectors_to_read_msg:
    .string "Enter the amount of sectors to read: "
read_another_sector_msg:
    .string "Would you like to read another sector (Enter: (Y or N)): "
read_another_sector_error_msg:
    .string "Please enter either Y/y for yes or N/n for no."
more_than_23_error_msg:
    .string "You can read a minimum of 1-23 sectors at once (2 digits maximum)"
