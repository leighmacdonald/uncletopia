#if defined __stocksoup_testing_included
	#endinput
#endif

#define __stocksoup_testing_included

#include <stocksoup/log_server>

static int s_nTests;
static char s_Context[256];

stock void SetTestContext(const char[] context) {
	strcopy(s_Context, sizeof(s_Context), context);
}

stock void AssertEq(const char[] text, any value, any expected) {
	int nTest = BeginNextTest();
	
	if (value == expected) {
		LogServer("[%d] %s: %s == %d OK", nTest, s_Context, text, expected);
	} else {
		LogServer("[%d] %s: %s != %d (got %d) FAIL", nTest, s_Context, text, expected, value);
		ThrowError("test %d (%s in %s) failed", nTest, text, s_Context);
	}
}

stock void AssertTrue(const char[] text, bool value) {
	AssertEqBool(text, value, true);
}

stock void AssertFalse(const char[] text, bool value) {
	AssertEqBool(text, value, false);
}

stock void AssertEqBool(const char[] text, bool value, bool expected) {
	int nTest = BeginNextTest();
	
	if (value == expected) {
		LogServer("[%d] %s: %s == %s OK", nTest, s_Context, text, expected? "true" : "false");
	} else {
		LogServer("[%d] %s: %s != %s FAIL", nTest, s_Context, text, expected? "true" : "false", value);
		ThrowError("test %d (%s in %s) failed", nTest, text, s_Context);
	}
}

stock void AssertStrEq(const char[] text, const char[] value, const char[] expected) {
	int nTest = BeginNextTest();
	
	if (StrEqual(value, expected)) {
		LogServer("[%d] %s: %s == %s OK", nTest, s_Context, text, expected);
	} else {
		LogServer("[%d] %s: %s != %s (got %s) FAIL", nTest, s_Context, text, expected, value);
		ThrowError("test %d (%s in %s) failed", nTest, text, s_Context);
	}
}

stock int BeginNextTest() {
	return ++s_nTests;
}

stock int GetCurrentTest() {
	return s_nTests;
}