add_rules("mode.debug", "mode.release")

target("test")
    set_kind("binary")
    add_files("src/*.c")
    add_files("src/*.bin")
    add_rules("utils.bin2c")


