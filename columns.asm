################# CSC258 Assembly Final Project ##############################
# This file contains our implementation of Columns.
#
# Student 1: Faiyad Ahmed Masnoon, 1011107062
#
# I assert that the code submitted here is entirely our own
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
##############################################################################
# layout
# x=0 to 14: left sidebar for displaying scores
# x=15: left wall
# x=16 to 25: game area
# x=26: right wall
# x=27 to 31: right sidebar

  .data
##############################################################################
# Immutable Data
##############################################################################
ADDR_DSPL:
  .word 0x10008000
ADDR_KBRD:
  .word 0xffff0000

# ASCII codes
KEY_A: .word 0x61 # left
KEY_D: .word 0x64 # right
KEY_W: .word 0x77 # change order
KEY_S: .word 0x73 # down
KEY_Q: .word 0x71 # exit
KEY_P: .word 0x70 # pause
KEY_R: .word 0x72 # retry
KEY_1: .word 0x31 # easy
KEY_2: .word 0x32 # mid
KEY_3: .word 0x33 # hard

# game area limits
FIELD_X_MIN: .word 16
FIELD_X_MAX: .word 25
FIELD_Y_MAX: .word 20

# 60fps
SLEEP_MS: .word 16

# global clock
TIMER: .word 0

# gravity delay (frames between auto drops)
FALL_DELAY: .word 40
FALL_DELAY_MID: .word 25
FALL_DELAY_HARD: .word 10

# score stuff
SCORE: .word 0
SCORE_MP: .word 1
SCORE_MP_MID: .word 2
SCORE_MP_HRD: .word 3

# chain multiplier 
CHAIN: .word 1

# frames since last drop
frame_counter: .word 0

# colors
COL_BG: .word 0x111111
COL_WALL: .word 0x888888
COL_FIELD: .word 0x222222
COL_SCORE: .word 0xFFFFFF
COL_SCORE_BG: .word 0x111111

# gem color table, indexed 0-5
gem_colors:
  .word 0xFF0000 # 0 red
  .word 0xFF8000 # 1 orange
  .word 0xFFFF00 # 2 yellow
  .word 0x00FF00 # 3 green
  .word 0x0000FF # 4 blue
  .word 0xFF00FF # 5 purple

# 7 segment digit bitmaps (3x5)
digit_bitmaps:
  .word 0b111101101101111 # 0
  .word 0b010010010010010 # 1
  .word 0b111001111100111 # 2
  .word 0b111001111001111 # 3
  .word 0b101101111001001 # 4
  .word 0b111100111001111 # 5
  .word 0b111100111101111 # 6
  .word 0b111001001001001 # 7
  .word 0b111101111101111 # 8
  .word 0b111101111001111 # 9

##############################################################################
# Mutable Data
##############################################################################

# current falling column (spawn x=20, center of shifted field)
col_x: .word 20
col_y: .word 1
col_gem0: .word 0
col_gem1: .word 0
col_gem2: .word 0

# board: -1 = empty, 0-5 = gem color index
# 20r, 10c
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
  jal pick_random_colors
  jal draw_background
  jal draw_field
  jal draw_walls
  jal draw_score
  jal draw_current_column

game_loop:
  jal handle_keyboard
  lw $t0, frame_counter
  addi $t0, $t0, 1
  lw $t1, FALL_DELAY
  blt $t0, $t1, gl_no_drop
  li $t0, 0
  sw $t0, frame_counter
  jal auto_drop
  # logger
  jal log_FD
  # jal log_SCORE
  
  j gl_sleep

gl_no_drop:
  sw $t0, frame_counter

gl_sleep:
  li $v0, 32
  lw $a0, SLEEP_MS
  syscall

  # increase difficulty every 10s?
  lw $t0, TIMER
  addi $t0, $t0, 1
  sw $t0, TIMER
  li $t1, 600
  beq $t0, $t1, auto_diff
  j game_loop


# increase difficulty by speeding up the game every 10s
# easy feature
auto_diff:
  lw $t0, FALL_DELAY
  ble $t0, 1, auto_d_done
  addi $t0, $t0, -1
  sw $t0, FALL_DELAY
  sw $zero, TIMER
auto_d_done:
  jr $ra

# log FALL_DELAY to show that auto_diff actually works
log_FD:
  lw   $a0, FALL_DELAY
  li   $v0, 1
  syscall
  
  li   $a0, 10
  li   $v0, 11
  syscall

  jr $ra
# log score for testing (TODO: remove later)
log_SCORE:
  lw   $a0, SCORE
  li   $v0, 1
  syscall
  
  li   $a0, 10
  li   $v0, 11
  syscall

  jr $ra

# handles keyboard input
# if $t1 != 1, it means no new input
handle_keyboard:
  addi $sp, $sp, -8
  sw $ra, 0($sp)
  sw $s0, 4($sp)

  lw $t0, ADDR_KBRD
  lw $t1, 0($t0)
  bne $t1, 1, hk_done

  lw $t2, 4($t0)

  lw $t3, KEY_Q
  beq $t2, $t3, key_quit
  lw $t3, KEY_A
  beq $t2, $t3, key_left
  lw $t3, KEY_D
  beq $t2, $t3, key_right
  lw $t3, KEY_W
  beq $t2, $t3, key_shuffle
  lw $t3, KEY_S
  beq $t2, $t3, key_drop
  lw $t3, KEY_P
  beq $t2, $t3, key_pause
  j hk_done

# 10 -> stops the program
key_quit:
  li $v0, 10
  syscall


# when p is pressed, pause the game
# easy feature
key_pause:
  li $s0, 1
pause_draw_loop:
  # draws the pause symbol
  bgt $s0, 3, pause_loop_start
  li $a0, 23
  move $a1, $s0
  li $a2, 0xFFFFFF
  jal draw_unit
  li $a0, 25
  move $a1, $s0
  li $a2, 0xFFFFFF
  jal draw_unit
  addi $s0, $s0, 1
  j pause_draw_loop

pause_loop_start:
  li $v0, 32
  li $a0, 100
  syscall
  lw $t0, ADDR_KBRD
  lw $t1, 0($t0)
  bne $t1, 1, pause_loop_start
  lw $t2, 4($t0)
  lw $t3, KEY_P
  bne $t2, $t3, pause_loop_start

  # erase symbol and resume
  li $s0, 1
pause_erase_loop:
  bgt $s0, 3, pause_done
  li $a0, 23
  move $a1, $s0
  lw $a2, COL_FIELD
  jal draw_unit
  li $a0, 25
  move $a1, $s0
  lw $a2, COL_FIELD
  jal draw_unit
  addi $s0, $s0, 1
  j pause_erase_loop

pause_done:
  j hk_done


# moves column to the left, as long as it is a legal move
key_left:
  lw $t4, col_x
  lw $t5, FIELD_X_MIN
  ble $t4, $t5, hk_done

  addi $a0, $t4, -1
  jal check_horizontal_collision
  bne $v0, $zero, hk_done

  jal find_ghost_column
  move $a1, $v0
  jal erase_ghost
  jal erase_current_column
  lw $t4, col_x
  addi $t4, $t4, -1
  sw $t4, col_x
  jal find_ghost_column
  move $a1, $v0
  jal draw_ghost
  jal draw_current_column
  j hk_done


# moves column to the right, as long as legal move
key_right:
  lw $t4, col_x
  lw $t5, FIELD_X_MAX
  bge $t4, $t5, hk_done

  addi $a0, $t4, 1
  jal check_horizontal_collision
  bne $v0, $zero, hk_done

  jal find_ghost_column
  move $a1, $v0
  jal erase_ghost
  jal erase_current_column
  lw $t4, col_x
  addi $t4, $t4, 1
  sw $t4, col_x
  jal find_ghost_column
  move $a1, $v0
  jal draw_ghost
  jal draw_current_column
  j hk_done


# moves gem downwards
key_shuffle:
  lw $t4, col_gem0
  lw $t5, col_gem1
  lw $t6, col_gem2
  sw $t6, col_gem0
  sw $t4, col_gem1
  sw $t5, col_gem2
  jal find_ghost_column
  move $a1, $v0
  jal draw_ghost
  jal draw_current_column
  j hk_done


# moves column down by 1, as long as it is legal
key_drop:
  jal check_landing
  bne $v0, $zero, key_drop_landed
  jal find_ghost_column
  move $a1, $v0
  jal erase_ghost
  jal erase_current_column
  lw $t4, col_y
  addi $t4, $t4, 1
  sw $t4, col_y
  jal find_ghost_column
  move $a1, $v0
  jal draw_ghost
  jal draw_current_column
  j hk_done

# when the column lands
key_drop_landed:
  jal lock_column
  jal check_top_overflow
  jal clear_matches
  jal spawn_column
  j hk_done


hk_done:
  lw $ra, 0($sp)
  lw $s0, 4($sp)
  addi $sp, $sp, 8
  jr $ra


# $a0 = target x, $v0 = 1 if blocked
check_horizontal_collision:
  addi $sp, $sp, -8
  sw $ra, 0($sp)
  sw $s0, 4($sp)

  move $s0, $a0

  move $a0, $s0
  lw $a1, col_y
  jal board_addr
  lw $t0, 0($v0)
  li $t1, -1
  bne $t0, $t1, chc_blocked

  move $a0, $s0
  lw $a1, col_y
  addi $a1, $a1, 1
  jal board_addr
  lw $t0, 0($v0)
  li $t1, -1
  bne $t0, $t1, chc_blocked

  move $a0, $s0
  lw $a1, col_y
  addi $a1, $a1, 2
  jal board_addr
  lw $t0, 0($v0)
  li $t1, -1
  bne $t0, $t1, chc_blocked

  li $v0, 0
  j chc_done

chc_blocked:
  li $v0, 1

chc_done:
  lw $ra, 0($sp)
  lw $s0, 4($sp)
  addi $sp, $sp, 8
  jr $ra

# for gravity
# easy feature
auto_drop:
  addi $sp, $sp, -4
  sw $ra, 0($sp)

  jal check_landing
  bne $v0, $zero, ad_landed
  jal find_ghost_column
  move $a1, $v0
  jal erase_ghost
  jal erase_current_column
  lw $t0, col_y
  addi $t0, $t0, 1
  sw $t0, col_y
  jal find_ghost_column
  move $a1, $v0
  jal draw_ghost
  jal draw_current_column
  j ad_done

ad_landed:
  jal lock_column
  jal check_top_overflow
  jal clear_matches
  jal spawn_column

ad_done:
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra


# erases current column cuz it moved
erase_current_column:
  addi $sp, $sp, -4
  sw $ra, 0($sp)

  lw $a0, col_x
  lw $a1, col_y
  lw $a2, COL_FIELD
  jal draw_unit

  lw $a0, col_x
  lw $a1, col_y
  addi $a1, $a1, 1
  lw $a2, COL_FIELD
  jal draw_unit

  lw $a0, col_x
  lw $a1, col_y
  addi $a1, $a1, 2
  lw $a2, COL_FIELD
  jal draw_unit

  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra


pick_random_colors:
  li $v0, 42
  li $a0, 0
  li $a1, 6
  syscall
  sw $a0, col_gem0

  li $v0, 42
  li $a0, 0
  li $a1, 6
  syscall
  sw $a0, col_gem1

  li $v0, 42
  li $a0, 0
  li $a1, 6
  syscall
  sw $a0, col_gem2

  jr $ra


draw_background:
  lw $t0, ADDR_DSPL
  lw $t1, COL_BG
  li $t2, 0
  li $t3, 1024
draw_bg_loop:
  beq $t2, $t3, draw_bg_done
  sw $t1, 0($t0)
  addi $t0, $t0, 4
  addi $t2, $t2, 1
  j draw_bg_loop
draw_bg_done:
  jr $ra

# 1: easy; 2: mid; 3: hard (actually impossible after a while xd)
# easy feature
select_difficulty:
  addi $sp, $sp, -4
  sw $ra, 0($sp)

  jal draw_background
  jal draw_difficulty_screen


# keeps on polling till it recieves 1, 2 or 3
diff_loop:
  lw $t0, ADDR_KBRD
  lw $t1, 0($t0)
  bne $t1, 1, diff_loop

  lw $t2, 4($t0)

  lw $t3, KEY_1
  beq $t2, $t3, set_easy
  lw $t3, KEY_2
  beq $t2, $t3, set_medium
  lw $t3, KEY_3
  beq $t2, $t3, set_hard
  j diff_loop

# FALL_DELAY by default is the easy diff
set_easy:
  j diff_done

set_medium:
  lw $t0, FALL_DELAY_MID
  sw $t0, FALL_DELAY
  lw $t0, SCORE_MP_MID
  sw $t0, SCORE_MP
  j diff_done

set_hard:
  lw $t0, FALL_DELAY_HARD
  sw $t0, FALL_DELAY
  lw $t0, SCORE_MP_HRD
  sw $t0, SCORE_MP
  j diff_done

diff_done:
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra



# green for easy, yellow for mid, red for hard
draw_difficulty_screen:
  addi $sp, $sp, -16
  sw $ra, 0($sp)
  sw $s0, 4($sp)
  sw $s1, 8($sp)
  sw $s2, 12($sp)
  
  li $s0, 3
dds_green_row:
  bgt $s0, 7, dds_green_done
  li $s1, 18
dds_green_col:
  bgt $s1, 22, dds_green_next_row
  move $a0, $s1
  move $a1, $s0
  li $a2, 0x00AA00
  jal draw_unit
  addi $s1, $s1, 1
  j dds_green_col
dds_green_next_row:
  addi $s0, $s0, 1
  j dds_green_row
dds_green_done:
  li $s0, 4

# I inside green box
dds_I_loop:
  bgt $s0, 6, dds_I_done
  li $a0, 20
  move $a1, $s0
  li $a2, 0x00FF00
  jal draw_unit
  addi $s0, $s0, 1
  j dds_I_loop
dds_I_done:
  li $s0, 10
dds_yellow_row:
  bgt $s0, 14, dds_yellow_done
  li $s1, 18
dds_yellow_col:
  bgt $s1, 22, dds_yellow_next_row
  move $a0, $s1
  move $a1, $s0
  li $a2, 0xAAAA00
  jal draw_unit
  addi $s1, $s1, 1
  j dds_yellow_col
dds_yellow_next_row:
  addi $s0, $s0, 1
  j dds_yellow_row
dds_yellow_done:
  li $s0, 11
# II inside yellow box
dds_II_loop:
  bgt $s0, 13, dds_II_done
  li $a0, 19
  move $a1, $s0
  li $a2, 0xFFFF00
  jal draw_unit
  li $a0, 21
  move $a1, $s0
  li $a2, 0xFFFF00
  jal draw_unit
  addi $s0, $s0, 1
  j dds_II_loop
dds_II_done:
  li $s0, 16
dds_red_row:
  bgt $s0, 20, dds_red_done
  li $s1, 18
dds_red_col:
  bgt $s1, 22, dds_red_next_row
  move $a0, $s1
  move $a1, $s0
  li $a2, 0xAA0000
  jal draw_unit
  addi $s1, $s1, 1
  j dds_red_col
dds_red_next_row:
  addi $s0, $s0, 1
  j dds_red_row
dds_red_done:
  li $s0, 17
# III inside red
dds_III_loop:
  bgt $s0, 19, dds_III_done
  li $a0, 18
  move $a1, $s0
  li $a2, 0xFF0000
  jal draw_unit
  li $a0, 20
  move $a1, $s0
  li $a2, 0xFF0000
  jal draw_unit
  li $a0, 22
  move $a1, $s0
  li $a2, 0xFF0000
  jal draw_unit
  addi $s0, $s0, 1
  j dds_III_loop
dds_III_done:

  lw $ra, 0($sp)
  lw $s0, 4($sp)
  lw $s1, 8($sp)
  lw $s2, 12($sp)
  addi $sp, $sp, 16
  jr $ra


draw_field:
  addi $sp, $sp, -16
  sw $ra, 0($sp)
  sw $s0, 4($sp)
  sw $s1, 8($sp)

  lw $t4, COL_FIELD
  li $s0, 1
draw_field_row:
  bgt $s0, 20, draw_field_done
  li $s1, 16
draw_field_col:
  bgt $s1, 25, draw_field_next_row
  move $a0, $s1
  move $a1, $s0
  move $a2, $t4
  jal draw_unit
  addi $s1, $s1, 1
  j draw_field_col
draw_field_next_row:
  addi $s0, $s0, 1
  j draw_field_row
draw_field_done:
  lw $ra, 0($sp)
  lw $s0, 4($sp)
  lw $s1, 8($sp)
  addi $sp, $sp, 16
  jr $ra


draw_walls:
  addi $sp, $sp, -8
  sw $ra, 0($sp)
  sw $s0, 4($sp)

  lw $t4, COL_WALL

  li $s0, 1
draw_left_wall:
  bgt $s0, 21, draw_right_wall_start
  li $a0, 15
  move $a1, $s0
  move $a2, $t4
  jal draw_unit
  addi $s0, $s0, 1
  j draw_left_wall

draw_right_wall_start:
  li $s0, 1
draw_right_wall:
  bgt $s0, 21, draw_floor_start
  li $a0, 26
  move $a1, $s0
  move $a2, $t4
  jal draw_unit
  addi $s0, $s0, 1
  j draw_right_wall

draw_floor_start:
  li $s0, 15
draw_floor:
  bgt $s0, 26, draw_walls_done
  move $a0, $s0
  li $a1, 21
  move $a2, $t4
  jal draw_unit
  addi $s0, $s0, 1
  j draw_floor

draw_walls_done:
  lw $ra, 0($sp)
  lw $s0, 4($sp)
  addi $sp, $sp, 8
  jr $ra

# draws the current game column 
draw_current_column:
  addi $sp, $sp, -16
  sw $ra, 0($sp)
  sw $s0, 4($sp)
  sw $s1, 8($sp)

  lw $s0, col_x
  lw $s1, col_y

  lw $t2, col_gem0
  jal get_gem_color
  move $a0, $s0
  move $a1, $s1
  move $a2, $v0
  jal draw_unit

  lw $t2, col_gem1
  jal get_gem_color
  move $a0, $s0
  addi $a1, $s1, 1
  move $a2, $v0
  jal draw_unit

  lw $t2, col_gem2
  jal get_gem_color
  move $a0, $s0
  addi $a1, $s1, 2
  move $a2, $v0
  jal draw_unit

  lw $ra, 0($sp)
  lw $s0, 4($sp)
  lw $s1, 8($sp)
  addi $sp, $sp, 16
  jr $ra


# ghost outline showing where the block will fall
# easy feature
find_ghost_column:
  addi $sp, $sp, -12
  sw $ra, 0($sp)
  sw $s0, 4($sp)
  lw $a0, col_x
  lw $s0, col_y
fgc_loop:
  move $a1, $s0
  jal check_landing_at
  beq $v0, 1, fgc_done
  addi $s0, $s0, 1
  j fgc_loop
fgc_done:
  move $v0, $s0
  lw $s0, 4($sp)
  lw $ra, 0($sp)
  addi $sp, $sp, 12
  jr $ra


# $a1 = y position to draw the ghost at
draw_ghost:
  addi $sp, $sp, -16
  sw $ra, 0($sp)
  sw $s0, 4($sp)
  sw $s1, 8($sp)
  sw $s2, 12($sp)
  
  move $s0, $a1 
  li $s1, 0x444444
  li $s2, 0
    
dg_loop:
  beq $s2, 3, dg_done
    
  lw $a0, col_x
  move $a1, $s0
  move $a2, $s1
  jal draw_unit
    
  addi $s0, $s0, 1
  addi $s2, $s2, 1
  j dg_loop

dg_done:
    lw $s2, 12($sp)
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 16
    jr $ra

# $a1 = y position of the ghost to erase
erase_ghost:
  addi $sp, $sp, -16
  sw $ra, 0($sp)
  sw $s0, 4($sp)
  sw $s1, 8($sp)
  sw $s2, 12($sp)
  move $s0, $a1
  lw $s1, COL_FIELD
  li $s2, 0
    
eg_loop:
  beq $s2, 3, eg_done
  lw $a0, col_x
  move $a1, $s0
  move $a2, $s1
  jal draw_unit
    
  addi $s0, $s0, 1
  addi $s2, $s2, 1
  j eg_loop

eg_done:
  lw $s2, 12($sp)
  lw $s1, 8($sp)
  lw $s0, 4($sp)
  lw $ra, 0($sp)
  addi $sp, $sp, 16
  jr $ra


  
# get color
get_gem_color:
  la $t3, gem_colors
  sll $t4, $t2, 2
  add $t3, $t3, $t4
  lw $v0, 0($t3)
  jr $ra


# address = ADDR_DSPL + y*128 + x*4
draw_unit:
  lw $t0, ADDR_DSPL
  sll $t1, $a1, 7
  sll $t2, $a0, 2
  add $t1, $t1, $t2
  add $t0, $t0, $t1
  sw $a2, 0($t0)
  jr $ra


# lock column in place, stop movement
lock_column:
  addi $sp, $sp, -4
  sw $ra, 0($sp)

  lw $a0, col_x
  lw $a1, col_y
  jal board_addr
  lw $t0, col_gem0
  sw $t0, 0($v0)

  lw $a0, col_x
  lw $a1, col_y
  addi $a1, $a1, 1
  jal board_addr
  lw $t0, col_gem1
  sw $t0, 0($v0)

  lw $a0, col_x
  lw $a1, col_y
  addi $a1, $a1, 2
  jal board_addr
  lw $t0, col_gem2
  sw $t0, 0($v0)

  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra


# spawn new column
spawn_column:
  addi $sp, $sp, -4
  sw $ra, 0($sp)

  # check if spawn area is blocked -> game over
  li $a0, 20
  li $a1, 1
  jal board_addr
  lw $t0, 0($v0)
  li $t1, -1
  bne $t0, $t1, game_over

  li $a0, 20
  li $a1, 2
  jal board_addr
  lw $t0, 0($v0)
  li $t1, -1
  bne $t0, $t1, game_over

  li $a0, 20
  li $a1, 3
  jal board_addr
  lw $t0, 0($v0)
  li $t1, -1
  bne $t0, $t1, game_over

  li $t0, 20
  sw $t0, col_x
  li $t0, 1
  sw $t0, col_y

  jal pick_random_colors
  jal find_ghost_column
  move $a1, $v0
  jal draw_ghost
  jal draw_current_column
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra


# fill field red -> R -> wait for input
# easy feature: retry
game_over:
  addi $sp, $sp, -8
  sw $ra, 0($sp)
  sw $s0, 4($sp)

  li $s0, 1
go_row:
  bgt $s0, 20, go_draw_R
  li $a0, 16
go_col:
  bgt $a0, 25, go_next_row
  move $a1, $s0
  li $a2, 0xFF0000
  jal draw_unit
  addi $a0, $a0, 1
  j go_col
go_next_row:
  addi $s0, $s0, 1
  j go_row

go_draw_R:
  jal draw_R

  # waiting for r / q
go_wait:
  li $v0, 32
  li $a0, 100
  syscall
  lw $t0, ADDR_KBRD
  lw $t1, 0($t0)
  bne $t1, 1, go_wait
  lw $t2, 4($t0)
  lw $t3, KEY_R
  beq $t2, $t3, go_retry
  lw $t3, KEY_Q
  beq $t2, $t3, key_quit
  j go_wait

go_retry:
  # reset variable data
  li $t0, 20
  sw $t0, col_x
  li $t0, 1
  sw $t0, col_y
  sw $zero, frame_counter
  sw $zero, TIMER
  sw $zero, SCORE

  # reset game board
  la $t0, board
  li $t1, 200 # 200 total
  li $t2, -1
go_reset_board:
  beq $t1, $zero, go_reset_done
  sw $t2, 0($t0)
  addi $t0, $t0, 4
  addi $t1, $t1, -1
  j go_reset_board
go_reset_done:

  lw $ra, 0($sp)
  lw $s0, 4($sp)
  addi $sp, $sp, 8
  j main


# R 
draw_R:
  addi $sp, $sp, -4
  sw $ra, 0($sp)

  li $a2, 0xFFFFFF

  li $a1, 8
  li $a0, 19
  jal draw_unit
  li $a0, 20
  jal draw_unit
  li $a0, 21
  jal draw_unit
  li $a0, 22
  jal draw_unit

  li $a1, 9
  li $a0, 19
  jal draw_unit
  li $a0, 23
  jal draw_unit

  li $a1, 10
  li $a0, 19
  jal draw_unit
  li $a0, 23
  jal draw_unit

  li $a1, 11
  li $a0, 19
  jal draw_unit
  li $a0, 20
  jal draw_unit
  li $a0, 21
  jal draw_unit
  li $a0, 22
  jal draw_unit

  li $a1, 12
  li $a0, 19
  jal draw_unit
  li $a0, 22
  jal draw_unit

  li $a1, 13
  li $a0, 19
  jal draw_unit
  li $a0, 23
  jal draw_unit

  li $a1, 14
  li $a0, 19
  jal draw_unit
  li $a0, 23
  jal draw_unit

  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra

# check for matches + clear 
set_match_flag:
  addi $t0, $a1, -1
  li $t1, 10
  mul $t0, $t0, $t1
  addi $t1, $a0, -16
  add $t0, $t0, $t1
  sll $t0, $t0, 2
  la $t1, match_flags
  add $t1, $t1, $t0
  li $t2, 1
  sw $t2, 0($t1)
  jr $ra


find_matches:
  addi $sp, $sp, -28
  sw $ra, 0($sp)
  sw $s0, 4($sp)
  sw $s1, 8($sp)
  sw $s2, 12($sp)
  sw $s3, 16($sp)
  sw $s4, 20($sp)
  sw $s5, 24($sp)

  li $s3, 0

  li $s0, 1
fm_row:
  bgt $s0, 20, fm_done
  li $s1, 16
fm_col:
  bgt $s1, 25, fm_next_row

  move $a0, $s1
  move $a1, $s0
  jal board_addr
  lw $s2, 0($v0)
  li $t0, -1
  beq $s2, $t0, fm_next_col # skip empty

  # vertical: (x,y+1) and (x,y+2)
  addi $t0, $s0, 2
  bgt $t0, 20, fm_skip_vert
  move $a0, $s1
  addi $a1, $s0, 1
  jal board_addr
  lw $s4, 0($v0)
  move $a0, $s1
  addi $a1, $s0, 2
  jal board_addr
  lw $s5, 0($v0)
  bne $s4, $s2, fm_skip_vert
  bne $s5, $s2, fm_skip_vert
  move $a0, $s1
  move $a1, $s0
  jal set_match_flag
  move $a0, $s1
  addi $a1, $s0, 1
  jal set_match_flag
  move $a0, $s1
  addi $a1, $s0, 2
  jal set_match_flag
  li $s3, 1

fm_skip_vert:
  # horizontal: (x+1,y) and (x+2,y)
  addi $t0, $s1, 2
  bgt $t0, 25, fm_skip_horiz
  addi $a0, $s1, 1
  move $a1, $s0
  jal board_addr
  lw $s4, 0($v0)
  addi $a0, $s1, 2
  move $a1, $s0
  jal board_addr
  lw $s5, 0($v0)
  bne $s4, $s2, fm_skip_horiz
  bne $s5, $s2, fm_skip_horiz
  move $a0, $s1
  move $a1, $s0
  jal set_match_flag
  addi $a0, $s1, 1
  move $a1, $s0
  jal set_match_flag
  addi $a0, $s1, 2
  move $a1, $s0
  jal set_match_flag
  li $s3, 1

fm_skip_horiz:
  # diagonal right: (x+1,y+1) and (x+2,y+2)
  addi $t0, $s1, 2
  bgt $t0, 25, fm_skip_diagr
  addi $t0, $s0, 2
  bgt $t0, 20, fm_skip_diagr
  addi $a0, $s1, 1
  addi $a1, $s0, 1
  jal board_addr
  lw $s4, 0($v0)
  addi $a0, $s1, 2
  addi $a1, $s0, 2
  jal board_addr
  lw $s5, 0($v0)
  bne $s4, $s2, fm_skip_diagr
  bne $s5, $s2, fm_skip_diagr
  move $a0, $s1
  move $a1, $s0
  jal set_match_flag
  addi $a0, $s1, 1
  addi $a1, $s0, 1
  jal set_match_flag
  addi $a0, $s1, 2
  addi $a1, $s0, 2
  jal set_match_flag
  li $s3, 1

fm_skip_diagr:
  # diagonal left: (x-1,y+1) and (x-2,y+2)
  addi $t0, $s1, -2
  blt $t0, 16, fm_skip_diagl
  addi $t0, $s0, 2
  bgt $t0, 20, fm_skip_diagl
  addi $a0, $s1, -1
  addi $a1, $s0, 1
  jal board_addr
  lw $s4, 0($v0)
  addi $a0, $s1, -2
  addi $a1, $s0, 2
  jal board_addr
  lw $s5, 0($v0)
  bne $s4, $s2, fm_skip_diagl
  bne $s5, $s2, fm_skip_diagl
  move $a0, $s1
  move $a1, $s0
  jal set_match_flag
  addi $a0, $s1, -1
  addi $a1, $s0, 1
  jal set_match_flag
  addi $a0, $s1, -2
  addi $a1, $s0, 2
  jal set_match_flag
  li $s3, 1

fm_skip_diagl:
fm_next_col:
  addi $s1, $s1, 1
  j fm_col

fm_next_row:
  addi $s0, $s0, 1
  j fm_row

fm_done:
  move $v0, $s3
  lw $ra, 0($sp)
  lw $s0, 4($sp)
  lw $s1, 8($sp)
  lw $s2, 12($sp)
  lw $s3, 16($sp)
  lw $s4, 20($sp)
  lw $s5, 24($sp)
  addi $sp, $sp, 28
  jr $ra


apply_matches:
  addi $sp, $sp, -12
  sw $ra, 0($sp)
  sw $s0, 4($sp)
  sw $s1, 8($sp)

  li $s0, 1
am_row:
  bgt $s0, 20, am_done
  li $s1, 16
am_col:
  bgt $s1, 25, am_next_row

  addi $t0, $s0, -1
  li $t1, 10
  mul $t0, $t0, $t1
  addi $t1, $s1, -16
  add $t0, $t0, $t1
  sll $t0, $t0, 2
  la $t1, match_flags
  add $t1, $t1, $t0
  lw $t2, 0($t1)
  beq $t2, $zero, am_next_col

  # add score: SCORE_MP * CHAIN for each clear
  lw $t0, SCORE
  lw $t1, SCORE_MP
  lw $t2, CHAIN
  mul $t1, $t1, $t2
  add $t0, $t0, $t1
  sw $t0, SCORE

  # clear from board + redraw
  move $a0, $s1
  move $a1, $s0
  jal board_addr
  li $t0, -1
  sw $t0, 0($v0)
  move $a0, $s1
  move $a1, $s0
  lw $a2, COL_FIELD
  jal draw_unit

am_next_col:
  addi $s1, $s1, 1
  j am_col

am_next_row:
  addi $s0, $s0, 1
  j am_row

am_done:
  lw $ra, 0($sp)
  lw $s0, 4($sp)
  lw $s1, 8($sp)
  addi $sp, $sp, 12
  jr $ra


# move each col down for removing cleared spaces
apply_gravity:
  addi $sp, $sp, -20
  sw $ra, 0($sp)
  sw $s0, 4($sp)
  sw $s1, 8($sp)
  sw $s2, 12($sp)
  sw $s3, 16($sp)

  li $s0, 16 # x

ag_col_loop:
  bgt $s0, 25, ag_done

  li $s2, 20
  li $s1, 20

ag_scan:
  blt $s1, 1, ag_fill_empty

  move $a0, $s0
  move $a1, $s1
  jal board_addr
  lw $s3, 0($v0)
  li $t0, -1
  beq $s3, $t0, ag_scan_next # skip empty

  move $a0, $s0
  move $a1, $s2
  jal board_addr
  sw $s3, 0($v0)

  beq $s2, $s1, ag_no_clear
  move $a0, $s0
  move $a1, $s1
  jal board_addr
  li $t0, -1
  sw $t0, 0($v0)
ag_no_clear:
  addi $s2, $s2, -1

ag_scan_next:
  addi $s1, $s1, -1
  j ag_scan

ag_fill_empty:
  li $s1, 1
ag_fill:
  bgt $s1, $s2, ag_redraw_col
  move $a0, $s0
  move $a1, $s1
  jal board_addr
  li $t0, -1
  sw $t0, 0($v0)
  addi $s1, $s1, 1
  j ag_fill

ag_redraw_col:
  li $s1, 1
ag_redraw:
  bgt $s1, 20, ag_next_col
  move $a0, $s0
  move $a1, $s1
  jal board_addr
  lw $t0, 0($v0)
  li $t1, -1
  bne $t0, $t1, ag_draw_gem
  move $a0, $s0
  move $a1, $s1
  lw $a2, COL_FIELD
  jal draw_unit
  j ag_redraw_next

ag_draw_gem:
  move $t2, $t0
  jal get_gem_color
  move $a0, $s0
  move $a1, $s1
  move $a2, $v0
  jal draw_unit

ag_redraw_next:
  addi $s1, $s1, 1
  j ag_redraw

ag_next_col:
  addi $s0, $s0, 1
  j ag_col_loop

ag_done:
  lw $ra, 0($sp)
  lw $s0, 4($sp)
  lw $s1, 8($sp)
  lw $s2, 12($sp)
  lw $s3, 16($sp)
  addi $sp, $sp, 20
  jr $ra


# keep clearing until no more matches, with chain multiplier
clear_matches:
  addi $sp, $sp, -4
  sw $ra, 0($sp)

  li $t0, 1
  sw $t0, CHAIN

cm_loop:
  la $t0, match_flags
  li $t1, 0
  li $t2, 200
cm_zero:
  beq $t2, $zero, cm_zero_done
  sw $t1, 0($t0)
  addi $t0, $t0, 4
  addi $t2, $t2, -1
  j cm_zero
cm_zero_done:

  jal find_matches
  beq $v0, $zero, cm_done # no matches, stop

  jal apply_matches
  jal apply_gravity
  jal draw_score

  # increment chain multiplier for next group
  lw $t0, CHAIN
  addi $t0, $t0, 1
  sw $t0, CHAIN
  j cm_loop

cm_done:
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra


# game over if any gem is sitting in row 1
check_top_overflow:
  addi $sp, $sp, -8
  sw $ra, 0($sp)
  sw $s0, 4($sp)

  li $s0, 16
cto_loop:
  bgt $s0, 25, cto_clear
  move $a0, $s0
  li $a1, 1
  jal board_addr
  lw $t0, 0($v0)
  li $t1, -1
  bne $t0, $t1, cto_overflow
  addi $s0, $s0, 1
  j cto_loop

cto_overflow:
  lw $ra, 0($sp)
  lw $s0, 4($sp)
  addi $sp, $sp, 8
  j game_over

cto_clear:
  lw $ra, 0($sp)
  lw $s0, 4($sp)
  addi $sp, $sp, 8
  jr $ra


# $v0 = 1 if bottom gem hit floor or a landed gem
check_landing:
  addi $sp, $sp, -4
  sw $ra, 0($sp)
  
  lw $t0, col_y
  addi $t0, $t0, 2
  lw $t1, FIELD_Y_MAX
  bge $t0, $t1, cl_landed

  lw $a0, col_x
  lw $a1, col_y
  addi $a1, $a1, 3
  jal board_addr
  lw $t0, 0($v0)
  li $t1, -1
  bne $t0, $t1, cl_landed

  li $v0, 0
  j cl_done

cl_landed:
  li $v0, 1

cl_done:
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra

# same as check_landing, just with $a0 = x and $a1 = y for ghost_column
check_landing_at:
  addi $sp, $sp, -12
  sw $ra, 0($sp)
  sw $a0, 4($sp)
  sw $a1, 8($sp)
  
  addi $t0, $a1, 2
  lw $t1, FIELD_Y_MAX
  bge $t0, $t1, cl_landed_at

  addi $a1, $a1, 3
  jal board_addr
  
  lw $t0, 0($v0)
  li $t1, -1
  bne $t0, $t1, cl_landed_at

  li $v0, 0
  j cl_done_at

cl_landed_at:
  li $v0, 1

cl_done_at:
  lw $ra, 0($sp)
  lw $a0, 4($sp)
  lw $a1, 8($sp)
  addi $sp, $sp, 12
  jr $ra


# board address for cell (x, y)
# addr = board + ((y-1)*10 + (x-16)) * 4
board_addr:
  addi $t0, $a1, -1
  li $t1, 10
  mul $t0, $t0, $t1
  addi $t1, $a0, -16
  add $t0, $t0, $t1
  sll $t0, $t0, 2
  la $v0, board
  add $v0, $v0, $t0
  jr $ra


# display score
# HARD feature 
draw_score:
  addi $sp, $sp, -20
  sw $ra, 0($sp)
  sw $s0, 4($sp)
  sw $s1, 8($sp)
  sw $s2, 12($sp)
  sw $s3, 16($sp)

  lw $s0, SCORE

  # 999 max
  li $t0, 999
  ble $s0, $t0, ds_no_clamp
  li $s0, 999
ds_no_clamp:

  # hundreds digit
  li $t1, 100
  div $s0, $t1
  mflo $s1
  mfhi $s0 # remainder
  li $a0, 1
  li $a1, 2
  move $a2, $s1
  jal draw_digit

  # tens digit
  li $t1, 10
  div $s0, $t1
  mflo $s1
  mfhi $s0
  li $a0, 5
  li $a1, 2
  move $a2, $s1
  jal draw_digit

  # ones digit
  li $a0, 9
  li $a1, 2
  move $a2, $s0
  jal draw_digit

  lw $ra, 0($sp)
  lw $s0, 4($sp)
  lw $s1, 8($sp)
  lw $s2, 12($sp)
  lw $s3, 16($sp)
  addi $sp, $sp, 20
  jr $ra


# draw_digit: draw one 3x5 7 segment
# $a0 = TL x, $a1 = TL y, $a2 = digit (0-9)
draw_digit:
  addi $sp, $sp, -28
  sw $ra, 0($sp)
  sw $s0, 4($sp)
  sw $s1, 8($sp)
  sw $s2, 12($sp)
  sw $s3, 16($sp)
  sw $s4, 20($sp)
  sw $s5, 24($sp)

  move $s0, $a0
  move $s1, $a1
  move $s2, $a2

  # load bitmap
  la $s3, digit_bitmaps
  sll $t0, $s2, 2
  add $s3, $s3, $t0
  lw $s3, 0($s3)

  li $s4, 0
dd_row:
  bgt $s4, 4, dd_done
  li $s5, 0
dd_col:
  bgt $s5, 2, dd_next_row

  # bit index: 14 = top-left
  # index = (4 - row) * 3 + (2 - col)
  li $t0, 4
  sub $t0, $t0, $s4
  li $t1, 3
  mul $t0, $t0, $t1
  li $t1, 2
  sub $t1, $t1, $s5
  add $t0, $t0, $t1
  li $t1, 1
  sllv $t1, $t1, $t0
  and $t1, $s3, $t1

  add $a0, $s0, $s5
  add $a1, $s1, $s4
  bne $t1, $zero, dd_lit
  lw $a2, COL_SCORE_BG
  j dd_draw
dd_lit:
  lw $a2, COL_SCORE
dd_draw:
  jal draw_unit

  addi $s5, $s5, 1
  j dd_col

dd_next_row:
  addi $s4, $s4, 1
  j dd_row
  
dd_done:
  lw $ra, 0($sp)
  lw $s0, 4($sp)
  lw $s1, 8($sp)
  lw $s2, 12($sp)
  lw $s3, 16($sp)
  lw $s4, 20($sp)
  lw $s5, 24($sp)
  addi $sp, $sp, 28
  jr $ra
# w game