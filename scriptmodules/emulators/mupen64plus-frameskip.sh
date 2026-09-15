#!/usr/bin/env bash
 
# This file is part of The RetroPie Project
#
# The RetroPie Project is the legal property of its developers, whose names are
# too numerous to list here. Please refer to the COPYRIGHT.md file distributed with this source.
#
# See the LICENSE.md file at the top-level directory of this distribution and
# at https://raw.githubusercontent.com/RetroPie/RetroPie-Setup/master/LICENSE.md
#
 
rp_module_id="mupen64plus-frameskip"
rp_module_desc="N64 emulator MUPEN64Plus (independent frameskip build)"
rp_module_help="ROM Extensions: .z64 .n64 .v64\n\nCopy your N64 roms to $romdir/n64"
rp_module_licence="GPL2 https://raw.githubusercontent.com/mupen64plus/mupen64plus-core/master/LICENSES"
rp_module_repo=":_pkg_info_mupen64plus-frameskip"
rp_module_section="main"
rp_module_flags="sdl2 nodistcc"
 
function depends_mupen64plus-frameskip() {
    local depends=(libsamplerate0-dev libspeexdsp-dev libsdl2-dev libpng-dev libfreetype6-dev fonts-freefont-ttf libglu1-mesa-dev)
    isPlatform "videocore" && depends+=(libraspberrypi-dev)
    isPlatform "mesa" && depends+=(libgles2-mesa-dev)
    isPlatform "gl" && depends+=(libglew-dev libglu1-mesa-dev)
    isPlatform "x86" && depends+=(nasm)
    isPlatform "vero4k" && depends+=(vero3-userland-dev-osmc)
    getDepends "${depends[@]}"
}
 
function _stock_data_mupen64plus-frameskip() {
    # Reuse the launcher shipped by RetroPie's stock mupen64plus module.
    # module. This keeps this custom module as a single independent .sh file.
    local sibling="${md_path%/*}/mupen64plus"
    local stock="$scriptdir/scriptmodules/emulators/mupen64plus"

    if [[ -d "$sibling" ]]; then
        echo "$sibling"
    else
        echo "$stock"
    fi
}

function _frameskip_video_supported_mupen64plus-frameskip() {
    # Keep the very old RPi1/2 path conservative for now. RetroPie treats
    # Zero 2 W as rpi3, so rpi3 covers both Pi 3 and Zero 2 W.
    if isPlatform "rpi"; then
        isPlatform "rpi3" || isPlatform "rpi4" || isPlatform "rpi5"
        return
    fi

    isPlatform "gl" || isPlatform "gles"
}

function _get_repos_mupen64plus-frameskip() {
    local repos=(
        'mupen64plus mupen64plus-core master'
        'mupen64plus mupen64plus-ui-console master'
        'mupen64plus mupen64plus-audio-sdl master'
        'mupen64plus mupen64plus-input-sdl master'
        'mupen64plus mupen64plus-rsp-hle master'
    )
    if isPlatform "videocore" && isPlatform "32bit"; then
        repos+=('gizmo98 mupen64plus-audio-omx master')
    fi

    # This module only needs the current Glide64mk2 and Rice plugins. The old
    # gles2rice/gles2n64 forks are intentionally not included.
    if isPlatform "gl"; then
        repos+=(
            'mupen64plus mupen64plus-video-glide64mk2 master'
            'mupen64plus mupen64plus-video-rice master'
            'mupen64plus mupen64plus-rsp-cxd4 master'
            'mupen64plus mupen64plus-rsp-z64 master'
        )
    elif isPlatform "gles" && _frameskip_video_supported_mupen64plus-frameskip; then
        repos+=(
            'mupen64plus mupen64plus-video-glide64mk2 master'
            'mupen64plus mupen64plus-video-rice master'
        )
    fi
 
    local repo
    for repo in "${repos[@]}"; do
        echo "$repo"
    done
}
 
function _pkg_info_mupen64plus-frameskip() {
    local mode="$1"
    local repo
    case "$mode" in
        get)
            local hashes=()
            local hash
            local date
            local newest_date
            while read repo; do
                repo=($repo)
                date=$(git -C "$md_build/${repo[1]}" log -1 --format=%aI)
                hash="$(git -C "$md_build/${repo[1]}" log -1 --format=%H)"
                hashes+=("$hash")
                if rp_dateIsNewer "$newest_date" "$date"; then
                    newest_date="$date"
                fi
            done < <(_get_repos_mupen64plus-frameskip)
            # store an md5sum of the various last commit hashes to be used to check for changes
            local hash="$(echo "${hashes[@]}" | md5sum | cut -d" " -f1)"
            echo "local pkg_repo_date=\"$newest_date\""
            echo "local pkg_repo_extra=\"$hash\""
            ;;
        newer)
            local hashes=()
            local hash
            while read repo; do
                repo=($repo)
                # Use a pinned hash when a repository entry provides one.
                if [[ -n "${repo[3]}" ]]; then
                    hash="${repo[3]}"
                else
                    if ! hash="$(rp_getRemoteRepoHash git https://github.com/${repo[0]}/${repo[1]} ${repo[2]})"; then
                        __ERRMSGS+=("$hash")
                        return 3
                    fi
                fi
                hashes+=("$hash")
            done < <(_get_repos_mupen64plus-frameskip)
            # store an md5sum of the various last commit hashes to be used to check for changes
            local hash="$(echo "${hashes[@]}" | md5sum | cut -d" " -f1)"
            if [[ "$hash" != "$pkg_repo_extra" ]]; then
                return 0
            fi
            return 1
            ;;
        check)
            local ret=0
            while read repo; do
                repo=($repo)
                out=$(rp_getRemoteRepoHash git https://github.com/${repo[0]}/${repo[1]} ${repo[2]})
                if [[ -z "$out" ]]; then
                    printMsgs "console" "$id repository failed - https://github.com/${repo[0]}/${repo[1]} ${repo[2]}"
                    ret=1
                fi
            done < <(_get_repos_mupen64plus-frameskip)
            return "$ret"
            ;;
    esac
}
 
function sources_mupen64plus-frameskip() {
    local repo
    while read repo; do
        repo=($repo)
        gitPullOrClone "$md_build/${repo[1]}" https://github.com/${repo[0]}/${repo[1]} ${repo[2]} ${repo[3]}
    done < <(_get_repos_mupen64plus-frameskip)
 
}
 
function _params_mupen64plus-frameskip() {
    local dir="$1"
    local params=()

    isPlatform "rpi1" && params+=("VFP=1" "VFP_HARD=1")

    # Legacy VideoCore builds select the Raspberry Pi EGL/GLES libraries.
    if isPlatform "videocore" || [[ "$dir" == "mupen64plus-audio-omx" ]]; then
        params+=("VC=1")
    fi

    # Current Raspberry Pi, Mesa, Mali and Armbian paths use GLES.
    if isPlatform "gles" || isPlatform "mesa" || isPlatform "mali" || isPlatform "armbian"; then
        params+=("USE_GLES=1")
    fi

    isPlatform "neon" && params+=("NEON=1")
    isPlatform "x11" && params+=("OSD=1" "PIE=1")
    isPlatform "x86" && params+=("SSE=SSE2")
    isPlatform "armv6" && params+=("HOST_CPU=armv6")
    isPlatform "armv7" && params+=("HOST_CPU=armv7")
    isPlatform "armv8" && params+=("HOST_CPU=armv8")
    isPlatform "aarch64" && params+=("HOST_CPU=aarch64")

    # RetroPie's console frontend does not provide a Vulkan renderer.
    params+=("VULKAN=0")

    # Build Glide64mk2 with its legacy frameskipper on every supported target.
    [[ "$dir" == "mupen64plus-video-glide64mk2" ]] && params+=("USE_FRAMESKIPPER=1")

    echo "${params[@]}"
}

function build_mupen64plus-frameskip() {
    rpSwap on 2048

    local dir
    local params
    for dir in *; do
        if [[ -f "$dir/projects/unix/Makefile" ]]; then
            params=($(_params_mupen64plus-frameskip "$dir"))
            [[ "$dir" == "mupen64plus-ui-console" ]] && params+=("COREDIR=$md_inst/lib/" "PLUGINDIR=$md_inst/lib/mupen64plus/")
            make -C "$dir/projects/unix" "${params[@]}" clean
            DISTCC_HOSTS="" make -C "$dir/projects/unix" all "${params[@]}" OPTFLAGS="$CFLAGS -O3 -flto"
        fi
    done

    rpSwap off
    md_ret_require=(
        'mupen64plus-ui-console/projects/unix/mupen64plus'
        'mupen64plus-core/projects/unix/libmupen64plus.so.2.0.0'
        'mupen64plus-audio-sdl/projects/unix/mupen64plus-audio-sdl.so'
        'mupen64plus-input-sdl/projects/unix/mupen64plus-input-sdl.so'
        'mupen64plus-rsp-hle/projects/unix/mupen64plus-rsp-hle.so'
    )

    if isPlatform "videocore" && ! isPlatform "64bit"; then
        md_ret_require+=('mupen64plus-audio-omx/projects/unix/mupen64plus-audio-omx.so')
    fi

    if isPlatform "gl"; then
        md_ret_require+=(
            'mupen64plus-video-glide64mk2/projects/unix/mupen64plus-video-glide64mk2.so'
            'mupen64plus-video-rice/projects/unix/mupen64plus-video-rice.so'
            'mupen64plus-rsp-z64/projects/unix/mupen64plus-rsp-z64.so'
        )
        if isPlatform "x86"; then
            md_ret_require+=('mupen64plus-rsp-cxd4/projects/unix/mupen64plus-rsp-cxd4-sse2.so')
        else
            md_ret_require+=('mupen64plus-rsp-cxd4/projects/unix/mupen64plus-rsp-cxd4.so')
        fi
    elif isPlatform "gles" && _frameskip_video_supported_mupen64plus-frameskip; then
        md_ret_require+=(
            'mupen64plus-video-glide64mk2/projects/unix/mupen64plus-video-glide64mk2.so'
            'mupen64plus-video-rice/projects/unix/mupen64plus-video-rice.so'
        )
    fi
}

function install_mupen64plus-frameskip() {
    local dir
    local params

    # Remove GLideN64 artifacts left by versions of this module prior to the
    # frameskip-only cleanup. Do not touch RetroPie's shared N64 config files.
    rm -f \
        "$md_inst/lib/mupen64plus/mupen64plus-video-GLideN64.so" \
        "$md_inst/share/mupen64plus/GLideN64.custom.ini" \
        "$md_inst/share/mupen64plus/GLideN64_config_version.ini"

    for dir in *; do
        if [[ -f "$dir/projects/unix/Makefile" ]]; then
            params=($(_params_mupen64plus-frameskip "$dir"))
            make -C "$dir/projects/unix" PREFIX="$md_inst" OPTFLAGS="$CFLAGS -O3 -flto" "${params[@]}" install
        fi
    done

    # remove default InputAutoConfig.ini. inputconfigscript writes a clean file
    rm -f "$md_inst/share/mupen64plus/InputAutoCfg.ini"
}

function configure_mupen64plus-frameskip() {
    # Avoid disruptive fullscreen mode switches when launched from a desktop
    # or KMS session by reusing Runcommand's current display resolution.
    local res=0
    if isPlatform "kms" || isPlatform "x11"; then
        res="%XRES%x%YRES%"
    fi

    # This module only adds the selectable frameskip variants. It deliberately
    # leaves RetroPie's normal Mupen64Plus emulator entries untouched.
    if _frameskip_video_supported_mupen64plus-frameskip; then
        addEmulator 0 "${md_id}-glide64mk2-noframeskip" "n64" "$md_inst/bin/mupen64plus.sh mupen64plus-video-glide64mk2 %ROM% $res 0 --set Video-Glide64mk2[autoframeskip]\=False --set Video-Glide64mk2[maxframeskip]\=0"
        local fs
        for fs in 1 2 3 4 5; do
            addEmulator 0 "${md_id}-glide64mk2-frameskip-${fs}" "n64" "$md_inst/bin/mupen64plus.sh mupen64plus-video-glide64mk2 %ROM% $res 0 --set Video-Glide64mk2[autoframeskip]\=True --set Video-Glide64mk2[maxframeskip]\=${fs}"
        done

        addEmulator 0 "${md_id}-rice-noframeskip" "n64" "$md_inst/bin/mupen64plus.sh mupen64plus-video-rice %ROM% $res 0 --set Video-Rice[SkipFrame]\=False"
        addEmulator 0 "${md_id}-rice-frameskip" "n64" "$md_inst/bin/mupen64plus.sh mupen64plus-video-rice %ROM% $res 0 --set Video-Rice[SkipFrame]\=True"
    fi

    addSystem "n64"
 
    mkRomDir "n64"
    moveConfigDir "$home/.local/share/mupen64plus" "$md_conf_root/n64/mupen64plus"
 
    [[ "$md_mode" == "remove" ]] && return
    # Copy RetroPie's stock launcher, then point it at this independent install.
    local stock_launcher="$(_stock_data_mupen64plus-frameskip)/mupen64plus.sh"
    if [[ ! -f "$stock_launcher" ]]; then
        md_ret_errors+=("Missing stock Mupen64Plus launcher: $stock_launcher")
        return 1
    fi
    cp "$stock_launcher" "$md_inst/bin/mupen64plus.sh"
    sed -i "s#/emulators/mupen64plus/bin/mupen64plus#/emulators/${md_id}/bin/mupen64plus#g" "$md_inst/bin/mupen64plus.sh"
    chmod +x "$md_inst/bin/mupen64plus.sh"
 
    mkUserDir "$md_conf_root/n64/"
 
    # Copy config files
    cp -v "$md_inst/share/mupen64plus/"{*.ini,font.ttf} "$md_conf_root/n64/"
    isPlatform "rpi" && cp -v "$md_inst/share/mupen64plus/"*.conf "$md_conf_root/n64/"
 
    local cfg_user="${__user:-$user}"
    local cfg_group="${__group:-$cfg_user}"
    local config="$md_conf_root/n64/mupen64plus.cfg"
    local cmd="$md_inst/bin/mupen64plus --configdir $md_conf_root/n64 --datadir $md_conf_root/n64"
 
    # if the user has an existing mupen64plus config we back it up, generate a new configuration
    # copy that to rp-dist and put the original config back again. We then make any ini changes
    # on the rp-dist file. This preserves any user configs from modification and allows us to have
    # a default config for reference
    if [[ -f "$config" ]]; then
        mv "$config" "$config.user"
        su "$cfg_user" -c "$cmd"
        mv "$config" "$config.rp-dist"
        mv "$config.user" "$config"
        config+=".rp-dist"
    else
        su "$cfg_user" -c "$cmd"
    fi
 
        # Raspberry Pi display and audio settings
    if isPlatform "rpi"; then
        iniConfig " = " "" "$config"
        # VSync is mandatory for good performance on KMS
        if isPlatform "kms"; then
            if ! grep -q "\[Video-General\]" "$config"; then
                echo "[Video-General]" >> "$config"
            fi
            iniSet "VerticalSync" "True"
        fi
        if isPlatform "videocore"; then
            setAutoConf mupen64plus_audio 1
        elif isPlatform "mesa"; then
            setAutoConf mupen64plus_audio 0
        fi
    else
        addAutoConf mupen64plus_audio 0
    fi

    # The stock launcher may redirect Rice to GLideN64 for some games. This
    # independent build intentionally contains no GLideN64 plugin.
    addAutoConf mupen64plus_compatibility_check 0
 
    addAutoConf mupen64plus_hotkeys 1
    addAutoConf mupen64plus_texture_packs 1
 
    chown -R "$cfg_user":"$cfg_group" "$md_conf_root/n64"
}
