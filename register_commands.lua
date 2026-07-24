local register_command = function(itemname,description,image)
    minetest.register_craftitem("vbots2:"..itemname, {
        description = description,
        inventory_image = image,
        wield_image = "wieldhand.png",
        stack_max = 1,
        groups = { bot_commands = 1, not_in_creative_inventory = 1},
        on_place = function(itemstack, placer, pointed_thing)
            return nil
        end,
        on_drop = function(itemstack, dropper, pos)
            return nil
        end,
        --on_use = function(itemstack, user, pointed_thing)
        --    return nil
        --end
    })
end

register_command("move_forward","Move bot forward","vbots_move_forward.png")
register_command("move_backward","Move bot backward","vbots_move_backward.png")
register_command("move_down","Move bot down","vbots_move_down.png")
register_command("move_home","Move bot to start position","vbots_move_home.png")

register_command("turn_clockwise","Turn bot 90° clockwise","vbots_turn_clockwise.png")
register_command("turn_anticlockwise","Move bot 90° anti-clockwise","vbots_turn_anticlockwise.png")
register_command("turn_random","Move bot 90° in a random direction","vbots_turn_random.png")

-- register_command("case_end","End section","vbots_case_end.png")
-- register_command("case_failure","Last action failed","vbots_case_failure.png")
-- register_command("case_success","Last action succeeded","vbots_case_success.png")
-- register_command("case_yes","Yes","vbots_case_yes.png")
-- register_command("case_no","No","vbots_case_no.png")
-- register_command("case_test","Test","vbots_case_test.png")
-- register_command("case_repeat","Repeat","vbots_case_repeat.png")

register_command("mode_build","Place ahead or into chest","vbots_mode_build.png")
register_command("build_behind","Place behind or into chest behind","vbots_build_behind.png")
register_command("mode_build_up","Place a block above the block behind the bot","vbots_mode_build_up.png")
register_command("mode_build_down","Place a block below the block behind the bot","vbots_mode_build_down.png")

register_command("mode_speed","set bot speed","vbots_mode_speed.png")
register_command("mode_dig","Dig ahead or take from chest (remove if empty)","vbots_mode_dig.png")
register_command("mode_dig_up","Dig the block above the block in front","vbots_mode_dig_up.png")
register_command("mode_dig_down","Dig the block below the block in front","vbots_mode_dig_down.png")

-- register_command("mode_examine","Examine the block in the direction of the next command","vbots_mode_examine.png")
-- register_command("mode_pause","Wait for a few seconds","vbots_mode_pause.png")
-- register_command("mode_wait","Wait until next event","vbots_mode_wait.png")

--register_command("number_1","1","vbots_number_1.png")
register_command("number_2","2","vbots_number_2.png")
register_command("number_3","3","vbots_number_3.png")
register_command("number_4","4","vbots_number_4.png")
register_command("number_5","5","vbots_number_5.png")
register_command("number_6","6","vbots_number_6.png")
register_command("number_7","7","vbots_number_7.png")

register_command("f1","Sub-program 1","vbots_f1.png")
register_command("f2","Sub-program 2","vbots_f2.png")
register_command("f3","Sub-program 3","vbots_f3.png")
register_command("f4","Sub-program 4","vbots_f4.png")
register_command("f5","Sub-program 5","vbots_f5.png")
register_command("f6","Sub-program 6","vbots_f6.png")

register_command("eq_check","Is block ahead?","vbots_eq_check.png")
register_command("neq_check","Is NOT block ahead?","vbots_neq_check.png")
register_command("dig_check","Is item in chest ahead?","vbots_dig_check.png")
register_command("gt_check","Value > Value ?","vbots_gt_check.png")
register_command("lt_check","Value < Value ?","vbots_lt_check.png")
register_command("gte_check","Value >= Value ?","vbots_gte_check.png")
register_command("lte_check","Value <= Value ?","vbots_lte_check.png")
register_command("end_program","End program","vbots_end_program.png")

register_command("var_a","Variable A","vbots_var_a.png")
register_command("var_b","Variable B","vbots_var_b.png")
register_command("var_c","Variable C","vbots_var_c.png")
register_command("var_d","Variable D","vbots_var_d.png")
register_command("sign_read","Load value from sign","vbots_sign_read.png")
register_command("sign_print","Write value to sign","vbots_sign_print.png")
register_command("count","Count items in inventory","vbots_count.png")
register_command("go_player","Go to player","vbots_go_player.png")
register_command("redstone_toggle","Toggle redstone","vbots_redstone_toggle.png")
register_command("goto_pos","Go to position","vbots_goto_pos.png")

