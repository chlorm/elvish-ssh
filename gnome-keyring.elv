# Copyright (c) 2020, Cody Opel <cwopel@chlorm.net>
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


use github.com/chlorm/elvish-stl/exec
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-xdg/xdg-dirs


var SOCKET-DIR = (path:join (xdg-dirs:runtime-dir) 'keyring')
var SOCKET-CONTROL = (path:join $SOCKET-DIR 'control')
var SOCKET-PKCS11 = (path:join $SOCKET-DIR 'pkcs11')
var SOCKET-SSH = (path:join $SOCKET-DIR 'ssh')

fn set-permissions {|agent|
    os:chmod 0700 $SOCKET-DIR
    var sockets = [
        $SOCKET-CONTROL
        $SOCKET-PKCS11
        $SOCKET-SSH
    ]
    for i $sockets {
        os:chmod 0600 $i
    }
}

# Manually envoke gnome-keyring-daemon
fn start {
    var cmd = [(
        exec:cmd-out 'gnome-keyring-daemon' ^
        '--components' 'ssh,secrets,pkcs11' ^
        '--control-directory' $SOCKET-DIR ^
        '--daemonize'
    )]

    set-permissions
}
