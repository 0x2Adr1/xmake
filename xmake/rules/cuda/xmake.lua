--!A cross-platform build utility based on Lua
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- 
-- Copyright (C) 2015 - 2019, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        xmake.lua
--

-- define rule: cuda static library
rule("cuda.static")

    -- add rules
    add_deps("cuda.device_link", "cuda.gencodes")

    -- we must set kind before target.on_load(), may we will use target in on_load()
    before_load(function (target)
        target:set("kind", "static")
    end)

-- define rule: cuda shared library
rule("cuda.shared")

    -- add rules
    add_deps("cuda.device_link", "cuda.gencodes")

    -- we must set kind before target.on_load(), may we will use target in on_load()
    before_load(function (target)
        target:set("kind", "shared")
    end)

-- define rule: cuda console
rule("cuda.console")

    -- add rules
    add_deps("cuda.device_link", "cuda.gencodes")

    -- we must set kind before target.on_load(), may we will use target in on_load()
    before_load(function (target)
        target:set("kind", "binary")
    end)

