# Copyright (c) 2020, 2022, Cody Opel <cwopel@chlorm.net>
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


fn -valid-types {|type|
    var types = [
        'ecdsa'
        'ed25519'
        'rsa'
    ]
    var _ = (list:has $types $type)
}

fn -ensure-conf-dir {
    if (not (os:is-dir $conf:DIR)) {
        os:makedirs $conf:DIR
    }
}

fn -prevent-overwrite {|f|
    if (not (os:is-file $f)) {
        fail 'Key already exists: '$f
    }
}

# TODO: automate setting this with a truncated hash of the following:
#       {date} {device serial} {passphrase or truncated hash of signingkey}
#       serial: ykman list --serials
# &comment - Descriptive name of key
fn key-comment {|security-key &comment=$nil|
    if (not (eq $comment $nil)) {
        put $comment
        return
    }

    var name = (os:user)'@'(platform:hostname)
    if $security-key {
        var date = (time:date)
        set name = $date'-'$comment
    }
    put $name
}

# https://man.openbsd.org/ssh-keygen.1
# &type         - Do NOT change the default unless you know what you are doing.
# &passphrase   - If not passed the user will be prompted for a passphrase.
#                 This is intended for automated generation usually without
#                 a passphrase (e.g. '').
# &comment      - Descriptive name of key
# &security-key - Hardware security key (e.g. Yubikey)
fn new {|&type='ed25519' &passphrase=$nil &comment=$nil &security-key=$false|
    -valid-types $type

    if (eq $comment $nil) {
        set comment = (key-comment &comment=$comment $false)
    }

    var type2 = $type
    if  $security-key {
        set type = $type'-sk'
        set type2 = $type2'_sk'
    }

    var out = (path:join $conf:DIR 'id_'$type2'-'$comment)

    var cmdArgs = [
        '-t' $type
        '-C' $comment
        '-f' $out
    ]
    if (not (eq $passphrase $nil)) {
        set cmdArgs = [ $@cmdArgs '-N' $passphrase ]
    }
    if (and (==s $type 'rsa') (not $security-key)) {
        set cmdArgs = [ $@cmdArgs '-b' '4096' ]
    }
    if $security-key {
        set cmdArgs = [
            $@cmdArgs
            '-w' 'internal'
            '-O' 'resident'
            '-O' 'application=ssh:'$comment
        ]
    }

    -ensure-conf-dir
    -prevent-overwrite $out
    -prevent-overwrite $out'.pub'
    echo $@cmdArgs >&2
    e:ssh-keygen $@cmdArgs
}

fn update-known-hosts {
    exec:cmd 'ssh-keygen' '-H'
    os:remove (path:join $conf:DIR 'known_hosts.old')
}
