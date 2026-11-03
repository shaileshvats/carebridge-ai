Class CareBridge.Test.HL7Parser Extends %UnitTest.TestCase
{

Method TestParsesCoreFields()
{
	Set p = ##class(CareBridge.Engine.HL7Parser).Parse(##class(CareBridge.Test.Helper).ORU("MRN100001", "ORD-1001", "91", "CTL1"))
	Do $$$AssertEquals(p.msh.messageType, "ORU^R01")
	Do $$$AssertEquals(p.msh.controlId, "CTL1")
	Do $$$AssertEquals(p.msh.sendingApplication, "SYNTH-LIS")
	Do $$$AssertEquals(p.pid.mrn, "MRN100001")
	Do $$$AssertEquals(p.pid.birthDate, "19740312")
	Do $$$AssertEquals(p.obr.placerOrderNumber, "ORD-1001")
	Do $$$AssertEquals(p.obr.testCode, "2345-7")
	Do $$$AssertEquals(p.obr.resultStatus, "F")
	Do $$$AssertEquals(p.obx.%Size(), 1)
	Do $$$AssertEquals(p.obx.%Get(0).value, "91")
	Do $$$AssertEquals(p.obx.%Get(0).status, "F")
}

Method TestAcceptsLineFeedsAndMLLPFraming()
{
	Set t = $CHAR(11)_$TRANSLATE(##class(CareBridge.Test.Helper).ORU(), $CHAR(13), $CHAR(10))_$CHAR(28,13)
	Set p = ##class(CareBridge.Engine.HL7Parser).Parse(t)
	Do $$$AssertEquals(p.pid.mrn, "MRN100001")
	Do $$$AssertEquals(p.parseErrors.%Size(), 0)
}

Method TestRejectsNonHL7()
{
	Set p = ##class(CareBridge.Engine.HL7Parser).Parse("hello world")
	Do $$$AssertEquals(p.parseErrors.%Size(), 1)
}

Method TestContentHashIgnoresControlIdButNotValues()
{
	Set h = "CareBridge.Engine.HL7Parser", t = "CareBridge.Test.Helper"
	Set a = $CLASSMETHOD(h, "ContentHash", $CLASSMETHOD(h, "Parse", $CLASSMETHOD(t, "ORU", "MRN100001", "ORD-1001", "91", "A1")))
	Set b = $CLASSMETHOD(h, "ContentHash", $CLASSMETHOD(h, "Parse", $CLASSMETHOD(t, "ORU", "MRN100001", "ORD-1001", "91", "B2")))
	Set c = $CLASSMETHOD(h, "ContentHash", $CLASSMETHOD(h, "Parse", $CLASSMETHOD(t, "ORU", "MRN100001", "ORD-1001", "92", "C3")))
	Do $$$AssertEquals(a, b, "Same content under a new control id hashes the same")
	Do $$$AssertNotEquals(a, c, "A different value hashes differently")
	Do $$$AssertEquals($LENGTH(a), 64)
}

}
