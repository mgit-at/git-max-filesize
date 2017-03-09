git-max-filesize
================

A pre-receive hook for git to enforce the usage of [git-lfs][1] by rejecting files that are larger than 5MB.

[1]: https://git-lfs.github.com/

Installation
------------

To install this hook, simply copy the script to the hooks directory of your
repo (the script must be called "pre-receive") and make it executable.

    cp pre-receive.sh yourrepo/hooks/pre-receive
    chmod +x yourrepo/hooks/pre-receive

Configuration
-------------

The maximum filesize can be configured in the git config of the individual
repositories. Setting a value of 0 disables the check.

    [hooks]
    maxfilesize = 5m

License
-------

git-max-filesize is distributed under the Apache License:, Version 2.0.

> Copyright 2017 mgIT GmbH.
>
> Licensed under the Apache License, Version 2.0 (the "License");
> you may not use this file except in compliance with the License.
> You may obtain a copy of the License at
>
>     http://www.apache.org/licenses/LICENSE-2.0
>
> Unless required by applicable law or agreed to in writing, > software
> distributed under the License is distributed on an "AS IS" BASIS,
> WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
> See the License for the specific language governing permissions and
> limitations under the License.
