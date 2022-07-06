# Copyright (c) 2014-2016, 2020, Cody Opel <cwopel@chlorm.net>
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


# - Port ssh key management
#   https://github.com/chlorm/kratos/tree/c82657c9565ce041ade093c473c3f6d0b25be0ad/plugins/ssh


use github.com/chlorm/elvish-stl/io
use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-stl/re


var DIR = (path:join (path:home) '.ssh')

# Make sure all directories and files have the correct permissions
# to ensure everything works with StrictModes enabled.
fn set-permissions {
    os:chmod 0700 (path:home)
    os:chmod 0700 $DIR

    for i (path:scandir $DIR)[files] {
        set i = (path:join $DIR $i)
        if (re:match 'PRIVATE KEY-----' [ (io:cat $i) ][0]) {
            # Private keys should never be readable by other users
            os:chmod 0600 $i
        } elif (==s 'config' (path:basename $i)) {
            os:chmod 0600 $i
        } else {
            # All files other than private keys need to be readable by sshd
            os:chmod 0644 $i
        }
    }
}

