// Minimal SQF assertion harness for sqf-vm. Results are emitted via diag_log and
// parsed by run.sh (the VM exits 0 even on failure, so the runner reads the log).

TEST_PASS = 0;
TEST_FAIL = 0;

// [label, got, expected] -> passes when the two are within 1e-6, for float scores whose exact
// string form is not stable across the VM's printing.
fnc_assertClose = {
    params ["_label", "_got", "_exp"];
    if (abs (_got - _exp) < 1e-6) then {
        TEST_PASS = TEST_PASS + 1;
        diag_log ("TEST-PASS| " + _label);
    } else {
        TEST_FAIL = TEST_FAIL + 1;
        diag_log format ["TEST-FAIL| %1 | got=%2 exp=%3", _label, str _got, str _exp];
    };
};

// [label, got, expected] -> compares string forms (value equality for arrays too)
fnc_assertEq = {
    params ["_label", "_got", "_exp"];
    if (str _got isEqualTo str _exp) then {
        TEST_PASS = TEST_PASS + 1;
        diag_log ("TEST-PASS| " + _label);
    } else {
        TEST_FAIL = TEST_FAIL + 1;
        diag_log format ["TEST-FAIL| %1 | got=%2 exp=%3", _label, str _got, str _exp];
    };
};
