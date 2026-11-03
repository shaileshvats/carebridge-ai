/// Minimal, schema-independent ER7 (pipe-delimited HL7 v2) reader for the fields CareBridge validates.
/// Deterministic and side-effect free, so it can be unit tested without a production.
Class CareBridge.Engine.HL7Parser Extends %RegisteredObject
{

/// Parse HL7 text into a %DynamicObject:
/// { "msh": {...}, "pid": {...}, "orc": {...}, "obr": {...}, "obx": [...], "nte": [...], "segments": [...] }
/// Missing segments are returned as empty objects/arrays; missing fields as "".
ClassMethod Parse(text As %String) As %DynamicObject
{
	Set out = {"msh":{}, "pid":{}, "orc":{}, "obr":{}, "obx":[], "nte":[], "segments":[], "parseErrors":[]}
	// Normalise segment terminators: CR is standard, accept LF/CRLF from files.
	Set text = $REPLACE($REPLACE(text, $CHAR(13,10), $CHAR(13)), $CHAR(10), $CHAR(13))
	// Strip MLLP framing if present.
	Set text = $TRANSLATE(text, $CHAR(11,28))
	If $EXTRACT(text, 1, 3) '= "MSH" {
		Do out.parseErrors.%Push("Message does not start with an MSH segment")
		Quit out
	}
	Set fs = $EXTRACT(text, 4)
	Set enc = $PIECE($EXTRACT(text, 5, *), fs, 1)
	Set cs = $EXTRACT(enc, 1)
	Set rs = $EXTRACT(enc, 2)
	Set obrSeen = 0
	For i = 1:1:$LENGTH(text, $CHAR(13)) {
		Set seg = $PIECE(text, $CHAR(13), i)
		Continue:seg=""
		Set name = $EXTRACT(seg, 1, 3)
		Do out.segments.%Push(name)
		If name = "MSH" {
			// MSH-1 is the field separator itself, so MSH-n is piece n of the segment.
			Set out.msh = {
				"sendingApplication": ($PIECE($PIECE(seg, fs, 3), cs, 1)),
				"sendingFacility": ($PIECE($PIECE(seg, fs, 4), cs, 1)),
				"receivingApplication": ($PIECE($PIECE(seg, fs, 5), cs, 1)),
				"receivingFacility": ($PIECE($PIECE(seg, fs, 6), cs, 1)),
				"dateTime": ($PIECE(seg, fs, 7)),
				"messageType": ($PIECE($PIECE(seg, fs, 9), cs, 1)_$SELECT($PIECE($PIECE(seg, fs, 9), cs, 2)'="":"^"_$PIECE($PIECE(seg, fs, 9), cs, 2), 1:"")),
				"controlId": ($PIECE(seg, fs, 10)),
				"processingId": ($PIECE(seg, fs, 11)),
				"version": ($PIECE($PIECE(seg, fs, 12), cs, 1))
			}
		} ElseIf name = "PID" {
			// PID-3 may repeat; the MR identifier is the first repetition.
			Set pid3 = $PIECE($PIECE(seg, fs, 4), rs, 1)
			Set out.pid = {
				"mrn": ($PIECE(pid3, cs, 1)),
				"assigningAuthority": ($PIECE(pid3, cs, 4)),
				"familyName": ($PIECE($PIECE(seg, fs, 6), cs, 1)),
				"givenName": ($PIECE($PIECE(seg, fs, 6), cs, 2)),
				"birthDate": ($EXTRACT($PIECE(seg, fs, 8), 1, 8)),
				"sex": ($PIECE(seg, fs, 9))
			}
		} ElseIf name = "ORC" {
			Set out.orc = {
				"orderControl": ($PIECE(seg, fs, 2)),
				"placerOrderNumber": ($PIECE($PIECE(seg, fs, 3), cs, 1)),
				"fillerOrderNumber": ($PIECE($PIECE(seg, fs, 4), cs, 1))
			}
		} ElseIf (name = "OBR") && 'obrSeen {
			Set obrSeen = 1
			Set out.obr = {
				"placerOrderNumber": ($PIECE($PIECE(seg, fs, 3), cs, 1)),
				"fillerOrderNumber": ($PIECE($PIECE(seg, fs, 4), cs, 1)),
				"testCode": ($PIECE($PIECE(seg, fs, 5), cs, 1)),
				"testName": ($PIECE($PIECE(seg, fs, 5), cs, 2)),
				"observationDateTime": ($PIECE(seg, fs, 8)),
				"resultStatus": ($PIECE(seg, fs, 26))
			}
		} ElseIf name = "OBX" {
			Do out.obx.%Push({
				"setId": ($PIECE(seg, fs, 2)),
				"valueType": ($PIECE(seg, fs, 3)),
				"code": ($PIECE($PIECE(seg, fs, 4), cs, 1)),
				"name": ($PIECE($PIECE(seg, fs, 4), cs, 2)),
				"value": ($PIECE(seg, fs, 6)),
				"units": ($PIECE($PIECE(seg, fs, 7), cs, 1)),
				"referenceRange": ($PIECE(seg, fs, 8)),
				"abnormalFlag": ($PIECE(seg, fs, 9)),
				"status": ($PIECE(seg, fs, 12))
			})
		} ElseIf name = "NTE" {
			Do out.nte.%Push($PIECE(seg, fs, 4))
		}
	}
	Quit out
}

/// SHA-256 (hex) over the clinically relevant content: patient, order, test and every observation.
/// Control id and timestamps are excluded so a resend under a new control id hashes the same.
ClassMethod ContentHash(parsed As %DynamicObject) As %String
{
	Set s = parsed.pid.mrn_"|"_parsed.obr.placerOrderNumber_"|"_parsed.obr.fillerOrderNumber_"|"_parsed.obr.testCode_"|"_parsed.obr.resultStatus
	Set iter = parsed.obx.%GetIterator()
	While iter.%GetNext(.k, .o) {
		Set s = s_"|"_o.code_"="_o.value_" "_o.units_" "_o.status
	}
	Quit $ZCONVERT(##class(%xsd.hexBinary).LogicalToXSD($SYSTEM.Encryption.SHAHash(256, $ZCONVERT(s, "O", "UTF8"))), "L")
}

/// Result status of the message: OBR-25 if present, otherwise the first OBX-11.
ClassMethod ResultStatus(parsed As %DynamicObject) As %String
{
	If parsed.obr.resultStatus '= "" Quit parsed.obr.resultStatus
	If parsed.obx.%Size() > 0 Quit parsed.obx.%Get(0).status
	Quit ""
}

}
