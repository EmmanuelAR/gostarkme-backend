#!/bin/bash

# Build the project
scarb build || exit 1

# Currently, the only way to get all the tests in your test suite is by running snforge test
# This runs all the tests and returns the list of all the tests that [PASS] or [FAIL]
# It might be faster to run only tests that failed to confirm they failed due to rate limit error
# and not because of anything else.

# Capture the output of snforge test
output=$(snforge test 2>&1 || true)

# This function runs only failed tests from the test suite.
run_failed_tests() {
    # Extract failed test names using grep and awk
    failed_tests=$(echo "$output" | grep "\[FAIL\]" | awk '{print $2}')

    # Loop through the failed tests and run them sequentially
    if [ -n "$failed_tests" ]; then
    echo "Running failed tests sequentially:"
    while IFS= read -r test; do
        echo "Running: snforge test $test"
        snforge test "$test"
        if [ $? -ne 0 ]; then
        echo "Test $test failed."
        fi
    done <<< "$failed_tests"
    else
    echo "No failed tests found."
    fi
}

# This function runs all tests in the test suite sequentially and reports tests that failed,
# running them sequentially prevents rate limit error due to snforge not needing to parallelize
# the tests to multiple threads and that reduces the aount of rpc calls made in a second.
run_all_tests_sequentially() {
    #This will be slower, but still avoids the rate limit.
    echo "Running all tests sequentially:"
    test_names=$(echo "$output" | grep "tests::" | awk '{print $2}')

    if [ -n "$test_names" ]; then
        while IFS= read -r test; do
            echo "Running: snforge test $test"
            snforge test "$test"
            if [ $? -ne 0 ]; then
                    echo "Test $test failed."
            fi
        done <<< "$test_names"
    else
        echo "No tests found."
    fi
}

# Uncomment below to run only the tests that failed while collecting the tests from the test suite.
# run_failed_tests()

# Uncomment below to run all tests sequentially.
run_all_tests_sequentially

echo "Local test completed successfully!"
