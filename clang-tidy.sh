#!/usr/bin/env bash

# in adition to your IDE clang-tidy,it is worth running this
# periodically to ensure all warnings have been caught. This is
# particularly true with respect to #include warnings which have been
# masked by precompiled headers

# ensure we have genrated a compile_commands.json without precompiled headers
./build.sh -c clang -b debug -g --nopch >/dev/null

# Use clang-tidy -p to force read of compile_commands.json in the
# current directory. This is quite a slow process and may take
# several minutes, hence the use of gnu parallel.
time find app/ src/ include/ -type f -name '*.cpp' -or -name '*.hpp' | \
    nice parallel -q clang-tidy --quiet -p --config-file=.clang-tidy \
	 -header-filter='.*/hibp/include/.*' --use-color
