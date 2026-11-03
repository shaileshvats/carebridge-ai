/// Runs the CareBridge test suites without loading files and writes a report.
///   Do ##class(CareBridge.Test.Runner).Run()            unit tests
///   Do ##class(CareBridge.Test.Runner).Run(1)           unit + integration (production must be running)
Class CareBridge.Test.Runner Extends %RegisteredObject
{

Parameter UNIT = "CareBridge.Test.HL7Parser,CareBridge.Test.Recommendation,CareBridge.Test.Validator,CareBridge.Test.PolicyGate,CareBridge.Test.Safety";

ClassMethod Run(includeIntegration As %Boolean = 0, reportFile As %String = "") As %DynamicObject
{
	// %UnitTest resolves a root directory even when nothing is loaded from disk.
	If ($GET(^UnitTestRoot) = "") || '##class(%File).DirectoryExists(^UnitTestRoot) Set ^UnitTestRoot = $SYSTEM.Util.ManagerDirectory()
	Set classes = ..#UNIT_$SELECT(includeIntegration:",CareBridge.Test.Integration", 1:"")
	Set report = {"startedAt":($ZDATETIME($ZTIMESTAMP, 3)), "iris":($ZVERSION), "agentMode":(##class(CareBridge.Operation.ExceptionInvestigator).ActiveMode()), "tests":[], "passed":0, "failed":0}
	For i = 1:1:$LENGTH(classes, ",") {
		Set cls = $PIECE(classes, ",", i)
		Kill ^UnitTest.Result
		Set sc = ##class(%UnitTest.Manager).DebugRunTestCase("", cls, "/noload/nodelete/nodisplay")
		Set idx = $ORDER(^UnitTest.Result(""), -1)
		Continue:idx=""
		Set suite = ""
		For {
			Set suite = $ORDER(^UnitTest.Result(idx, suite)) Quit:suite=""
			Set case = ""
			For {
				Set case = $ORDER(^UnitTest.Result(idx, suite, case)) Quit:case=""
				Set meth = ""
				For {
					Set meth = $ORDER(^UnitTest.Result(idx, suite, case, meth)) Quit:meth=""
					Set node = $GET(^UnitTest.Result(idx, suite, case, meth))
					Set ok = +$LISTGET(node, 1)
					Set failures = []
					Set a = ""
					For {
						Set a = $ORDER(^UnitTest.Result(idx, suite, case, meth, a)) Quit:a=""
						Set an = $GET(^UnitTest.Result(idx, suite, case, meth, a))
						If '$LISTGET(an, 1) Do failures.%Push($LISTGET(an, 2)_": "_$LISTGET(an, 3))
					}
					Do report.tests.%Push({"class":(case), "test":(meth), "result":($SELECT(ok=1:"PASS", 1:"FAIL")), "durationSec":($LISTGET(node, 2)), "failures":(failures)})
					If ok = 1 { Set report.passed = report.passed + 1 } Else { Set report.failed = report.failed + 1 }
				}
			}
		}
	}
	Set report.finishedAt = $ZDATETIME($ZTIMESTAMP, 3)
	If reportFile '= "" {
		Set f = ##class(%Stream.FileCharacter).%New()
		Set f.Filename = reportFile
		Do f.Write(report.%ToJSON())
		Do f.%Save()
	}
	Set iter = report.tests.%GetIterator()
	While iter.%GetNext(.k, .t) {
		Write t.result, "  ", t.class, ":", t.test, !
		Set it2 = t.failures.%GetIterator()
		While it2.%GetNext(.k2, .f) { Write "      ", f, ! }
	}
	Write !, report.passed, " passed, ", report.failed, " failed", !
	Quit report
}

}
