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


use github.com/chlorm/elvish-stl/exec
use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-stl/re
use github.com/chlorm/elvish-xdg/xdg-dirs


var SOCKET = (path:join (xdg-dirs:runtime-dir) 'ssh-agent.socket')

fn set-permissions {
    os:chmod 600 $SOCKET
}

# Manually envoke ssh-agent
fn start {
    var cmd = [ (exec:cmd-out 'ssh-agent' '-c' '-a' $SOCKET) ]

    set-permissions

    var pid = (re:find 'pid ([0-9]+)\;' $cmd[-1])
}
