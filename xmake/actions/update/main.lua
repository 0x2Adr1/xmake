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
-- @file        main.lua
--

-- imports
import("core.base.semver")
import("core.base.option")
import("core.base.task")
import("net.http")
import("devel.git")
import("net.fasturl")
import("core.base.privilege")
import("privilege.sudo")
import("actions.require.impl.environment", {rootdir = os.programdir()})
import("get_version")

-- run program with privilege
function _sudo_v(program, params)

    -- attempt to install directly
    return try
    {
        function ()
            os.vrunv(program, params)
            return true
        end,

        catch
        {
            -- failed or not permission? request administrator permission and run it again
            function (errors)

                -- trace
                vprint(errors)

                -- try get privilege
                if privilege.get() then
                    local ok = try
                    {
                        function ()
                            os.vrunv(program, params)
                            return true
                        end
                    }

                    -- release privilege
                    privilege.store()

                    -- ok?
                    if ok then
                        return true
                    end
                end

                -- show tips
                local command = program .. " " ..os.args(params)
                cprint("\r${bright color.error}error: ${clear}run `%s` failed, may permission denied!", command)

                -- continue to install with administrator permission?
                if sudo.has() then

                    -- confirm to install?
                    local confirm = utils.confirm({default = true, description = "try continue to run `%s` with administrator permission again"})
                    if confirm then
                        sudo.vrunv(program, params)
                        return true
                    end
                end
            end
        }
    }
end

-- run program witn admin user
function _run_win_v(program, commands, admin)
    local sudo_vbs = path.join(os.programdir(), "scripts", "run.vbs")
    local temp_vbs = os.tmpfile() .. ".vbs"
    os.cp(sudo_vbs, temp_vbs)
    local params = table.join("/Nologo", temp_vbs, "W" .. (admin and "A" or "N") , program, commands)
    local proc = process.openv("cscript", params)
    if proc then process.close(proc) end
    return proc ~= nil
end

-- do uninstall
function _uninstall()
    if is_host("windows") then
        local uninstaller = path.join(os.programdir(), "uninstall.exe")
        if os.isfile(uninstaller) then
            -- UAC on win7
            local params = option.get("quiet") and { "/S" } or {}
            if winos:version():gt("winxp") then
                _run_win_v(uninstaller, params, true)
            else
                _run_win_v(uninstaller, params, false)
            end
        else
            raise("the uninstaller(%s) not found!", uninstaller)
        end
    else
        if os.programdir():startswith("/usr/") then
            _sudo_v("xmake", {"lua", "rm", os.programdir() })
            if os.isfile("/usr/local/bin/xmake") then
                _sudo_v("xmake", {"lua", "rm", "/usr/local/bin/xmake" })
            end
            if os.isfile("/usr/bin/xmake") then
                _sudo_v("xmake", {"lua", "rm", "/usr/bin/xmake" })
            end
        else
            os.rm(os.programdir())
            os.rm(os.programfile())
            os.rm("~/.local/bin/xmake")
        end
    end
end

-- do install
function _install(sourcedir, version)

    -- the install task
    local install_task = function ()

        -- get the install directory
        local installdir = is_host("windows") and os.programdir() or "~/.local/bin"

        -- trace
        cprintf("\r${yellow}  => ${clear}installing to %s ..  ", installdir)
        local ok = try
        {
            function ()

                -- install it
                os.cd(sourcedir)
                if is_host("windows") then
                    local installer = "xmake-" .. version .. ".exe"
                    if os.isfile(installer) then
                        -- /D sets the default installation directory ($INSTDIR), overriding InstallDir and InstallDirRegKey. It must be the last parameter used in the command line and must not contain any quotes, even if the path contains spaces. Only absolute paths are supported.
                        local params = ("/D=" .. os.programdir()):split("%s", { strict = true })
                        if option.get("quiet") then table.insert(params, 1, "/S") end
                        -- need UAC?
                        if winos:version():gt("winxp") then
                            _run_win_v(installer, params, true)
                        else
                            _run_win_v(installer, params, false)
                        end
                    else
                        raise("the installer(%s) not found!", installer)
                    end
                else
                    os.vrun("./scripts/get.sh __local__")
                end
                return true
            end,
            catch 
            {
                function (errors)
                    vprint(errors)
                end
            }
        }

        -- trace
        if ok then
            cprint("\r${yellow}  => ${clear}install to %s .. ${green}ok    ", installdir)
        else
            raise("install failed!")
        end
    end

    -- do install 
    if option.get("verbose") then
        install_task()
    else
        process.asyncrun(install_task)
    end

    -- show version
    if not is_host("windows") then
        os.exec("xmake --version")
    end
end

-- do install script
function _install_script(sourcedir)
    cprintf("\r${yellow}  => ${clear}install script to %s .. ", os.programdir())

    local ok = try
    {
        function ()
            if is_host("windows") then
                local script_original = path.join(os.programdir(), "scripts", "update-script.bat")
                local script = os.tmpfile() .. ".bat"
                os.cp(script_original, script)
                local params = { "/c", script, os.programdir(), path.join(sourcedir, "xmake") }
                os.tryrm(script_original .. ".bak")
                local access = os.trycp(script_original, script_original .. ".bak")
                return _run_win_v("cmd", params, not access)
            else
                os.cd(sourcedir)
                os.vrun("./scripts/get.sh __local__ __install_only__")
                return true
            end
        end,
        catch
        {
            function (errors)
                vprint(errors)
            end
        }
    }
    -- trace
    if ok then
        cprint("${color.success}${text.success}")
    else
        cprint("${color.failure}${text.failure}")
    end
end

-- main
function main()

    -- only uninstall it
    if option.get("uninstall") then

        -- do uninstall
        _uninstall()

        -- trace
        cprint("${bright}uninstall ok!")
        return
    end

    -- enter environment
    environment.enter()

    local is_official, mainurls, version, tags, branches = get_version(option.get("xmakever"))

    -- has been installed?
    if is_official and xmake.version():eq(version) then
        cprint("${bright}xmake %s has been installed!", version)
        return
    end

    local script_only = option.get("scriptonly")

    -- get urls on windows
    if is_host("windows") and not script_only then
        if not is_official then
            raise("not support to update from unofficial source on windows, missing '--scriptonly' flag?")
        end

        if version:find('.', 1, true) then
            mainurls = {format("https://github.com/xmake-io/xmake/releases/download/%s/xmake-%s.exe", version, version),
                        format("https://qcloud.coding.net/u/waruqi/p/xmake-releases/git/raw/master/xmake-%s.exe", version),
                        format("https://gitlab.com/xmake-mirror/xmake-releases/raw/master/xmake-%s.exe", version)}
        else
            local lastest = semver.select("lastest", tags or {}, tags or {}, {})
            if lastest then
                mainurls = {format("https://github.com/xmake-io/xmake/releases/download/%s/xmake-%s.exe", lastest, version),
                            format("https://qcloud.coding.net/u/waruqi/p/xmake-releases/git/raw/master/xmake-%s.exe", version),
                            format("https://gitlab.com/xmake-mirror/xmake-releases/raw/master/xmake-%s.exe", version)}
            else
                raise("not support to update %s on windows!", version)
            end
        end

        -- re-sort mainurls
        fasturl.add(mainurls)
        mainurls = fasturl.sort(mainurls)
    end

    -- trace
    if is_official then
        cprint("update version ${green}%s${clear} from official source ..", version)
    else
        cprint("update version ${green}%s${clear} from ${underline}%s${clear} ..", version, mainurls[1])
    end

    -- the download task
    local sourcedir = path.join(os.tmpdir(), "xmakesrc", version)
    vprint("prepared to downlaod to temp dir %s ..", sourcedir)

    local download_task = function ()
        for idx, url in ipairs(mainurls) do
            cprintf("\r${yellow}  => ${clear}downloading %s ..  ", url)
            local ok = try
            {
                function ()
                    os.tryrm(sourcedir)
                    -- all user provided urls are considered as git url since check has been performed in get_version
                    if is_official and not git.checkurl(url) then
                        os.mkdir(sourcedir)
                        http.download(url, path.join(sourcedir, path.filename(url)))
                    else
                        if version:find('.', 1, true) then
                            git.clone(url, {outputdir = sourcedir})
                            git.checkout(version, {repodir = sourcedir})
                        else
                            git.clone(url, {depth = 1, branch = version, outputdir = sourcedir})
                        end
                    end
                    return true
                end,
                catch 
                {
                    function (errors)
                        vprint(errors)
                    end
                }
            }
            if ok then
                cprint("\r${yellow}  => ${clear}download %s .. ${color.success}${text.success}    ", url)
                break
            else
                cprint("\r${yellow}  => ${clear}download %s .. ${color.failure}${text.failure}    ", url)
            end
            if not ok and idx == #mainurls then
                raise("download failed!")
            end
        end
    end

    -- do download 
    if option.get("verbose") then
        download_task()
    else
        process.asyncrun(download_task)
    end

    -- leave environment
    environment.leave()

    -- do install
    if script_only then
        _install_script(sourcedir)
    else
        _install(sourcedir, version)
    end
end

