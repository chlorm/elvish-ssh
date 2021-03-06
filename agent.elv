# Copyright (c) 2016, 2020, Cody Opel <cwopel@chlorm.net>
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
use github.com/chlorm/elvish-stl/utils
use github.com/chlorm/elvish-xdg/xdg-dirs


var CACHE-DIR = (path:join (xdg-dirs:runtime-dir) 'agent-auto')
var CACHE-SOCKET = (path:join $CACHE-DIR 'socket')
var CACHE-PID = (path:join $CACHE-DIR 'pid')

var s-gnome-keyring = 'gnome-keyring-daemon'
var s-gpg-agent = 'gpg-agent'
var s-ssh-agent = 'ssh-agent'

fn get-cmd {
    var agent-cmds = [
        $s-ssh-agent
        $s-gnome-keyring
        $s-gpg-agent
    ]

    put (utils:get-preferred-cmd 'PREFERRED_SSH_AGENTS' $agent-cmds)
}

fn get-socket {|agent|
    if (==s $s-gnome-keyring $agent) {
        put $gnome-keyring:SOCKET-SSH
    } elif (==s $s-gpg-agent $agent) {
        put $gpg-agent:SOCKET-SSH
    } elif (==s $s-ssh-agent $agent) {
        put $ssh-agent:SOCKET
    }
    fail
}

fn cache-write {|agent|
    os:makedir $CACHE-DIR
    # FIXME: windows support
    os:chmod 0700 $CACHE-DIR
    print (get-socket $agent) >$CACHE-SOCKET
    print (proc:pidof $agent) >$CACHE-PID
}

fn cache-read {
    if (not (os:exists $CACHE-DIR)) {
        fail
    }
    env:set 'SSH_AUTH_SOCK' (io:cat $CACHE-SOCKET)
    env:set 'SSH_AGENT_PID' (io:cat $CACHE-PID)
}

# NOTE: This is only meant as a fallback if the agent isn't running. It is
#       recommended to start the needed agents with your service manager.
fn start-manually {|agent|
    if (==s $s-gnome-keyring $agent) {
        $gnome-keyring:start
    } elif (==s $s-gpg-agent $agent) {
        $gpg-agent:start
    } elif (==s $s-ssh-agent $agent) {
        $ssh-agent:start
    }
    fail
}

var proper-iter = 1
fn check-proper {|agent|
    var agentPids = $nil
    try {
        var t = (proc:pidsof $agent)
        set agentPids = $t
    } catch _ { }

    if (not (eq $agentPids $nil)) {
        # If the agent is running on a socket that isn't the expected one we
        # must kill the daemon and restart it manually.
        if (not (os:is-socket (get-socket $agent))) {
            for i $agentPids {
                proc:kill $i
            }
            env:unset 'SSH_AGENT_PID'
            env:unset 'SSH_AUTH_SOCK'
            start-manually $agent
        }
    } else {
        start-manually $agent
    }

    # Recursively check
    if (> $proper-iter 3) {
        return
    }
    check-proper $agent
    set proper-iter = (+ $proper-iter 1)
}

fn init-instance {
    if (not $platform:windows) {
        var tty = (exec:cmd-out 'tty')
        env:set 'GPG_TTY' $tty
        env:set 'SSH_TTY' $tty
    }
    cache-read

    # FIXME: document HACK
    # HACK:
    if ?(env:has 'SSH_ASKPASS' >$os:NULL) {
        env:unset 'SSH_ASKPASS'
    }
}

fn init-session {
    var agent = (get-cmd)

    check-proper $agent
    set-permissions $agent
    cache-write $agent
}

