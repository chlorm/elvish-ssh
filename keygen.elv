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


use github.com/chlorm/elvish-ssh/conf
use github.com/chlorm/elvish-stl/exec
use github.com/chlorm/elvish-stl/list
use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-stl/platform
use github.com/chlorm/elvish-stl/time


fn generate {|&type='ed25519' &passphrase=$nil &device-name=$nil &security-key=$false|
    var types = [
        'ecdsa'
        'ed25519'
        'rsa'
    ]
    var _ = (list:has $types $type)

    var date = (time:date)
    var name = $date'-'(platform:hostname)
    if $security-key {
        if (eq $device-name $nil) {
            fail
        }
        set name = $date'-'$device-name
    }

    fn if-sk {|i s|
        if $security-key {
            print $i$s
        } else {
            print $i
        }
    }

    var cmdArgs = [
        '-t' (if-sk $type '-sk')
        '-C' $name
        '-f' (path:join $conf:DIR 'id_'(if-sk $type '_sk')'-'$name)
    ]
    if (not (eq $passphrase $nil)) {
        set cmdArgs = [ $@cmdArgs '-N' $passphrase ]
    }
    # FIXME: assert $security-key == $false
    if (==s $type 'rsa') {
        set cmdArgs = [ $@cmdArgs '-b' '4096' ]
    }
    if $security-key {
        set cmdArgs = [
            $@cmdArgs
            '-w' 'internal'
            '-O' 'resident'
            '-O' 'application=ssh:'$name
        ]
    }

    if (not (os:is-dir $conf:DIR)) {
        os:makedirs $conf:DIR
    }
    if (not (os:is-file (path:join $conf:DIR $name'.pub'))) {
        e:ssh-keygen $@cmdArgs
    }
}

fn update-known-hosts {
    exec:cmd 'ssh-keygen' '-H'
    os:remove (path:join $conf:DIR 'known_hosts.old')
}
