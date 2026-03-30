################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Faiyad Ahmed Masnoon, 1011107062
#
# I assert that the code submitted here is entirely our own
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

# ASCII codes
KEY_A:  .word 0x61   # left
KEY_D:  .word 0x64   # right
KEY_W:  .word 0x77   # change order
KEY_S:  .word 0x73   # down
KEY_Q:  .word 0x71   # exit
KEY_1:  .word 0x31   # 1 -> default
KEY_2:  .word 0x32   # 2 -> med
KEY_3:  .word 0x33   # 3 -> insaneeeeeeee

# boundaries
FIELD_X_MIN: .word 11   # left wall
FIELD_X_MAX: .word 20   # right wall
FIELD_Y_MAX: .word 20   # base

# 60fps (sleep duration)
SLEEP_MS:    .word 16


#global clock 
TIMER: .word 0

# gravity time
FALL_DELAY:  .word 40
FALL_DELAY_MID: .word 25
FALL_DELAY_HARD: .word 10
# todo: remember to make it look pretty with proper spacing cuz why not xd


# frames since last gravity 
frame_counter: .word 0

# game colors
COL_BG:         .word 0x111111   # bg
COL_WALL:       .word 0x888888   # wall
COL_FIELD:      .word 0x222222   # empty spaces

# gems
gem_colors:
    .word 0xFF0000   # 0 red
    .word 0xFF8000   # 1 orange
    .word 0xFFFF00   # 2 yellow
    .word 0x00FF00   # 3 green
    .word 0x0000FF   # 4 blue
    .word 0xFF00FF   # 5 purple

##############################################################################
# Mutable Data
##############################################################################

# current column (falling)
col_x:      .word 15    # middle x
col_y:      .word 1     # top y
col_gem0:   .word 0     # first gem
col_gem1:   .word 0
col_gem2:   .word 0

# gem map
# -1 -> empty
board:
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    .word -1,-1,-1,-1,-1,-1,-1,-1,-1,-1

match_flags:
    .space 800

##############################################################################
# Code
##############################################################################
    .text
    .globl main

main:
    jal select_difficulty
    jal  pick_random_colors
    jal  draw_background
    jal  draw_field
    jal  draw_walls
    jal  draw_current_column

game_loop:
    jal  handle_keyboard
    lw   $t0, frame_counter
    addi $t0, $t0, 1
    lw   $t1, FALL_DELAY
    blt  $t0, $t1, gl_no_drop
    li   $t0, 0
    sw   $t0, frame_counter
    jal  auto_drop
    
    jal log_FD
    j    gl_sleep

gl_no_drop:
    sw   $t0, frame_counter

gl_sleep:
    li   $v0, 32
    lw   $a0, SLEEP_MS
    syscall
    lw $t0, TIMER
    addi $t0, $t0, 1
    sw $t0, TIMER
    li $t1, 1000
    beq $t0, $t1, auto_diff
    j game_loop



# 0xffff0000 -> 1 -> new key; 0xffff0004 -> ASCII

log_FD:
  lw   $a0, FALL_DELAY
  li   $v0, 1
  syscall
  
  li   $a0, 10
  li   $v0, 11
  syscall

  jr $ra


auto_diff:
  lw $t0, FALL_DELAY
  ble $t0, 1, auto_d_done
  addi $t0, $t0, -1
  sw $t0, FALL_DELAY
  sw $zero, TIMER
  
auto_d_done:
  jr $ra
  


handle_keyboard:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    bne  $t1, 1, hk_done # skip

    lw   $t2, 4($t0) # ASCII of new key

    lw   $t3, KEY_Q
    beq  $t2, $t3, key_quit

    lw   $t3, KEY_A
    beq  $t2, $t3, key_left

    lw   $t3, KEY_D
    beq  $t2, $t3, key_right

    lw   $t3, KEY_W
    beq  $t2, $t3, key_shuffle

    lw   $t3, KEY_S
    beq  $t2, $t3, key_drop

    j    hk_done                 

key_quit:
    li   $v0, 10 # exit
    syscall


key_left:
    lw   $t4, col_x
    lw   $t5, FIELD_X_MIN
    ble  $t4, $t5, hk_done

    addi $a0, $t4, -1
    jal  check_horizontal_collision
    bne  $v0, $zero, hk_done

    jal  erase_current_column
    lw   $t4, col_x
    addi $t4, $t4, -1
    sw   $t4, col_x
    jal  draw_current_column
    j    hk_done


key_right:
    lw   $t4, col_x
    lw   $t5, FIELD_X_MAX
    bge  $t4, $t5, hk_done

    addi $a0, $t4, 1
    jal  check_horizontal_collision
    bne  $v0, $zero, hk_done

    jal  erase_current_column
    lw   $t4, col_x
    addi $t4, $t4, 1
    sw   $t4, col_x
    jal  draw_current_column
    j    hk_done

# rotate downwards
key_shuffle:
    lw   $t4, col_gem0
    lw   $t5, col_gem1
    lw   $t6, col_gem2

   # move by 1 down
    sw   $t6, col_gem0
    sw   $t4, col_gem1
    sw   $t5, col_gem2

    jal  draw_current_column
    j    hk_done

key_drop:
    jal  check_landing
    bne  $v0, $zero, key_drop_landed


    jal  erase_current_column

    lw   $t4, col_y
    addi $t4, $t4, 1
    sw   $t4, col_y

    jal  draw_current_column
    j    hk_done

key_drop_landed:
    jal  lock_column
    jal  check_top_overflow
    jal  clear_matches
    jal  spawn_column
    j    hk_done

hk_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

# $v0 -> 1 : blocked
check_horizontal_collision:
    addi $sp, $sp, -8
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)

    move $s0, $a0

    #top
    move $a0, $s0
    lw   $a1, col_y
    jal  board_addr
    lw   $t0, 0($v0)
    li   $t1, -1
    bne  $t0, $t1, chc_blocked

    #mid
    move $a0, $s0
    lw   $a1, col_y
    addi $a1, $a1, 1
    jal  board_addr
    lw   $t0, 0($v0)
    li   $t1, -1
    bne  $t0, $t1, chc_blocked

    #last
    move $a0, $s0
    lw   $a1, col_y
    addi $a1, $a1, 2
    jal  board_addr
    lw   $t0, 0($v0)
    li   $t1, -1
    bne  $t0, $t1, chc_blocked

    li   $v0, 0
    j    chc_done

chc_blocked:
    li   $v0, 1

chc_done:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    addi $sp, $sp, 8
    jr   $ra


auto_drop:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    jal  check_landing
    bne  $v0, $zero, ad_landed

    jal  erase_current_column
    lw   $t0, col_y
    addi $t0, $t0, 1
    sw   $t0, col_y
    jal  draw_current_column
    j    ad_done

ad_landed:
    jal  lock_column
    jal  check_top_overflow
    jal  clear_matches
    jal  spawn_column

ad_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


erase_current_column:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw   $a0, col_x
    lw   $a1, col_y
    lw   $a2, COL_FIELD
    jal  draw_unit

    lw   $a0, col_x
    lw   $a1, col_y
    addi $a1, $a1, 1
    lw   $a2, COL_FIELD
    jal  draw_unit

    lw   $a0, col_x
    lw   $a1, col_y
    addi $a1, $a1, 2
    lw   $a2, COL_FIELD
    jal  draw_unit

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

# 42: random int between [0, $a1-1] -> returned to $a0 
pick_random_colors:
    li   $v0, 42
    li   $a0, 0
    li   $a1, 6
    syscall
    sw   $a0, col_gem0

    li   $v0, 42
    li   $a0, 0
    li   $a1, 6
    syscall
    sw   $a0, col_gem1

    li   $v0, 42
    li   $a0, 0
    li   $a1, 6
    syscall
    sw   $a0, col_gem2

    jr   $ra

draw_background:
    lw   $t0, ADDR_DSPL
    lw   $t1, COL_BG
    li   $t2, 0
    li   $t3, 1024

draw_bg_loop:
    beq  $t2, $t3, draw_bg_done
    sw   $t1, 0($t0)
    addi $t0, $t0, 4
    addi $t2, $t2, 1
    j    draw_bg_loop

draw_bg_done:
    jr   $ra



select_difficulty:
  add $sp, $sp, -4
  sw $ra, 0($sp)

  jal draw_background
  jal draw_difficulty_screen

diff_loop:
    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    bne  $t1, 1, diff_loop # keep waiting

    lw   $t2, 4($t0) # ASCII of new key

    lw   $t3, KEY_1
    beq  $t2, $t3, set_easy

    lw   $t3, KEY_2
    beq  $t2, $t3, set_medium

    lw   $t3, KEY_3
    beq  $t2, $t3, set_hard

    j    diff_loop

set_easy:
    j   diff_done


set_medium:
    lw  $t0, FALL_DELAY_MID
    sw  $t0, FALL_DELAY
    j   diff_done

set_hard:
    lw  $t0, FALL_DELAY_HARD
    sw  $t0, FALL_DELAY
    j   diff_done

diff_done:
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra


draw_difficulty_screen:
    addi $sp, $sp, -16
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)

    # green=easy, yellow=mid red = hard
    # green block x=13..17, y=2..6
    li   $s0, 2
dds_green_row:
    bgt  $s0, 6, dds_green_done
    li   $s1, 13
dds_green_col:
    bgt  $s1, 17, dds_green_next_row
    move $a0, $s1
    move $a1, $s0
    li   $a2, 0x00AA00
    jal  draw_unit
    addi $s1, $s1, 1
    j    dds_green_col
dds_green_next_row:
    addi $s0, $s0, 1
    j    dds_green_row
dds_green_done:
    li   $s0, 3
dds_I_loop:
    bgt  $s0, 5, dds_I_done
    li   $a0, 15
    move $a1, $s0
    li   $a2, 0x00FF00
    jal  draw_unit
    addi $s0, $s0, 1
    j    dds_I_loop
dds_I_done:

    # yellow block x=13 to 17, y=9 to 13
    li   $s0, 9
dds_yellow_row:
    bgt  $s0, 13, dds_yellow_done
    li   $s1, 13
dds_yellow_col:
    bgt  $s1, 17, dds_yellow_next_row
    move $a0, $s1
    move $a1, $s0
    li   $a2, 0xAAAA00
    jal  draw_unit
    addi $s1, $s1, 1
    j    dds_yellow_col
dds_yellow_next_row:
    addi $s0, $s0, 1
    j    dds_yellow_row
dds_yellow_done:
    li   $s0, 10
dds_II_loop:
    bgt  $s0, 12, dds_II_done
    li   $a0, 14
    move $a1, $s0
    li   $a2, 0xFFFF00
    jal  draw_unit
    li   $a0, 16
    move $a1, $s0
    li   $a2, 0xFFFF00
    jal  draw_unit
    addi $s0, $s0, 1
    j    dds_II_loop
dds_II_done:

    # red block x=13 to 17, y=16 to 20
    li   $s0, 16
dds_red_row:
    bgt  $s0, 20, dds_red_done
    li   $s1, 13
dds_red_col:
    bgt  $s1, 17, dds_red_next_row
    move $a0, $s1
    move $a1, $s0
    li   $a2, 0xAA0000
    jal  draw_unit
    addi $s1, $s1, 1
    j    dds_red_col
dds_red_next_row:
    addi $s0, $s0, 1
    j    dds_red_row
dds_red_done:
    li   $s0, 17
dds_III_loop:
    bgt  $s0, 19, dds_III_done
    li   $a0, 13
    move $a1, $s0
    li   $a2, 0xFF0000
    jal  draw_unit
    li   $a0, 15
    move $a1, $s0
    li   $a2, 0xFF0000
    jal  draw_unit
    li   $a0, 17
    move $a1, $s0
    li   $a2, 0xFF0000
    jal  draw_unit
    addi $s0, $s0, 1
    j    dds_III_loop
dds_III_done:

    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    addi $sp, $sp, 16
    jr   $ra
  

# x=[11, 20], y=[1, 20] 
draw_field:
    addi $sp, $sp, -16
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)

    lw   $t4, COL_FIELD
    li   $s0, 1

draw_field_row:
    bgt  $s0, 20, draw_field_done
    li   $s1, 11

draw_field_col:
    bgt  $s1, 20, draw_field_next_row
    move $a0, $s1
    move $a1, $s0
    move $a2, $t4
    jal  draw_unit
    addi $s1, $s1, 1
    j    draw_field_col

draw_field_next_row:
    addi $s0, $s0, 1
    j    draw_field_row

draw_field_done:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    addi $sp, $sp, 16
    jr   $ra


draw_walls:
    addi $sp, $sp, -8
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)

    lw   $t4, COL_WALL

    li   $s0, 1
draw_left_wall:
    bgt  $s0, 21, draw_right_wall_start
    li   $a0, 10
    move $a1, $s0
    move $a2, $t4
    jal  draw_unit
    addi $s0, $s0, 1
    j    draw_left_wall

draw_right_wall_start:
    li   $s0, 1
draw_right_wall:
    bgt  $s0, 21, draw_floor_start
    li   $a0, 21
    move $a1, $s0
    move $a2, $t4
    jal  draw_unit
    addi $s0, $s0, 1
    j    draw_right_wall

draw_floor_start:
    li   $s0, 10
draw_floor:
    bgt  $s0, 21, draw_walls_done
    move $a0, $s0
    li   $a1, 21
    move $a2, $t4
    jal  draw_unit
    addi $s0, $s0, 1
    j    draw_floor

draw_walls_done:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    addi $sp, $sp, 8
    jr   $ra


draw_current_column:
    addi $sp, $sp, -16
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)

    lw   $s0, col_x
    lw   $s1, col_y

    lw   $t2, col_gem0
    jal  get_gem_color
    move $a0, $s0
    move $a1, $s1
    move $a2, $v0
    jal  draw_unit

    lw   $t2, col_gem1
    jal  get_gem_color
    move $a0, $s0
    addi $a1, $s1, 1
    move $a2, $v0
    jal  draw_unit

    lw   $t2, col_gem2
    jal  get_gem_color
    move $a0, $s0
    addi $a1, $s1, 2
    move $a2, $v0
    jal  draw_unit

    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    addi $sp, $sp, 16
    jr   $ra


get_gem_color:
    la   $t3, gem_colors
    sll  $t4, $t2, 2
    add  $t3, $t3, $t4
    lw   $v0, 0($t3)
    jr   $ra

draw_unit:
    lw   $t0, ADDR_DSPL
    sll  $t1, $a1, 7 # y * 128
    sll  $t2, $a0, 2 # x * 4
    add  $t1, $t1, $t2
    add  $t0, $t0, $t1
    sw   $a2, 0($t0)
    jr   $ra


lock_column:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)


    lw   $a0, col_x
    lw   $a1, col_y
    jal  board_addr
    lw   $t0, col_gem0
    sw   $t0, 0($v0)

    lw   $a0, col_x
    lw   $a1, col_y
    addi $a1, $a1, 1
    jal  board_addr
    lw   $t0, col_gem1
    sw   $t0, 0($v0)

    lw   $a0, col_x
    lw   $a1, col_y
    addi $a1, $a1, 2
    jal  board_addr
    lw   $t0, col_gem2
    sw   $t0, 0($v0)

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


spawn_column:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # check if game over? 
    li   $a0, 15
    li   $a1, 1
    jal  board_addr
    lw   $t0, 0($v0)
    li   $t1, -1
    bne  $t0, $t1, game_over

    # check if enough space to spawn
    li   $a0, 15
    li   $a1, 2
    jal  board_addr
    lw   $t0, 0($v0)
    li   $t1, -1 
    bne  $t0, $t1, game_over

    li   $a0, 15
    li   $a1, 3
    jal  board_addr
    lw   $t0, 0($v0)
    li   $t1, -1
    bne  $t0, $t1, game_over

    li   $t0, 15
    sw   $t0, col_x
    li   $t0, 1
    sw   $t0, col_y

    jal  pick_random_colors
    jal  draw_current_column

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

game_over:
    # U LOSE !!! RED
    addi $sp, $sp, -8
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)

    li   $s0, 1
go_row:
    bgt  $s0, 20, go_exit
    li   $a0, 11
go_col:
    bgt  $a0, 20, go_next_row
    move $a1, $s0
    li   $a2, 0xFF0000
    jal  draw_unit
    addi $a0, $a0, 1
    j    go_col
go_next_row:
    addi $s0, $s0, 1
    j    go_row

go_exit:
    # sleep to show the red
    li   $v0, 32
    li   $a0, 800
    syscall

    li   $v0, 10
    syscall

# if mathced, match_flags[x,y] = 1.

set_match_flag:
    addi $t0, $a1, -1
    li   $t1, 10
    mul  $t0, $t0, $t1      # (y-1)*10
    addi $t1, $a0, -11      # x-11
    add  $t0, $t0, $t1      # (y-1)*10 + (x-11)
    sll  $t0, $t0, 2
    la   $t1, match_flags
    add  $t1, $t1, $t0
    li   $t2, 1
    sw   $t2, 0($t1)
    jr   $ra


find_matches:
    addi $sp, $sp, -28
    sw   $ra,  0($sp)
    sw   $s0,  4($sp)
    sw   $s1,  8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)
    sw   $s4, 20($sp)
    sw   $s5, 24($sp)

    li   $s3, 0

    li   $s0, 1 # y = 1
fm_row:
    bgt  $s0, 20, fm_done
    li   $s1, 11 # x = 11
fm_col:
    bgt  $s1, 20, fm_next_row

    # s2 -> color of (x, y)
    move $a0, $s1
    move $a1, $s0
    jal  board_addr
    lw   $s2, 0($v0)
    li   $t0, -1
    beq  $s2, $t0, fm_next_col   # skip empty cell

    # (x,y+1) and (x,y+2)
    addi $t0, $s0, 2
    bgt  $t0, 20, fm_skip_vert

    move $a0, $s1
    addi $a1, $s0, 1
    jal  board_addr
    lw   $s4, 0($v0) # board[x, y+1]

    move $a0, $s1
    addi $a1, $s0, 2
    jal  board_addr
    lw   $s5, 0($v0) # board[x, y+2]

    bne  $s4, $s2, fm_skip_vert
    bne  $s5, $s2, fm_skip_vert
    move $a0, $s1
    move $a1, $s0
    jal  set_match_flag
    move $a0, $s1
    addi $a1, $s0, 1
    jal  set_match_flag
    move $a0, $s1
    addi $a1, $s0, 2
    jal  set_match_flag
    li   $s3, 1

fm_skip_vert:
    # (x+1,y) and (x+2,y)
    addi $t0, $s1, 2
    bgt  $t0, 20, fm_skip_horiz

    addi $a0, $s1, 1
    move $a1, $s0
    jal  board_addr
    lw   $s4, 0($v0) # board[x+1, y]

    addi $a0, $s1, 2
    move $a1, $s0
    jal  board_addr
    lw   $s5, 0($v0) # board[x+2, y]

    bne  $s4, $s2, fm_skip_horiz
    bne  $s5, $s2, fm_skip_horiz
    move $a0, $s1
    move $a1, $s0
    jal  set_match_flag
    addi $a0, $s1, 1
    move $a1, $s0
    jal  set_match_flag
    addi $a0, $s1, 2
    move $a1, $s0
    jal  set_match_flag
    li   $s3, 1

fm_skip_horiz:
    # dr: (x+1,y+1) and (x+2,y+2)
    addi $t0, $s1, 2
    bgt  $t0, 20, fm_skip_diagr
    addi $t0, $s0, 2
    bgt  $t0, 20, fm_skip_diagr

    addi $a0, $s1, 1
    addi $a1, $s0, 1
    jal  board_addr
    lw   $s4, 0($v0)

    addi $a0, $s1, 2
    addi $a1, $s0, 2
    jal  board_addr
    lw   $s5, 0($v0)

    bne  $s4, $s2, fm_skip_diagr
    bne  $s5, $s2, fm_skip_diagr
    move $a0, $s1
    move $a1, $s0
    jal  set_match_flag
    addi $a0, $s1, 1
    addi $a1, $s0, 1
    jal  set_match_flag
    addi $a0, $s1, 2
    addi $a1, $s0, 2
    jal  set_match_flag
    li   $s3, 1

fm_skip_diagr:
    # dl: (x-1,y+1) and (x-2,y+2)
    addi $t0, $s1, -2
    blt  $t0, 11, fm_skip_diagl
    addi $t0, $s0, 2
    bgt  $t0, 20, fm_skip_diagl

    addi $a0, $s1, -1
    addi $a1, $s0, 1
    jal  board_addr
    lw   $s4, 0($v0)

    addi $a0, $s1, -2
    addi $a1, $s0, 2
    jal  board_addr
    lw   $s5, 0($v0)

    bne  $s4, $s2, fm_skip_diagl
    bne  $s5, $s2, fm_skip_diagl
    move $a0, $s1
    move $a1, $s0
    jal  set_match_flag
    addi $a0, $s1, -1
    addi $a1, $s0, 1
    jal  set_match_flag
    addi $a0, $s1, -2
    addi $a1, $s0, 2
    jal  set_match_flag
    li   $s3, 1

fm_skip_diagl:
fm_next_col:
    addi $s1, $s1, 1
    j    fm_col

fm_next_row:
    addi $s0, $s0, 1
    j    fm_row

fm_done:
    move $v0, $s3

    lw   $ra,  0($sp)
    lw   $s0,  4($sp)
    lw   $s1,  8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    lw   $s5, 24($sp)
    addi $sp, $sp, 28
    jr   $ra


# applies flag -1 to all marked matches
apply_matches:
    addi $sp, $sp, -12
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)

    li   $s0, 1             # y
am_row:
    bgt  $s0, 20, am_done
    li   $s1, 11            # x
am_col:
    bgt  $s1, 20, am_next_row

    addi $t0, $s0, -1
    li   $t1, 10
    mul  $t0, $t0, $t1
    addi $t1, $s1, -11
    add  $t0, $t0, $t1
    sll  $t0, $t0, 2
    la   $t1, match_flags
    add  $t1, $t1, $t0
    lw   $t2, 0($t1)
    beq  $t2, $zero, am_next_col


    move $a0, $s1
    move $a1, $s0
    jal  board_addr
    li   $t0, -1
    sw   $t0, 0($v0)


    move $a0, $s1
    move $a1, $s0
    lw   $a2, COL_FIELD
    jal  draw_unit

am_next_col:
    addi $s1, $s1, 1
    j    am_col

am_next_row:
    addi $s0, $s0, 1
    j    am_row

am_done:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    addi $sp, $sp, 12
    jr   $ra


# goes column by column
apply_gravity:
    addi $sp, $sp, -20
    sw   $ra,  0($sp)
    sw   $s0,  4($sp)
    sw   $s1,  8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)

    li   $s0, 11

ag_col_loop:
    bgt  $s0, 20, ag_done

    li   $s2, 20
    li   $s1, 20

ag_scan:
    blt  $s1, 1, ag_fill_empty

    move $a0, $s0
    move $a1, $s1
    jal  board_addr
    lw   $s3, 0($v0)
    li   $t0, -1
    beq  $s3, $t0, ag_scan_next

    
    move $a0, $s0
    move $a1, $s2
    jal  board_addr
    sw   $s3, 0($v0)

    
    beq  $s2, $s1, ag_no_clear
    move $a0, $s0
    move $a1, $s1
    jal  board_addr
    li   $t0, -1
    sw   $t0, 0($v0)
ag_no_clear:

    addi $s2, $s2, -1

ag_scan_next:
    addi $s1, $s1, -1
    j    ag_scan

ag_fill_empty:
    li   $s1, 1
ag_fill:
    bgt  $s1, $s2, ag_redraw_col
    move $a0, $s0
    move $a1, $s1
    jal  board_addr
    li   $t0, -1
    sw   $t0, 0($v0)
    addi $s1, $s1, 1
    j    ag_fill

ag_redraw_col:
    li   $s1, 1
ag_redraw:
    bgt  $s1, 20, ag_next_col

    move $a0, $s0
    move $a1, $s1
    jal  board_addr
    lw   $t0, 0($v0)

    li   $t1, -1
    bne  $t0, $t1, ag_draw_gem

    move $a0, $s0
    move $a1, $s1
    lw   $a2, COL_FIELD
    jal  draw_unit
    j    ag_redraw_next

ag_draw_gem:
    move $t2, $t0      
    jal  get_gem_color
    move $a0, $s0
    move $a1, $s1
    move $a2, $v0
    jal  draw_unit

ag_redraw_next:
    addi $s1, $s1, 1
    j    ag_redraw

ag_next_col:
    addi $s0, $s0, 1
    j    ag_col_loop

ag_done:
    lw   $ra,  0($sp)
    lw   $s0,  4($sp)
    lw   $s1,  8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    addi $sp, $sp, 20
    jr   $ra


clear_matches:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

cm_loop:
    la   $t0, match_flags
    li   $t1, 0
    li   $t2, 200
cm_zero:
    beq  $t2, $zero, cm_zero_done
    sw   $t1, 0($t0)
    addi $t0, $t0, 4
    addi $t2, $t2, -1
    j    cm_zero
cm_zero_done:

    jal  find_matches
    beq  $v0, $zero, cm_done

    jal  apply_matches
    jal  apply_gravity
    j    cm_loop

cm_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra



check_top_overflow:
    addi $sp, $sp, -8
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)

    li   $s0, 11
cto_loop:
    bgt  $s0, 20, cto_clear
    move $a0, $s0
    li   $a1, 1
    jal  board_addr
    lw   $t0, 0($v0)
    li   $t1, -1
    bne  $t0, $t1, cto_overflow

    addi $s0, $s0, 1
    j    cto_loop

cto_overflow:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    addi $sp, $sp, 8
    j    game_over

cto_clear:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    addi $sp, $sp, 8
    jr   $ra


# (col_y + 2) >= FIELD_Y_MAX -> floor
# (col_x, col_y + 3) != -1 -> gem below
check_landing:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # with floor
    lw   $t0, col_y
    addi $t0, $t0, 2
    lw   $t1, FIELD_Y_MAX
    bge  $t0, $t1, cl_landed

    # gem below
    lw   $a0, col_x
    lw   $a1, col_y
    addi $a1, $a1, 3
    jal  board_addr
    lw   $t0, 0($v0)
    li   $t1, -1
    bne  $t0, $t1, cl_landed

    li   $v0, 0
    j    cl_done

cl_landed:
    li   $v0, 1

cl_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra



# returns the adress of cell (x, y)
# board + ((y-1)*10 + (x-11)) * 4
board_addr:
    addi $t0, $a1, -1
    li   $t1, 10
    mul  $t0, $t0, $t1
    addi $t1, $a0, -11
    add  $t0, $t0, $t1
    sll  $t0, $t0, 2
    la   $v0, board
    add  $v0, $v0, $t0
    jr   $ra