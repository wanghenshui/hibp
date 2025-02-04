#!/usr/bin/env bash

projdir="$(realpath $(dirname $0)/..)"

if [[ -z $1 ]]
then
    echo "Usage: system_tests.sh BUILDDIR"
    exit 1
fi
builddir="$(realpath $1)"
shift

oneTimeSetUp() {
    echo 
    echo "Running system tests..."
    echo 

    export tmpdir=$projdir/test/tmp
    export datadir=$projdir/test/data
    mkdir -p $tmpdir
    rm -rf $tmpdir/*

    stdoutF="${tmpdir}/stdout"
    stderrF="${tmpdir}/stderr"

    $builddir/mock_api_server $datadir &
    export mock_server_pid=$!
    $builddir/hibp-server --ntlm-db=$datadir/hibp_test.ntlm.bin --sha1-db=$datadir/hibp_test.sha1.bin 1>/dev/null &
    export hibp_server_pid=$!
    
    export avoidDoubleTearDownExecution="true"
}

oneTimeTearDown() {
    if [[ "${avoidDoubleTearDownExecution}" == "true" ]]
    then   
	kill $mock_server_pid
	kill $hibp_server_pid
	rm -rf $tmpdir/*
	unset -v avoidDoubleTearDownExecution
    fi
}

th_assertTrueWithNoOutput() {
    th_return_=$1
    th_stdout_=$2
    th_stderr_=$3

    assertTrue 'expecting return code of 0 (true)' ${th_return_}
    assertFalse 'unexpected output to STDOUT' "[ -s '${th_stdout_}' ]"
    assertFalse 'unexpected output to STDERR' "[ -s '${th_stderr_}' ]"

    [ -s "${th_stdout_}" ] && cat "${th_stdout_}" 
    [ -s "${th_stderr_}" ] && cat "${th_stderr_}" 1>&2

    unset th_return_ th_stdout_ th_stderr_
}

# local download

testLocalDownloadSha1() {
    $builddir/hibp-download --testing $tmpdir/hibp_test.sha1.bin --limit 256 --no-progress >${stdoutF} 2>${stderrF}
    rtrn=$?
    th_assertTrueWithNoOutput ${rtrn} "${stdoutF}" "${stderrF}"
}

testLocalDownloadNtlm() {
    $builddir/hibp-download --testing $tmpdir/hibp_test.ntlm.bin --ntlm --limit 256 --no-progress >${stdoutF} 2>${stderrF}
    rtrn=$?
    th_assertTrueWithNoOutput ${rtrn} "${stdoutF}" "${stderrF}"
}

# check local download

testLocalDownloadCmpSha1() {
    cmp $datadir/hibp_test.sha1.bin $tmpdir/hibp_test.sha1.bin >${stdoutF} 2>${stderrF}
    rtrn=$?
    th_assertTrueWithNoOutput ${rtrn} "${stdoutF}" "${stderrF}"
}

testLocalDownloadCmpNtlm() {
    cmp $datadir/hibp_test.ntlm.bin $tmpdir/hibp_test.ntlm.bin >${stdoutF} 2>${stderrF}
    rtrn=$?
    th_assertTrueWithNoOutput ${rtrn} "${stdoutF}" "${stderrF}"
}

# live download

testDownloadSha1() {
    $builddir/hibp-download --limit 10 --no-progress $tmpdir/hibp_live.sha1.bin >${stdoutF} 2>${stderrF}
    rtrn=$?
    th_assertTrueWithNoOutput ${rtrn} "${stdoutF}" "${stderrF}"

    bin_size=$(echo $(wc -c $tmpdir/hibp_live.sha1.bin) | cut -d' ' -f1)
    min_size=232968
    assertTrue "size of hibp-download --limit 10 = ${bin_size}. Too small, expected at least ${min_size}." "[ $bin_size -ge  $min_size ]"
}

testDownloadNtlm() {
    $builddir/hibp-download --ntlm --limit 10 --no-progress $tmpdir/hibp_live.ntlm.bin >${stdoutF} 2>${stderrF}
    rtrn=$?
    th_assertTrueWithNoOutput ${rtrn} "${stdoutF}" "${stderrF}"

    bin_size=$(echo $(wc -c $tmpdir/hibp_live.ntlm.bin) | cut -d' ' -f1)
    min_size=180180
    assertTrue "size of hibp-download --limit 10 = ${bin_size}. Too small, expected at least ${min_size}." "[ $bin_size -ge  $min_size ]"
}

# make topn

testTopnSha1() {
    :> ${stdoutF} 
    $builddir/hibp-topn $datadir/hibp_test.sha1.bin -o $tmpdir/hibp_topn.sha1.bin --topn 10000 1>/dev/null  2>${stderrF}
    rtrn=$?
    th_assertTrueWithNoOutput ${rtrn} "${stdoutF}" "${stderrF}"
}

testTopnNtlm() {
    :> ${stdoutF} 
    $builddir/hibp-topn --ntlm $datadir/hibp_test.ntlm.bin -o $tmpdir/hibp_topn.ntlm.bin --topn 10000 1>/dev/null  2>${stderrF}
    rtrn=$?
    th_assertTrueWithNoOutput ${rtrn} "${stdoutF}" "${stderrF}"
}

# check topn

testTopnCmpSha1() {
    cmp $datadir/hibp_topn.sha1.bin $tmpdir/hibp_topn.sha1.bin >${stdoutF} 2>${stderrF}
    rtrn=$?
    th_assertTrueWithNoOutput ${rtrn} "${stdoutF}" "${stderrF}"
}

testTopnCmpNtlm() {
    cmp $datadir/hibp_topn.ntlm.bin $tmpdir/hibp_topn.ntlm.bin >${stdoutF} 2>${stderrF}
    rtrn=$?
    th_assertTrueWithNoOutput ${rtrn} "${stdoutF}" "${stderrF}"
}

# search topn

testSearchPlainSha1() {
    plain="truelove15"
    correct_count="1002"
    count=$($builddir/hibp-search $tmpdir/hibp_topn.sha1.bin "${plain}" | grep '^found' | cut -d: -f2)
    assertEquals "count for plain pw '${plain}' of '${count}' was wrong" "${correct_count}" "${count}"
}

testSearchPlainNtlm() {
    plain="19696969"
    correct_count="913"
    count=$($builddir/hibp-search --ntlm $tmpdir/hibp_topn.ntlm.bin "${plain}" | grep '^found' | cut -d: -f2)
    assertEquals "count for plain pw '${plain}' of '${count}' was wrong" "${correct_count}" "${count}"
}

testSearchHashSha1() {
    hash="00001131628B741FF755AAC0E7C66D26A7C72082"
    correct_count="1002"
    count=$($builddir/hibp-search --hash $tmpdir/hibp_topn.sha1.bin "${hash}" | grep '^found' | cut -d: -f2)
    assertEquals "count for hash pw '${hash}' of '${count}' was wrong" "${correct_count}" "${count}"
}

testSearchHashNtlm() {
    hash="0001256EA8F568DBEACE2E172FD939F7"
    correct_count="913"
    count=$($builddir/hibp-search --ntlm --hash $tmpdir/hibp_topn.ntlm.bin "${hash}" | grep '^found' | cut -d: -f2)
    assertEquals "count for hash pw '${hash}' of '${count}' was wrong" "${correct_count}" "${count}"
}

# search topn with --toc

testSearchPlainSha1Toc() {
    plain="truelove15"
    correct_count="1002"
    bits=18
    count=$($builddir/hibp-search --toc --toc-bits=$bits $tmpdir/hibp_test.sha1.bin "${plain}" | grep '^found' | cut -d: -f2)
    assertEquals "count for plain pw '${plain}' of '${count}' was wrong" "${correct_count}" "${count}"
    toc_size=$(echo $(wc -c $tmpdir/hibp_test.sha1.bin.$bits.toc) | cut -d' ' -f1)
    correct_toc_size=256
    assertEquals "toc size of ${toc_size} wrong" "${correct_toc_size}" "${toc_size}"
}

testSearchPlainNtlmToc() {
    plain="19696969"
    correct_count="913"
    bits=18
    count=$($builddir/hibp-search --toc --toc-bits=$bits --ntlm $tmpdir/hibp_test.ntlm.bin "${plain}" | grep '^found' | cut -d: -f2)
    assertEquals "count for plain pw '${plain}' of '${count}' was wrong" "${correct_count}" "${count}"
    toc_size=$(echo $(wc -c $tmpdir/hibp_test.ntlm.bin.$bits.toc) | cut -d' ' -f1)
    correct_toc_size=256
    assertEquals "toc size of ${toc_size} wrong" "${correct_toc_size}" "${toc_size}"
}

testSearchHashSha1Toc() {
    hash="00001131628B741FF755AAC0E7C66D26A7C72082"
    correct_count="1002"
    bits=18
    count=$($builddir/hibp-search --toc --toc-bits=$bits --hash $tmpdir/hibp_test.sha1.bin "${hash}" | grep '^found' | cut -d: -f2)
    assertEquals "count for plain pw '${plain}' of '${count}' was wrong" "${correct_count}" "${count}"
}

testSearchHashNtlmToc() {
    hash="0001256EA8F568DBEACE2E172FD939F7"
    correct_count="913"
    bits=18
    count=$($builddir/hibp-search --toc --toc-bits=$bits --ntlm --hash $tmpdir/hibp_test.ntlm.bin "${hash}" | grep '^found' | cut -d: -f2)
    assertEquals "count for plain pw '${plain}' of '${count}' was wrong" "${correct_count}" "${count}"
}

# ensure toc accuracy
testTocCmpSha1() {
    cmp $datadir/hibp_test.sha1.bin.18.toc $tmpdir/hibp_test.sha1.bin.18.toc >${stdoutF} 2>${stderrF}
    rtrn=$?
    th_assertTrueWithNoOutput ${rtrn} "${stdoutF}" "${stderrF}"
}

testTocCmpNtlm() {
    cmp $datadir/hibp_test.ntlm.bin.18.toc $tmpdir/hibp_test.ntlm.bin.18.toc >${stdoutF} 2>${stderrF}
    rtrn=$?
    th_assertTrueWithNoOutput ${rtrn} "${stdoutF}" "${stderrF}"
}

testServerPlain() {
    plain="truelove15"
    correct_count="1002"
    count=$(curl -s http://localhost:8082/check/plain/${plain})
    assertEquals "count for plain pw '${plain}' of '${count}' was wrong" "${correct_count}" "${count}"

    plain="password123"
    correct_count="-1"
    count=$(curl -s http://localhost:8082/check/plain/${plain})
    assertEquals "count for plain pw '${plain}' of '${count}' was wrong" "${correct_count}" "${count}"
}

testServerSha1() {
    sha1="00001131628B741FF755AAC0E7C66D26A7C72082"
    correct_count="1002"
    count=$(curl -s http://localhost:8082/check/sha1/${sha1})
    assertEquals "count for sha1 pw '${sha1}' of '${count}' was wrong" "${correct_count}" "${count}"

    sha1="00001131628B741FF755AAC0E7C66D26A7C72083"
    correct_count="-1"
    count=$(curl -s http://localhost:8082/check/sha1/${sha1})
    assertEquals "count for sha1 pw '${sha1}' of '${count}' was wrong" "${correct_count}" "${count}"

    sha1="00001131628B741FF755AAC0E7C66D26A7C7208"
    correct_count="Invalid hash provided. Check type of hash."
    count=$(curl -s http://localhost:8082/check/sha1/${sha1})
    assertEquals "count for sha1 pw '${sha1}' of '${count}' was wrong" "${correct_count}" "${count}"

    sha1="00001131628B741FF755AAC0E7C66D26A7C7208G"
    correct_count="Invalid hash provided. Check type of hash."
    count=$(curl -s http://localhost:8082/check/sha1/${sha1})
    assertEquals "count for sha1 pw '${sha1}' of '${count}' was wrong" "${correct_count}" "${count}"
}

testServerNtlm() {
    ntlm="0001256EA8F568DBEACE2E172FD939F7"
    correct_count="913"
    count=$(curl -s http://localhost:8082/check/ntlm/${ntlm})
    assertEquals "count for ntlm pw '${ntlm}' of '${count}' was wrong" "${correct_count}" "${count}"

    ntlm="0001256EA8F568DBEACE2E172FD939F8"
    correct_count="-1"
    count=$(curl -s http://localhost:8082/check/ntlm/${ntlm})
    assertEquals "count for ntlm pw '${ntlm}' of '${count}' was wrong" "${correct_count}" "${count}"

    ntlm="0001256EA8F568DBEACE2E172FD939F"
    correct_count="Invalid hash provided. Check type of hash."
    count=$(curl -s http://localhost:8082/check/ntlm/${ntlm})
    assertEquals "count for ntlm pw '${ntlm}' of '${count}' was wrong" "${correct_count}" "${count}"

    ntlm="0001256EA8F568DBEACE2E172FD939F-"
    correct_count="Invalid hash provided. Check type of hash."
    count=$(curl -s http://localhost:8082/check/ntlm/${ntlm})
    assertEquals "count for ntlm pw '${ntlm}' of '${count}' was wrong" "${correct_count}" "${count}"
}


. $projdir/ext/shunit2/shunit2


