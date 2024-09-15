# Copyright (c) 2016, 2020, 2022, Cody Opel <cwopel@chlorm.net>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Automatically sets SSH_AUTH_SOCK to the correct agent and starts the agent
# if it isn't running.


use github.com/chlorm/elvish-ssh/gnome-keyring
use github.com/chlorm/elvish-ssh/gpg-agent
use github.com/chlorm/elvish-ssh/ssh-agent
use github.com/chlorm/elvish-stl/env
use github.com/chlorm/elvish-stl/exec
use github.com/chlorm/elvish-stl/io
use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-stl/platform
use github.com/chlorm/elvish-stl/proc
use github.com/chlorm/elvish-stl/re
use github.com/chlorm/elvish-stl/utils
use github.com/chlorm/elvish-xdg/xdg-dirs


var CACHE-DIR = (path:join (xdg-dirs:runtime-dir) 'agent-auto')
var CACHE-SOCKET = (path:join $CACHE-DIR 'socket')
var CACHE-PID = (path:join $CACHE-DIR 'pid')

var s-gnome-keyring = 'gnome-keyring-daemon'
var s-gpg-agent = 'gpg-agent'
var s-ssh-agent = 'ssh-agent'

var agent-permissions = [&]
set agent-permissions[$s-gnome-keyring] = $gnome-keyring:set-permissions~
set agent-permissions[$s-gpg-agent] = $gpg-agent:set-permissions~
set agent-permissions[$s-ssh-agent] = $ssh-agent:set-permissions~

var agent-socket = [&]
set agent-socket[$s-gnome-keyring] = $gnome-keyring:SOCKET-SSH
set agent-socket[$s-gpg-agent] = $gpg-agent:SOCKET-SSH
set agent-socket[$s-ssh-agent] = $ssh-agent:SOCKET

var agent-start = [&]
set agent-start[$s-gnome-keyring] = $gnome-keyring:start~
set agent-start[$s-gpg-agent] = $gpg-agent:start~
set agent-start[$s-ssh-agent] = $ssh-agent:start~

fn get-cmd {
    var agent-cmds = [
        $s-ssh-agent
        $s-gnome-keyring
        $s-gpg-agent
    ]

    utils:get-preferred-cmd 'PREFERRED_SSH_AGENTS' $agent-cmds
}

fn get-socket {|agent|
    try {
        put $agent-socket[$agent]
    } catch e {
        echo "Can't find agent socket" >&2
        fail $e
    }
}

fn cache-write {|agent|
    os:makedir $CACHE-DIR
    os:chmod 700 $CACHE-DIR
    print (get-socket $agent) >$CACHE-SOCKET
    print (proc:pidsof $agent)[0] >$CACHE-PID
}

fn cache-read {
    if (not (os:exists $CACHE-DIR)) {
        fail 'Cache directory does not exist, session not initialized'
    }
    env:set 'SSH_AUTH_SOCK' (io:open $CACHE-SOCKET)
    env:set 'SSH_AGENT_PID' (io:open $CACHE-PID)
}

fn set-permissions {|agent|
    try {
        $agent-permissions[$agent]
    } catch e {
        echo 'Issue setting agent permissions' >&2
        fail $e
    }
}

# NOTE: This is only meant as a fallback if the agent isn't running. It is
#       recommended to start the needed agents with your service manager.
fn start-manually {|agent|
    try {
        $agent-start[$agent]
    } catch e {
        echo 'Failed to manually start agent' >&2
        fail $e
    }
}

var proper-iter = 1
fn check-proper {|agent|
    var agentPids = $nil
    try {
        var t = (proc:pidsof $agent)
        set agentPids = $t
    } catch _ { }

    # If the agent is running on a socket that isn't the expected one we
    # must kill the daemon and restart it manually.
    if (os:is-socket (get-socket $agent)) {
        return
    } elif (not (eq $agentPids $nil)) {
        for i $agentPids {
            proc:kill $i
        }
        env:unset 'SSH_AGENT_PID'
        env:unset 'SSH_AUTH_SOCK'
        start-manually $agent
    } else {
        start-manually $agent
    }

    # Recursively check
    if (> $proper-iter 3) {
        fail 'Failed to start preferred agent'
    }
    set proper-iter = (+ $proper-iter 1)
    check-proper $agent
}

fn init-instance {
    if $platform:is-windows {
        env:set 'GIT_SSH' (search-external 'ssh')
        return
    }

    var tty = (exec:cmd-out 'tty')
    env:set 'GPG_TTY' $tty
    env:set 'SSH_TTY' $tty
    cache-read
}

fn init-session {
    if ($platform:is-windows) { return }

    var agent = (path:basename (get-cmd))
    check-proper $agent
    set-permissions $agent
    cache-write $agent
}
